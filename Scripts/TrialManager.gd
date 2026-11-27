extends Node

signal trial_state_updated

var is_trial_active: bool = false
var active_trial: TrialData = null
var current_turn: int = 0
var return_to_dojo_slide: bool = false

# Per-attempt combat telemetry
var p1_damage_taken: int = 0
var p2_damage_dealt: int = 0
var p1_parry_triggered: bool = false
var _last_p1_used_parry: bool = false
var _signals_bound: bool = false

var _trials_cache: Array[TrialData] = []


func _ready() -> void:
	_build_trial_roster()


#region Roster & Queries

func get_all_trials() -> Array[TrialData]:
	if _trials_cache.is_empty():
		_build_trial_roster()
	return _trials_cache


func get_trials_by_category(cat: TrialData.Category) -> Array[TrialData]:
	var result: Array[TrialData] = []
	for t: TrialData in get_all_trials():
		if t.category == cat:
			result.append(t)
	result.sort_custom(func(a: TrialData, b: TrialData) -> bool: return a.order < b.order)
	return result


func get_trial_by_id(trial_id: String) -> TrialData:
	for t: TrialData in get_all_trials():
		if t.id == trial_id:
			return t
	return null


func get_next_trial(trial_id: String) -> TrialData:
	var all_trials: Array[TrialData] = get_all_trials()
	for i: int in range(all_trials.size()):
		if all_trials[i].id == trial_id and i + 1 < all_trials.size():
			return all_trials[i + 1]
	return null


func is_trial_completed(trial_id: String) -> bool:
	if RunManager == null or RunManager.meta_data == null:
		return false
	return trial_id in RunManager.meta_data.completed_trials


func get_completed_count(cat: Variant = null) -> int:
	var count: int = 0
	for t: TrialData in get_all_trials():
		if cat != null and t.category != (cat as TrialData.Category):
			continue
		if is_trial_completed(t.id):
			count += 1
	return count


func _build_trial_roster() -> void:
	_trials_cache = TrialCatalog.build_all_trials()

#endregion


#region Trial Lifecycle

func start_trial(trial_id: String) -> void:
	var trial: TrialData = get_trial_by_id(trial_id)
	if trial == null:
		printerr("TrialManager: Trial ID not found: ", trial_id)
		return

	active_trial = trial
	is_trial_active = true
	current_turn = 0
	_reset_telemetry()
	_bind_combat_signals()

	# Clean any conflicting mode flags
	RunManager.clear_active_run_state()
	TutorialManager.clear_active_tutorial()
	GameManager.p2_is_custom = false
	GameManager.ai_difficulty = GameManager.Difficulty.MEDIUM

	# Build deterministic fighters
	var p1: CharacterData = _build_trial_fighter(
		trial.p1_name, trial.p1_class, trial.p1_max_hp, trial.p1_start_hp,
		trial.p1_max_sp, trial.p1_start_sp, trial.p1_card_names
	)
	var p2: CharacterData = _build_trial_fighter(
		trial.p2_name, trial.p2_class, trial.p2_max_hp, trial.p2_start_hp,
		trial.p2_max_sp, trial.p2_start_sp, trial.p2_card_names
	)

	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2
	GameManager.apply_environment_rules(trial.environment)

	if AudioManager and AudioManager.has_method("play_location_music"):
		AudioManager.play_location_music(trial.environment)

	print("--- DOJO TRIAL STARTED: ", trial.id, " (", trial.title, ") ---")
	SceneLoader.change_scene("res://Scenes/CombatArena.tscn")


func retry_trial() -> void:
	if active_trial == null:
		return
	get_tree().paused = false
	start_trial(active_trial.id)


func start_next_trial() -> void:
	if active_trial == null:
		exit_trial_to_menu()
		return
	var next_t: TrialData = get_next_trial(active_trial.id)
	get_tree().paused = false
	if next_t != null:
		start_trial(next_t.id)
	else:
		exit_trial_to_menu()


func exit_trial_to_menu() -> void:
	clear_active_trial()
	return_to_dojo_slide = true
	get_tree().paused = false
	AudioManager.reset_audio_state()
	GlobalCinematics.reset_visuals()
	AudioManager.play_music("menu_theme")
	SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")


func clear_active_trial() -> void:
	is_trial_active = false
	active_trial = null
	current_turn = 0
	_reset_telemetry()
	_unbind_combat_signals()


## Called by CombatArena._ready() right after GameManager.reset_combat().
func apply_trial_initial_state() -> void:
	if not is_trial_active or active_trial == null:
		return

	var t: TrialData = active_trial
	var p1: CharacterData = GameManager.p1_data
	var p2: CharacterData = GameManager.p2_data

	if p1 != null:
		p1.max_hp = t.p1_max_hp
		p1.current_hp = t.p1_start_hp
		p1.max_sp = t.p1_max_sp
		p1.current_sp = t.p1_start_sp
		p1.statuses = t.start_p1_statuses.duplicate(true)
		p1.patient_buff_active = false
		p1.combo_action_count = 0

	if p2 != null:
		p2.max_hp = t.p2_max_hp
		p2.current_hp = t.p2_start_hp
		p2.max_sp = t.p2_max_sp
		p2.current_sp = t.p2_start_sp
		p2.statuses = t.start_p2_statuses.duplicate(true)
		p2.patient_buff_active = false
		p2.combo_action_count = 0

	var st: MatchState = GameManager.state
	st.momentum = t.start_momentum
	st.current_combo_attacker = t.start_combo_attacker
	st.attacker_override = 0
	st.priority_player = t.start_priority_player
	st.p1_opening_stat = t.start_p1_opening
	st.p2_opening_stat = t.start_p2_opening
	st.p1_opportunity_stat = t.start_p1_opportunity
	st.p2_opportunity_stat = t.start_p2_opportunity
	st.p1_must_opener = t.start_p1_must_opener
	st.p2_must_opener = t.start_p2_must_opener

	trial_state_updated.emit()

#endregion


#region Scripted Opponent & Telemetry

func get_bot_card_for_turn(character: CharacterData) -> ActionData:
	if active_trial == null or active_trial.bot_moves.is_empty():
		return GameManager.get_struggle_action(ActionData.Type.DEFENCE)

	var idx: int = clampi(current_turn, 0, active_trial.bot_moves.size() - 1)
	var target_name: String = active_trial.bot_moves[idx]

	if target_name == "Struggle":
		var is_off: bool = (GameManager.get_attacker() == 2)
		return GameManager.get_struggle_action(ActionData.Type.OFFENCE if is_off else ActionData.Type.DEFENCE)

	for card: ActionData in character.deck:
		if card.display_name == target_name:
			return card

	var fallback: ActionData = _load_action_by_name(target_name)
	if fallback != null:
		return fallback

	printerr("TrialManager: Missing scripted bot card: ", target_name)
	return GameManager.get_struggle_action(ActionData.Type.DEFENCE)


func get_upcoming_bot_card_info() -> Dictionary:
	if active_trial == null:
		return {}
	if not active_trial.show_enemy_intent:
		return {
			"hidden": true,
			"name": "Hidden",
			"description": "Use Inspect (Sensei) to read their SP and deck!"
		}
	if active_trial.bot_moves.is_empty():
		return {}

	var idx: int = clampi(current_turn, 0, active_trial.bot_moves.size() - 1)
	var target_name: String = active_trial.bot_moves[idx]
	var card: ActionData = _load_action_by_name(target_name)
	return {
		"hidden": false,
		"name": target_name,
		"description": card.description if card != null else "",
	}


func _reset_telemetry() -> void:
	p1_damage_taken = 0
	p2_damage_dealt = 0
	p1_parry_triggered = false
	_last_p1_used_parry = false


func _bind_combat_signals() -> void:
	if _signals_bound:
		return
	if not GameManager.damage_dealt.is_connected(_on_damage_dealt):
		GameManager.damage_dealt.connect(_on_damage_dealt)
	if not GameManager.clash_resolved.is_connected(_on_clash_resolved):
		GameManager.clash_resolved.connect(_on_clash_resolved)
	_signals_bound = true


func _unbind_combat_signals() -> void:
	if not _signals_bound:
		return
	if GameManager.damage_dealt.is_connected(_on_damage_dealt):
		GameManager.damage_dealt.disconnect(_on_damage_dealt)
	if GameManager.clash_resolved.is_connected(_on_clash_resolved):
		GameManager.clash_resolved.disconnect(_on_clash_resolved)
	_signals_bound = false


func _on_damage_dealt(target_id: int, amount: int, is_blocked: bool) -> void:
	if not is_trial_active or is_blocked or amount <= 0:
		return
	if target_id == 1:
		p1_damage_taken += amount
	elif target_id == 2:
		p2_damage_dealt += amount


func _on_clash_resolved(_winner_id: int, p1_card: ActionData, _p2_card: ActionData, _results: Dictionary) -> void:
	if not is_trial_active:
		return
	_last_p1_used_parry = (p1_card != null and p1_card.is_parry)

#endregion


#region Outcome Evaluation

## Evaluates whether the active trial has been CLEARED, FAILED, or should CONTINUE.
## Called on POST_CLASH (match_ended = false) or game_over (match_ended = true).
func evaluate_trial_outcome(match_ended: bool, winner_id: int) -> Dictionary:
	if not is_trial_active or active_trial == null:
		return { "status": "CONTINUE", "reason": "", "tokens_earned": 0 }

	var t: TrialData = active_trial
	var p1: CharacterData = GameManager.p1_data
	var p2: CharacterData = GameManager.p2_data

	# Check if P1 successfully parried this clash (Parry sets p2_must_opener = true)
	if _last_p1_used_parry and GameManager.state.p2_must_opener:
		p1_parry_triggered = true

	current_turn += 1

	# 1. Immediate fail if P1 was defeated
	if p1 == null or p1.current_hp <= 0 or (match_ended and winner_id == 2):
		return {
			"status": "FAILED",
			"reason": "You were knocked out before completing the trial objective.",
			"tokens_earned": 0,
		}

	# 2. Immediate fail if P1 exceeded allowed damage taken
	if t.max_p1_damage_taken >= 0 and p1_damage_taken > t.max_p1_damage_taken:
		return {
			"status": "FAILED",
			"reason": "You took %d damage (allowed: %d)." % [p1_damage_taken, t.max_p1_damage_taken],
			"tokens_earned": 0,
		}

	# 3. Check if all win conditions are satisfied now
	var enemy_ko: bool = (p2 == null or p2.current_hp <= 0 or (match_ended and winner_id == 1))
	var dmg_ok: bool = (t.max_p1_damage_taken < 0 or p1_damage_taken <= t.max_p1_damage_taken)
	var attacker_ok: bool = (not t.require_p1_attacker or GameManager.get_attacker() == 1)
	var parry_ok: bool = (not t.require_p1_parry or p1_parry_triggered)
	var sp_ok: bool = (t.min_p1_sp_end < 0 or p1.current_sp >= t.min_p1_sp_end)
	var dealt_ok: bool = (p2_damage_dealt >= t.min_damage_to_p2)
	var ko_ok: bool = (not t.require_enemy_ko or enemy_ko)

	if ko_ok and dmg_ok and attacker_ok and parry_ok and sp_ok and dealt_ok:
		var earned: int = _record_trial_clear(t)
		return {
			"status": "CLEARED",
			"reason": t.lesson_summary,
			"tokens_earned": earned,
		}

	# 4. If match ended or turn limit reached without satisfying conditions -> FAILED
	if match_ended or current_turn >= t.turn_limit:
		var reason: String = _build_failure_reason(t, enemy_ko, attacker_ok, parry_ok, sp_ok, dealt_ok)
		return {
			"status": "FAILED",
			"reason": reason,
			"tokens_earned": 0,
		}

	trial_state_updated.emit()
	return { "status": "CONTINUE", "reason": "", "tokens_earned": 0 }


func _build_failure_reason(
	t: TrialData,
	enemy_ko: bool,
	attacker_ok: bool,
	parry_ok: bool,
	sp_ok: bool,
	dealt_ok: bool
) -> String:
	if t.require_enemy_ko and not enemy_ko:
		return "Sensei is still standing after %d clash(es). Try a different line to land lethal damage!" % t.turn_limit
	if t.require_p1_parry and not parry_ok:
		return "Parry did not trigger! Remember: Parry only succeeds when stolen Momentum exceeds your Fall Back."
	if t.require_p1_attacker and not attacker_ok:
		return "You did not seize the Offence! Check how momentum and Reversal/Priority shift advantage."
	if not sp_ok:
		return "You ended with %d SP (needed at least %d SP)." % [GameManager.p1_data.current_sp, t.min_p1_sp_end]
	if not dealt_ok:
		return "You dealt %d damage (needed at least %d)." % [p2_damage_dealt, t.min_damage_to_p2]
	return "Objective not met within %d clash(es)." % t.turn_limit


func _record_trial_clear(t: TrialData) -> int:
	if RunManager == null or RunManager.meta_data == null:
		return 0
	if t.id in RunManager.meta_data.completed_trials:
		return 0
	RunManager.meta_data.completed_trials.append(t.id)
	RunManager.meta_data.circuit_tokens += t.token_reward
	RunManager._save_global_data()
	return t.token_reward

#endregion


#region Fighter & Action Helpers

func _build_trial_fighter(
	fighter_name: String,
	class_type: CharacterData.ClassType,
	max_hp: int,
	start_hp: int,
	max_sp: int,
	start_sp: int,
	card_names: Array[String]
) -> CharacterData:
	var c: CharacterData
	if class_type != CharacterData.ClassType.NONE and ClassFactory.class_registry.has(class_type):
		c = ClassFactory.create_character(class_type, fighter_name)
	else:
		c = CharacterData.new()
		c.character_name = fighter_name
		c.class_type = class_type
		c.portrait = preload("res://Art/Portraits/patient.png")
		c.speed = 2

	c.character_name = fighter_name
	c.max_hp = max_hp
	c.current_hp = start_hp
	c.max_sp = max_sp
	c.current_sp = start_sp
	c.deck.clear()

	for card_name: String in card_names:
		var action: ActionData = _load_action_by_name(card_name)
		if action != null:
			c.deck.append(action.duplicate(true) as ActionData)
		else:
			printerr("TrialManager: Could not find action '", card_name, "' for ", fighter_name)

	return c


func _load_action_by_name(card_name: String) -> ActionData:
	var direct: ActionData = ClassFactory.find_action_resource(card_name)
	if direct != null:
		return direct
	for basic: ActionData in ClassFactory.get_basic_actions():
		if basic.display_name.to_lower() == card_name.to_lower():
			return basic
	return null

#endregion
