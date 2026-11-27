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
var _pre_clash_momentum: int = 0
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
	RunManager.is_arcade_mode = false
	RunManager.is_boss_match = false
	RunManager.is_rival_match = false
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""
	RunManager.next_fight_statuses.clear()
	TutorialManager.is_tutorial_active = false
	TutorialManager.current_step = 0
	TutorialManager.active_script.clear()
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

	_pre_clash_momentum = st.momentum
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
	_pre_clash_momentum = 0
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
	_pre_clash_momentum = GameManager.state.momentum
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


#region Curated Trial Definitions (17 Trials across 3 Tiers)

func _make_trial(cfg: Dictionary) -> TrialData:
	var t: TrialData = TrialData.new()
	t.id = str(cfg.get("id", ""))
	t.title = str(cfg.get("title", ""))
	t.category = cfg.get("category", TrialData.Category.INTERACTION_DRILL) as TrialData.Category
	t.order = int(cfg.get("order", 0))
	t.difficulty = int(cfg.get("difficulty", 1))
	t.focus_trait = str(cfg.get("focus_trait", ""))
	t.objective_short = str(cfg.get("objective_short", ""))
	t.briefing_text = str(cfg.get("briefing_text", ""))
	t.hint_text = str(cfg.get("hint_text", ""))
	t.lesson_summary = str(cfg.get("lesson_summary", ""))
	t.token_reward = int(cfg.get("token_reward", 5))
	t.environment = str(cfg.get("environment", "Dojo"))

	t.p1_name = str(cfg.get("p1_name", "Challenger"))
	t.p1_class = cfg.get("p1_class", CharacterData.ClassType.NONE) as CharacterData.ClassType
	t.p1_max_hp = int(cfg.get("p1_max_hp", 10))
	t.p1_start_hp = int(cfg.get("p1_start_hp", t.p1_max_hp))
	t.p1_max_sp = int(cfg.get("p1_max_sp", 5))
	t.p1_start_sp = int(cfg.get("p1_start_sp", t.p1_max_sp))
	for cn: String in cfg.get("p1_cards", []):
		t.p1_card_names.append(cn)

	t.p2_name = str(cfg.get("p2_name", "Sensei"))
	t.p2_class = cfg.get("p2_class", CharacterData.ClassType.NONE) as CharacterData.ClassType
	t.p2_max_hp = int(cfg.get("p2_max_hp", 10))
	t.p2_start_hp = int(cfg.get("p2_start_hp", t.p2_max_hp))
	t.p2_max_sp = int(cfg.get("p2_max_sp", 5))
	t.p2_start_sp = int(cfg.get("p2_start_sp", t.p2_max_sp))
	for cn: String in cfg.get("p2_cards", []):
		t.p2_card_names.append(cn)

	t.start_momentum = int(cfg.get("start_momentum", 0))
	t.start_combo_attacker = int(cfg.get("start_combo_attacker", 0))
	t.start_priority_player = int(cfg.get("start_priority_player", 1))
	t.start_p1_opening = int(cfg.get("start_p1_opening", 0))
	t.start_p2_opening = int(cfg.get("start_p2_opening", 0))
	t.start_p1_opportunity = int(cfg.get("start_p1_opportunity", 0))
	t.start_p2_opportunity = int(cfg.get("start_p2_opportunity", 0))
	t.start_p1_must_opener = bool(cfg.get("start_p1_must_opener", false))
	t.start_p2_must_opener = bool(cfg.get("start_p2_must_opener", false))
	t.start_p1_statuses = cfg.get("start_p1_statuses", {})
	t.start_p2_statuses = cfg.get("start_p2_statuses", {})

	for bm: String in cfg.get("bot_moves", []):
		t.bot_moves.append(bm)
	for bf: String in cfg.get("bot_feint_moves", []):
		t.bot_feint_moves.append(bf)
	t.show_enemy_intent = bool(cfg.get("show_enemy_intent", true))

	t.turn_limit = int(cfg.get("turn_limit", 1))
	t.require_enemy_ko = bool(cfg.get("require_enemy_ko", false))
	t.max_p1_damage_taken = int(cfg.get("max_p1_damage_taken", -1))
	t.require_p1_attacker = bool(cfg.get("require_p1_attacker", false))
	t.require_p1_parry = bool(cfg.get("require_p1_parry", false))
	t.min_p1_sp_end = int(cfg.get("min_p1_sp_end", -1))
	t.min_damage_to_p2 = int(cfg.get("min_damage_to_p2", 0))
	return t


func _build_trial_roster() -> void:
	_trials_cache.clear()

	# ==========================================================================
	# TIER 1: CORE INTERACTION DRILLS (8 Drills — Telegraphed Intent, 5T each)
	# ==========================================================================

	_trials_cache.append(_make_trial({
		"id": "drill_block_vs_light",
		"title": "Hold the Line",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 1,
		"difficulty": 1,
		"focus_trait": "BLOCK + SP RECOVERY",
		"objective_short": "Take 0 damage and finish with at least 3 SP (1 Clash)",
		"briefing_text": "Sensei is throwing a quick Basic Light (1 Damage). You're low on stamina — pick the defence that negates the poke AND refills your stamina bar.",
		"hint_text": "Every Defence action passively restores +1 SP, and Basic Block adds Recover 1 on top (+2 SP total) while stopping 1 Damage.",
		"lesson_summary": "Block reduces incoming damage and Basic Block restores +2 SP total (Defence +1 + Recover 1). Use Block against low-damage attacks or whenever you need to rebuild stamina safely!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 3, "p1_max_sp": 5, "p1_start_sp": 1,
		"p1_cards": ["Basic Block", "Basic Dodge", "Basic Parry", "Basic Reversal"],
		"p2_max_hp": 10, "p2_start_hp": 10, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Basic Light"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Light"],
		"show_enemy_intent": true,
		"turn_limit": 1, "max_p1_damage_taken": 0, "min_p1_sp_end": 3,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_dodge_vs_guard_break",
		"title": "Sidestep the Breaker",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 2,
		"difficulty": 1,
		"focus_trait": "DODGE vs GUARD BREAK",
		"objective_short": "Survive the clash without taking any damage (1 Clash)",
		"briefing_text": "You're down to 1 HP and Sensei is coming in with Basic Technical (Cost 2, Guard Break, Tiring 1). Guard Break smashes straight through Block — find the defence that avoids it completely!",
		"hint_text": "Dodge completely nullifies any attack whose SP Cost is less than or equal to your Dodge value. Basic Dodge (Dodge 2) beats a Cost 2 Guard Break!",
		"lesson_summary": "Guard Break ignores all Block values, making turtles vulnerable. Dodge completely nullifies an attack (damage, momentum, AND status/Tiring) whenever your Dodge value ≥ the attacker's SP Cost!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 1, "p1_max_sp": 5, "p1_start_sp": 3,
		"p1_cards": ["Basic Block", "Basic Dodge", "Basic Parry", "Basic Reversal"],
		"p2_max_hp": 10, "p2_start_hp": 10, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Basic Technical"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Technical"],
		"show_enemy_intent": true,
		"turn_limit": 1, "max_p1_damage_taken": 0,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_parry_vs_heavy",
		"title": "Turn Their Weight",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 3,
		"difficulty": 1,
		"focus_trait": "PARRY vs HIGH MOMENTUM",
		"objective_short": "Land a successful Parry and take 0 damage (1 Clash)",
		"briefing_text": "Sensei winds up a devastating Basic Heavy (Cost 3, Damage 3, Momentum 3). You only have 2 HP and 1 SP — Block can't absorb 3 damage, and Dodge is too expensive. Use Sensei's own Momentum against them!",
		"hint_text": "Parry steals the opponent's Momentum. Because Heavy's Momentum (3) is greater than Basic Parry's Fall Back (2), the net push goes in your favor — negating all 3 damage!",
		"lesson_summary": "Parry steals the attacker's Momentum and succeeds whenever the tracker moves in your direction (stolen Momentum > your Fall Back). It nullifies ALL incoming damage AND forces the attacker to use an Opener next clash — ideal against slow, high-momentum Heavy attacks!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 2, "p1_max_sp": 5, "p1_start_sp": 1,
		"p1_cards": ["Basic Block", "Basic Dodge", "Basic Parry", "Basic Reversal"],
		"p2_max_hp": 10, "p2_start_hp": 10, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Basic Heavy"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Heavy"],
		"show_enemy_intent": true,
		"turn_limit": 1, "max_p1_damage_taken": 0, "require_p1_parry": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_reversal_vs_fallback",
		"title": "Seize the Opening",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 4,
		"difficulty": 1,
		"focus_trait": "REVERSAL vs FALL BACK",
		"objective_short": "Steal the Offence from Sensei (1 Clash)",
		"briefing_text": "Sensei is on the attack, but pauses to recover stamina with Basic Positioning (Recover 1, Fall Back 1). Punish their retreat and steal the Offence!",
		"hint_text": "Reversal triggers whenever the clash moves Momentum toward your side. Sensei's Fall Back 1 pulls Momentum toward you — play Basic Reversal!",
		"lesson_summary": "Reversal flips you onto the Offence immediately whenever Momentum moves in your direction. Watch for opponents using Fall Back moves (like Basic Positioning) to catch their breath — Reversal turns their breather into your combo!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 4, "p1_max_sp": 5, "p1_start_sp": 2,
		"p1_cards": ["Basic Block", "Basic Dodge", "Basic Parry", "Basic Reversal"],
		"p2_max_hp": 10, "p2_start_hp": 10, "p2_max_sp": 5, "p2_start_sp": 2,
		"p2_cards": ["Basic Positioning"],
		"start_momentum": 6, "start_combo_attacker": 2,
		"bot_moves": ["Basic Positioning"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_p1_attacker": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_combo_and_momentum_swap",
		"title": "Combo's End & Momentum Flip",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 5,
		"difficulty": 1,
		"focus_trait": "COMBOS & MOMENTUM SWAP",
		"objective_short": "End Sensei's combo on your side of Momentum, then KO them on Clash 2 (2 Clashes)",
		"briefing_text": "An attacker keeps their combo going as long as they still have SP (> 0). The instant they hit 0 SP, their combo ends and the Momentum Tracker decides who takes Offence! Sensei has 3 SP left and is about to spend ALL of it on Basic Heavy — pull Momentum into your half so Offence & Defence swap!",
		"hint_text": "Clash 1: Basic Block leaves Momentum on Sensei's half (8), so Sensei keeps Offence even at 0 SP. Play Basic Parry instead to steal Momentum into your half (4)! When Sensei hits 0 SP, roles swap — finish Clash 2 with Basic Light (Opener)!",
		"lesson_summary": "Combos continue as long as the attacker has SP > 0 — even if Momentum crosses over. The moment the attacker hits 0 SP, their combo ends and Momentum is checked: whoever owns the active side swaps onto Offence (starting a fresh combo with an Opener) while the other swaps to Defence!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 4, "p1_max_sp": 5, "p1_start_sp": 2,
		"p1_cards": ["Basic Parry", "Basic Block", "Basic Light", "Basic Heavy"],
		"p2_max_hp": 6, "p2_start_hp": 1, "p2_max_sp": 5, "p2_start_sp": 3,
		"p2_cards": ["Basic Heavy", "Basic Reversal"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Heavy", "Basic Reversal"],
		"show_enemy_intent": true,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_initial_clash_priority",
		"title": "Beat Them to the Punch",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 6,
		"difficulty": 1,
		"focus_trait": "INITIAL CLASH COST PRIORITY",
		"objective_short": "Win the Initial Clash and claim Offence (1 Clash)",
		"briefing_text": "The match starts in Neutral (Momentum 0), and Sensei holds the Priority Token! Sensei opens with Haymaker (Opener, Cost 3). Even without the Priority Token, you can interrupt them and take first Offence.",
		"hint_text": "On the Initial Clash, Offence beats Defence, and between two Offence Openers the LOWER SP Cost wins! Basic Light (Cost 1) interrupts Haymaker (Cost 3).",
		"lesson_summary": "In an Initial Clash, Offence beats Defence; if both pick Offence, the lower SP Cost interrupts the higher Cost and claims Momentum Advantage (Priority Token only breaks exact cost ties). Use cheap Openers like Basic Light to steal first strike against heavy openers!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 5, "p1_start_sp": 4,
		"p1_cards": ["Basic Light", "Haymaker", "Basic Block", "Basic Parry"],
		"p2_max_hp": 10, "p2_start_hp": 10, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Haymaker"],
		"start_momentum": 0, "start_combo_attacker": 0, "start_priority_player": 2,
		"bot_moves": ["Haymaker"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_p1_attacker": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_guard_break_vs_block",
		"title": "Crack the Fortress",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 7,
		"difficulty": 1,
		"focus_trait": "GUARD BREAK vs BLOCK",
		"objective_short": "KO Sensei in 1 Clash",
		"briefing_text": "Sensei is at 1 HP and hunkering down behind Perfect Block (Block 4). Even your hardest Heavy attack (3 Damage) will bounce right off — break through their guard!",
		"hint_text": "Basic Technical has the Guard Break trait, which ignores all Block value completely for a clean 1-damage KO!",
		"lesson_summary": "Guard Break completely bypasses Block regardless of how high the Block value is. Whenever an opponent turtles up with heavy Blocks to survive or farm SP, punish them with Guard Break!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 5, "p1_start_sp": 4,
		"p1_cards": ["Basic Light", "Basic Heavy", "Basic Technical", "Basic Positioning"],
		"p2_max_hp": 10, "p2_start_hp": 1, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Perfect Block"],
		"start_momentum": 3, "start_combo_attacker": 1,
		"bot_moves": ["Perfect Block"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_wall_crush_danger",
		"title": "Back Against the Wall",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 8,
		"difficulty": 2,
		"focus_trait": "WALL CRUSH DANGER",
		"objective_short": "Survive the clash with 0 damage taken (1 Clash)",
		"briefing_text": "You're pinned at your own Wall (Momentum 8) with 1 HP and 0 SP! Sensei throws Haymaker (2 Damage, Momentum 3). Normally Parry beats Momentum 3 — watch out for what Fall Back does at the Wall!",
		"hint_text": "Using Fall Back at your own Wall triggers Wall Crush (drains SP, then deals HP damage) — Basic Parry (Fall Back 2) will kill you! Play Adept Block (Cost 0, Block 2, no Fall Back) instead.",
		"lesson_summary": "Using any Fall Back action when you are already pinned at your Wall triggers Wall Crush — draining SP and spilling directly into HP damage! Avoid Parry or Fall Back moves at the wall unless you have spare SP, and rely on pure Block or Dodge instead.",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 1, "p1_max_sp": 5, "p1_start_sp": 0,
		"p1_cards": ["Basic Parry", "Adept Block", "Basic Block", "Basic Reversal"],
		"p2_max_hp": 10, "p2_start_hp": 10, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Haymaker"],
		"start_momentum": 8, "start_combo_attacker": 2,
		"bot_moves": ["Haymaker"],
		"show_enemy_intent": true,
		"turn_limit": 1, "max_p1_damage_taken": 0,
	}))

	_trials_cache.append(_make_trial({
		"id": "drill_opening_and_counter",
		"title": "Create Opening → Counter",
		"category": TrialData.Category.INTERACTION_DRILL,
		"order": 9,
		"difficulty": 2,
		"focus_trait": "OPENING + COUNTER",
		"objective_short": "KO Sensei within 2 Clashes",
		"briefing_text": "Counter actions are locked until you create an Opening on the opponent! Parry Sensei's Heavy with a move that creates an Opening, then unleash your Counter on Clash 2.",
		"hint_text": "Clash 1: Play Resounding Parry (Parry + Create Opening 2). Clash 2: Resounding Counter (Counter 2, Damage 2) unlocks and KOs Sensei from Defence!",
		"lesson_summary": "Counter X cards are powerful payoffs that stay locked until you inflict Opening ≥ X on your opponent (usually via Create Opening cards like Resounding Parry). Build your Circuit hand with matching Create Opening + Counter pairs!",
		"token_reward": 5,
		"p1_max_hp": 5, "p1_start_hp": 4, "p1_max_sp": 5, "p1_start_sp": 3,
		"p1_cards": ["Resounding Parry", "Resounding Counter", "Basic Block", "Basic Light"],
		"p2_max_hp": 10, "p2_start_hp": 2, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Basic Heavy", "Basic Light"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Heavy", "Basic Light"],
		"show_enemy_intent": true,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	# ==========================================================================
	# TIER 2: CLASS PASSIVES & HYBRID ACTIONS (6 Trials — 10T each)
	# ==========================================================================

	_trials_cache.append(_make_trial({
		"id": "passive_heavy_rage",
		"title": "Heavy: Blood for Stamina",
		"category": TrialData.Category.PASSIVES_AND_HYBRIDS,
		"order": 10,
		"difficulty": 2,
		"focus_trait": "PASSIVE: RAGE",
		"objective_short": "KO Sensei in 1 Clash (Sensei's move is hidden — inspect their deck!)",
		"briefing_text": "You're playing Heavy at 0 SP, facing Sensei at 3 HP. Sensei's move isn't telegraphed — inspect Sensei's hand to see their only defence, then use Heavy's Rage passive to land the sole lethal attack!",
		"hint_text": "Sensei only has Basic Block (Block 1). Toggle RAGE (Pay HP) above your hand and play Drop Kick (Cost 2 paid in HP, Damage 4 − Block 1 = 3 lethal; Basic Heavy only deals 3 − 1 = 2)!",
		"lesson_summary": "Heavy's Rage passive lets you pay HP instead of SP whenever your stamina runs dry (as long as you survive the cost) — though watch out, because Tiring effects also drain Heavy's HP when out of SP! Use Rage to close out a lethal combo when your opponent thinks you're tapped out!",
		"token_reward": 10,
		"p1_name": "Heavy Trainee", "p1_class": CharacterData.ClassType.HEAVY,
		"p1_max_hp": 6, "p1_start_hp": 4, "p1_max_sp": 4, "p1_start_sp": 0,
		"p1_cards": ["Drop Kick", "Basic Heavy", "Basic Technical", "Basic Light"],
		"p2_max_hp": 6, "p2_start_hp": 3, "p2_max_sp": 4, "p2_start_sp": 0,
		"p2_cards": ["Basic Block"],
		"start_momentum": 3, "start_combo_attacker": 1,
		"bot_moves": ["Basic Block"],
		"show_enemy_intent": false,
		"turn_limit": 1, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "passive_patient_bide",
		"title": "Patient: Bide Your Time",
		"category": TrialData.Category.PASSIVES_AND_HYBRIDS,
		"order": 11,
		"difficulty": 2,
		"focus_trait": "PASSIVE: BIDE",
		"objective_short": "KO Sensei within 2 Clashes (Inspect Sensei to read their stamina!)",
		"briefing_text": "You're playing Patient. Sensei is attacking with only 1 SP left (and 2 HP). Survive Clash 1 while arming Patient's Bide passive, then punish Sensei with an Opener when their combo ends on Clash 2!",
		"hint_text": "Clash 1: Play Active Block (Block 1 + Fall Back 1) to block Basic Light AND arm Bide (+1 Damage next action). Sensei hits 0 SP so their combo ends! Clash 2: Play Haymaker (Opener, 2 + 1 Bide − 1 Block = 2 lethal)!",
		"lesson_summary": "Patient's Bide passive arms whenever you use a Fall Back action, adding +1 Damage to your very next move. Pairing Fall Back defences like Active Block or Parry into an Opener turns defensive turns into sudden lethal swings!",
		"token_reward": 10,
		"p1_name": "Patient Trainee", "p1_class": CharacterData.ClassType.PATIENT,
		"p1_max_hp": 5, "p1_start_hp": 4, "p1_max_sp": 4, "p1_start_sp": 2,
		"p1_cards": ["Active Block", "Basic Block", "Haymaker", "Basic Light"],
		"p2_max_hp": 6, "p2_start_hp": 2, "p2_max_sp": 4, "p2_start_sp": 1,
		"p2_cards": ["Basic Light", "Basic Block"],
		"start_momentum": 4, "start_combo_attacker": 2,
		"bot_moves": ["Basic Light", "Basic Block"],
		"show_enemy_intent": false,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "passive_quick_relentless",
		"title": "Quick: Relentless Flow",
		"category": TrialData.Category.PASSIVES_AND_HYBRIDS,
		"order": 12,
		"difficulty": 2,
		"focus_trait": "PASSIVE: RELENTLESS",
		"objective_short": "KO Sensei (4 HP) within 2 Clashes (Inspect Sensei's hand!)",
		"briefing_text": "You're playing Quick at 3 SP against a 4 HP Sensei who has 0 SP. Basic Heavy drains all 3 SP and ends your combo short of a KO — use Quick's Relentless passive to keep your combo alive!",
		"hint_text": "Every 3rd offensive hit restores +1 SP! Clash 1: Play Roll Punch (Cost 1, Repeat 3) — all 3 hits land for 3 damage AND Relentless refunds +1 SP so your combo continues! Clash 2: Finish with Basic Light (1 SP, 1 Damage)!",
		"lesson_summary": "Quick's Relentless passive restores +1 SP on every 3rd hit of a combo — and multi-hit Repeat moves like Roll Punch count EVERY hit toward it! Spend Repeat cards to keep your stamina above 0 and extend lethal combos.",
		"token_reward": 10,
		"p1_name": "Quick Trainee", "p1_class": CharacterData.ClassType.QUICK,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 4, "p1_start_sp": 3,
		"p1_cards": ["Roll Punch", "Basic Heavy", "Basic Light", "Basic Technical"],
		"p2_max_hp": 6, "p2_start_hp": 4, "p2_max_sp": 4, "p2_start_sp": 0,
		"p2_cards": ["Basic Reversal", "Basic Dodge"],
		"start_momentum": 3, "start_combo_attacker": 1,
		"bot_moves": ["Basic Reversal", "Basic Reversal"],
		"show_enemy_intent": false,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "passive_technical_technique",
		"title": "Technical: Custom Technique",
		"category": TrialData.Category.PASSIVES_AND_HYBRIDS,
		"order": 13,
		"difficulty": 2,
		"focus_trait": "PASSIVE: TECHNIQUE",
		"objective_short": "KO Sensei on the Initial Clash (1 Clash)",
		"briefing_text": "You're in Neutral (Momentum 0) against a 1 HP Sensei playing Perfect Block (Block 4). You need Guard Break, but Basic Technical isn't an Opener! Use Technical's Technique dropdown to modify it.",
		"hint_text": "Select '+Opener (+1 SP)' in the Technical dropdown above your hand! That turns Basic Technical (Cost 2 → 3 SP) into a legal Opener with Guard Break for an instant KO.",
		"lesson_summary": "Technical's Custom Technique lets you spend +1 SP to graft Opener, +1 Tiring, or +1 Momentum onto any action. Adding Opener to non-Opener bombs (like Basic Technical or Heavy) lets you break rules in Neutral or after being Parried!",
		"token_reward": 10,
		"p1_name": "Technical Trainee", "p1_class": CharacterData.ClassType.TECHNICAL,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 4, "p1_start_sp": 4,
		"p1_cards": ["Basic Technical", "Basic Light", "Haymaker", "Basic Block"],
		"p2_max_hp": 6, "p2_start_hp": 1, "p2_max_sp": 4, "p2_start_sp": 4,
		"p2_cards": ["Perfect Block"],
		"start_momentum": 0, "start_combo_attacker": 0, "start_priority_player": 1,
		"bot_moves": ["Perfect Block"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "hybrid_crushing_block",
		"title": "Hybrid: Crushing Defence",
		"category": TrialData.Category.PASSIVES_AND_HYBRIDS,
		"order": 14,
		"difficulty": 2,
		"focus_trait": "HYBRID: BLOCK + DAMAGE",
		"objective_short": "Take 0 damage AND KO Sensei from Defence (1 Clash)",
		"briefing_text": "You're on Defence at 1 HP while Sensei has 2 HP and attacks with Basic Light. Pure Block keeps you alive without scoring the KO — look for a hybrid action that combines Defence with Damage!",
		"hint_text": "Crushing Block (Cost 2, Block 2, Damage 2) blocks Sensei's 1 Damage AND strikes back for 2 Damage in the exact same clash!",
		"lesson_summary": "Advanced hybrid actions combine traits so a single card does two jobs at once. Hybrid blocks like Crushing Block (Block 2 + Damage 2) or Elbow Block let you punish light attackers and steal wins even while stuck on Defence!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 1, "p1_max_sp": 5, "p1_start_sp": 3,
		"p1_cards": ["Crushing Block", "Basic Block", "Basic Dodge", "Basic Parry"],
		"p2_max_hp": 6, "p2_start_hp": 2, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Basic Light"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Light"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_enemy_ko": true, "max_p1_damage_taken": 0,
	}))

	_trials_cache.append(_make_trial({
		"id": "hybrid_breakout",
		"title": "Hybrid: Fighting Reversal",
		"category": TrialData.Category.PASSIVES_AND_HYBRIDS,
		"order": 15,
		"difficulty": 2,
		"focus_trait": "HYBRID: BLOCK + REVERSAL + MOM",
		"objective_short": "Survive AND steal Offence in 1 Clash",
		"briefing_text": "Sensei launches a reckless Drop Kick (4 Damage, Fall Back 1) while you're at 4 HP. Basic Reversal gets you knocked out, and Basic Block survives without reversing — pick the hybrid move that does BOTH!",
		"hint_text": "Breakout combines Block 1 + Reversal + Momentum 1. You block 1 damage (surviving at 1 HP) while Momentum 1 + Sensei's Fall Back 1 triggers Reversal and hands you the Offence!",
		"lesson_summary": "Pure Basic Reversal leaves you wide open to damage. Hybrid reversals like Breakout (Block 1 + Reversal + Momentum 1) or Hand Catch absorb incoming hits while still flipping momentum in your favor!",
		"token_reward": 10,
		"p1_max_hp": 6, "p1_start_hp": 4, "p1_max_sp": 5, "p1_start_sp": 3,
		"p1_cards": ["Breakout", "Basic Block", "Basic Reversal", "Basic Parry"],
		"p2_max_hp": 10, "p2_start_hp": 10, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Drop Kick"],
		"start_momentum": 6, "start_combo_attacker": 2,
		"bot_moves": ["Drop Kick"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_p1_attacker": true,
	}))

	# ==========================================================================
	# TIER 3: TACTICAL PUZZLES (3 Multi-Step Puzzles — 10T each)
	# ==========================================================================

	_trials_cache.append(_make_trial({
		"id": "puzzle_feint_combine",
		"title": "Two Moves as One",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 16,
		"difficulty": 3,
		"focus_trait": "FEINT COMBINATION",
		"objective_short": "Survive at 1 HP AND KO Sensei in 1 Clash",
		"briefing_text": "Both fighters are at 1 HP, and Sensei attacks with Basic Light (Cost 1, Damage 1). Quick Dodge keeps you alive with 0 damage; Wind up kills Sensei but gets you killed too. Fuse them with Feint!",
		"hint_text": "Play Wind up (Cost 3, Feint, Damage 1) first — when the Feint phase opens, combine it with Quick Dodge (Cost 1, Dodge 1). Total Cost 4 SP: you dodge Basic Light AND deal 1 lethal damage!",
		"lesson_summary": "Feint lets you combine a second action onto your first move (paying both SP costs), merging their Dodge, Block, Damage, Guard Break, and traits into one super-action. Use Feint to cover a move's weakness on decisive turns!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 1, "p1_max_sp": 5, "p1_start_sp": 4,
		"p1_cards": ["Wind up", "Quick Dodge", "Basic Block", "Basic Parry"],
		"p2_max_hp": 5, "p2_start_hp": 1, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Basic Light"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Light"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_enemy_ko": true, "max_p1_damage_taken": 0,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_opportunity_tempo",
		"title": "Seize the Tempo",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 17,
		"difficulty": 3,
		"focus_trait": "OPPORTUNITY DISCOUNT",
		"objective_short": "KO Sensei (3 HP) within 2 Clashes (Inspect Sensei's SP!)",
		"briefing_text": "You're on Defence at 1 SP, while Sensei is at 0 SP and 3 HP. Without a cost discount, you won't have enough stamina to land your big finisher on Clash 2 — generate Opportunity first!",
		"hint_text": "Sensei has 0 SP and must play Basic Positioning (Fall Back 1). Clash 1: Play Push Kick (Cost 1, Mom 1, Opportunity 1 — net 1 SP after Def +1) to take Momentum AND gain Opportunity 1. Clash 2: Drop Kick is discounted from 2 SP → 1 SP and deals 4 − 1 Block = 3 lethal!",
		"lesson_summary": "Opportunity reduces the SP cost of your next action (and boosts its Momentum!). Setting up Opportunity on Defence with moves like Push Kick lets you unleash expensive finishers a full turn earlier than your opponent expects!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 4, "p1_max_sp": 5, "p1_start_sp": 1,
		"p1_cards": ["Push Kick", "Basic Reversal", "Basic Block", "Drop Kick", "Basic Light"],
		"p2_max_hp": 6, "p2_start_hp": 3, "p2_max_sp": 5, "p2_start_sp": 0,
		"p2_cards": ["Basic Positioning", "Basic Block"],
		"start_momentum": 5, "start_combo_attacker": 0,
		"bot_moves": ["Basic Positioning", "Basic Block"],
		"show_enemy_intent": false,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_grandmaster_exam",
		"title": "Grandmaster's Exam",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 18,
		"difficulty": 3,
		"focus_trait": "PARRY → COUNTER → TECHNIQUE GB",
		"objective_short": "Defeat Sensei (3 HP) within 3 Clashes without dying!",
		"briefing_text": "The final fundamentals test! You're playing Technical. Sensei opens with Basic Heavy (3 Dmg), follows up with Basic Light while unbalanced, and will turtle behind Perfect Block once their stamina runs dry. Chain 3 interactions + Custom Technique for the KO!",
		"hint_text": "Clash 1: Resounding Parry (negates Heavy, creates Opening 2, Mom 5 → 4). Clash 2: Resounding Counter (2 Dmg, Sensei hits 0 SP so combo ends & Mom is on your side!). Clash 3: Select '+Opener (+1 SP)' in Technical's dropdown and play Basic Technical (Guard Break) to shatter Perfect Block!",
		"lesson_summary": "True CLASH mastery is chaining defence into offence: Parry neutralizes heavy momentum and creates Openings, Counters deal damage from Defence while exhausting the attacker, and Technical's +Opener Guard Break seals the KO even against Perfect Block!",
		"token_reward": 10,
		"p1_name": "Dojo Candidate", "p1_class": CharacterData.ClassType.TECHNICAL,
		"p1_max_hp": 5, "p1_start_hp": 3, "p1_max_sp": 5, "p1_start_sp": 3,
		"p1_cards": ["Resounding Parry", "Resounding Counter", "Basic Technical", "Haymaker", "Basic Block"],
		"p2_max_hp": 6, "p2_start_hp": 3, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Basic Heavy", "Basic Light", "Perfect Block"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Heavy", "Basic Light", "Perfect Block"],
		"show_enemy_intent": true,
		"turn_limit": 3, "require_enemy_ko": true,
	}))

	# ==========================================================================
	# ADVANCED TIER 3 PUZZLES (10 Additional Multi-Turn Puzzles — 10T each)
	# ==========================================================================

	_trials_cache.append(_make_trial({
		"id": "puzzle_drain_the_tank",
		"title": "Drain the Tank",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 19,
		"difficulty": 3,
		"focus_trait": "TIRING vs HEAVY",
		"objective_short": "KO Heavy Sensei (2 HP) within 2 Clashes with only 2 SP! (Inspect Sensei!)",
		"briefing_text": "Sensei is a Heavy fighter at 2 HP and 0 SP hiding behind Adept Block (Block 2). You only have 2 SP total — Basic Technical can only deal 1 damage before you're tapped out. Exploit Heavy's weakness to Tiring!",
		"hint_text": "When a Heavy fighter is hit by Tiring with insufficient SP, the overflow drains their HP directly (ignoring Block)! Play Headbutt (Cost 1, Tiring 2) on Clash 1 and Clash 2: Adept Block gives Sensei +1 SP, and Tiring 2 drains 1 SP + 1 HP each clash for a 2-HP KO!",
		"lesson_summary": "Heavy's Rage cuts both ways: Tiring effects spill straight into HP damage when a Heavy fighter runs out of SP, completely bypassing Block! Against low-stamina Heavy opponents, cheap Tiring moves like Headbutt or Pummel melt through any guard.",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 5, "p1_start_sp": 2,
		"p1_cards": ["Headbutt", "Basic Technical", "Basic Heavy", "Basic Light"],
		"p2_name": "Heavy Sensei", "p2_class": CharacterData.ClassType.HEAVY,
		"p2_max_hp": 6, "p2_start_hp": 2, "p2_max_sp": 4, "p2_start_sp": 0,
		"p2_cards": ["Adept Block"],
		"start_momentum": 3, "start_combo_attacker": 1,
		"bot_moves": ["Adept Block", "Adept Block"],
		"show_enemy_intent": false,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_grapplers_trap",
		"title": "Grappler's Trap",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 20,
		"difficulty": 3,
		"focus_trait": "MULTI LOCK + OPENING → THROW",
		"objective_short": "KO Sensei (3 HP) within 2 Clashes!",
		"briefing_text": "In Neutral (Momentum 0), Sensei is fishing for a Basic Reversal on Clash 1 — and holds Perfect Block (Block 4) ready for Clash 2. Lock Sensei out of Perfect Block AND open them up for a massive Counter finisher!",
		"hint_text": "Clash 1: Play Grab (Cost 1, Opener, Multi 2, Create Opening 2) — it wins Neutral, locks Sensei into repeating Basic Reversal on Clash 2 (blocking Perfect Block!), and creates Opening 2! Clash 2: Throw (Cost 2 ≤ Multi 2, Counter 2, Damage 3) KOs Sensei cleanly!",
		"lesson_summary": "When you use a Multi X action, your opponent must repeat their same action on the next clash, while your next action is capped to Cost ≤ X. Locking an opponent into an unguarded move with Grab (Multi 2 + Create Opening 2) guarantees a clean Throw (Cost 2, Counter 2, 3 Damage)!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 5, "p1_start_sp": 4,
		"p1_cards": ["Grab", "Throw", "Haymaker", "Basic Light"],
		"p2_max_hp": 6, "p2_start_hp": 3, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Basic Reversal", "Perfect Block"],
		"start_momentum": 0, "start_combo_attacker": 0, "start_priority_player": 1,
		"bot_moves": ["Basic Reversal", "Perfect Block"],
		"show_enemy_intent": true,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_retaliate_recoil",
		"title": "Taste of Their Own Medicine",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 21,
		"difficulty": 3,
		"focus_trait": "RETALIATE REFLECTION",
		"objective_short": "KO Sensei (3 HP) from Defence in 1 Clash!",
		"briefing_text": "Sensei (3 HP) charges in with Lariat (Cost 2, Momentum 2, Damage 3) while you're stuck on Defence at 4 HP. Because Lariat only has Momentum 2, Parry won't nullify it — turn Sensei's own 3 Damage back on them!",
		"hint_text": "Play Redirect (Cost 1, Retaliate, Parry, Fall Back 2). Because Mom 2 equals Fall Back 2, Parry doesn't make you immune — you survive at 1 HP and Retaliate reflects all 3 of Lariat's damage right back into Sensei for the KO!",
		"lesson_summary": "Retaliate reflects the attacker's raw incoming Damage right back at them (reduced only by the attacker's own Block/Dodge). When a hard-hitting attack can't be Parried or you can afford to soak the hit, Retaliate turns their biggest attack into a lethal boomerang!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 4, "p1_max_sp": 5, "p1_start_sp": 2,
		"p1_cards": ["Redirect", "Crushing Block", "Basic Parry", "Basic Block"],
		"p2_max_hp": 6, "p2_start_hp": 3, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Lariat"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Lariat"],
		"show_enemy_intent": true,
		"turn_limit": 1, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_wall_super_unlock",
		"title": "Push to the Brink",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 22,
		"difficulty": 3,
		"focus_trait": "WALL PUSH → SUPER UNLOCK",
		"objective_short": "Pin Sensei to the Wall on Clash 1 and unleash your Super to KO (6 HP) on Clash 2!",
		"briefing_text": "Super moves stay locked until you pin your opponent all the way to their Wall (Momentum 1)! You're at Momentum 4 while Sensei uses Push Kick (Momentum 1) to resist — pick the move with enough push to reach the Wall!",
		"hint_text": "Basic Heavy (Mom 3) minus Sensei's Push Kick (Mom 1) only reaches Momentum 2 (1 slot short!). Clash 1: Play Knee Crush (Cost 3, Mom 4 − 1 = 3 → reaches Mom 1 Wall!). Clash 2: Vital Point Assault (Super, Guard Break, Dmg 2, Repeat 3) unlocks and shreds Perfect Block for 6 damage!",
		"lesson_summary": "Super actions are game-ending finishers that unlock the moment you pin your opponent at their Wall (Momentum 1 for P1). High-momentum pushes like Knee Crush (Momentum 4) reach the Wall even through opposing momentum so you can drop a Super on the next clash!",
		"token_reward": 10,
		"p1_max_hp": 6, "p1_start_hp": 6, "p1_max_sp": 9, "p1_start_sp": 9,
		"p1_cards": ["Knee Crush", "Vital Point Assault", "Basic Heavy", "Basic Technical"],
		"p2_max_hp": 6, "p2_start_hp": 6, "p2_max_sp": 5, "p2_start_sp": 4,
		"p2_cards": ["Push Kick", "Perfect Block"],
		"start_momentum": 4, "start_combo_attacker": 1,
		"bot_moves": ["Push Kick", "Perfect Block"],
		"show_enemy_intent": true,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_feint_cure_injury",
		"title": "Fight Through the Pain",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 23,
		"difficulty": 3,
		"focus_trait": "INJURY CURE + OFFENSIVE FEINT",
		"objective_short": "Survive Injury at 1 HP AND KO Sensei (4 HP) within 2 Clashes!",
		"briefing_text": "You start INJURED at 1 HP — if you don't cure Injury with Heal or Fall Back on Clash 1, you'll bleed out at the end of the turn! Yet Sensei (4 HP) is behind Perfect Block (Block 4), so spending Clash 1 without dealing damage leaves you 1 short of lethal. Fuse cure + damage with Feint!",
		"hint_text": "Clash 1: Play Go with the Flow (Cost 3, Feint, Recover 1, Fall Back 1 → cures Injury!) and Feint-combine Basic Technical (Cost 2, Guard Break, Damage 1). You survive Injury, keep 3 SP (7 − 5 + 1), and chip Sensei to 3 HP! Clash 2: Perfect Strike (Cost 3, Guard Break, Damage 3) KOs Sensei!",
		"lesson_summary": "Injured deals 1 HP damage at the end of every clash until cured by Heal or Fall Back. Offensive Feints like Go with the Flow let you cure Injury AND attack in the exact same clash so you never lose lethal tempo!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 1, "p1_max_sp": 7, "p1_start_sp": 7,
		"p1_cards": ["Go with the Flow", "Basic Technical", "Perfect Strike", "Basic Positioning"],
		"p2_max_hp": 6, "p2_start_hp": 4, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Perfect Block"],
		"start_momentum": 3, "start_combo_attacker": 1,
		"start_p1_statuses": {"Injured": 1},
		"bot_moves": ["Perfect Block", "Perfect Block"],
		"show_enemy_intent": true,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_bleeding_out",
		"title": "Bleeding Out",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 24,
		"difficulty": 3,
		"focus_trait": "INJURED DoT TIMING",
		"objective_short": "KO Sensei (2 HP) behind Perfect Block within 2 Clashes using only 2 SP! (Inspect Sensei!)",
		"briefing_text": "Sensei has 2 HP and hides behind Perfect Block (Block 4) with no Heal or Fall Back moves. You only have 2 SP total — enough for ONE Basic Technical (1 Dmg), not two. Use Injury bleed to score the second point of damage!",
		"hint_text": "Injury ticks at the end of every clash AFTER the clash it was applied! Clash 1: Play Twist Arm (Cost 0, Injure) — it applies Injured even through Perfect Block while saving all 2 SP! Clash 2: Play Basic Technical (Cost 2, Guard Break, 1 Dmg) → Sensei drops to 1 HP, then Injured ticks for the 2nd HP KO!",
		"lesson_summary": "Injured can be applied even through Block (though not Dodge/Parry) and deals 1 unavoidable HP damage at the end of every subsequent clash until cured by Heal or Fall Back. Against pure-Block defenders, inflicting Injured early guarantees free chip damage!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 4, "p1_start_sp": 2,
		"p1_cards": ["Twist Arm", "Basic Technical", "Basic Heavy", "Basic Light"],
		"p2_max_hp": 6, "p2_start_hp": 2, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Perfect Block"],
		"start_momentum": 3, "start_combo_attacker": 1,
		"bot_moves": ["Perfect Block", "Perfect Block"],
		"show_enemy_intent": false,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_stamina_choke",
		"title": "Stamina Choke",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 25,
		"difficulty": 3,
		"focus_trait": "DEFENSIVE TIRING ENDS COMBO",
		"objective_short": "Cut Sensei's combo short on Clash 1 and KO them (1 HP) on Clash 2!",
		"briefing_text": "Sensei has 5 SP and is attacking with Basic Heavy (Cost 3). Normally they'd still have 2 SP left to keep attacking on Clash 2 — use a defensive Tiring move to drain their remaining 2 SP to 0 and force an immediate Offence swap!",
		"hint_text": "Clash 1: Basic Parry leaves Sensei at 2 SP (combo continues!). Play Tiring Parry (Cost 1, Parry, Fall Back 2, Tiring 2) instead — it negates Heavy, steals Mom 5 → 4, AND drains Sensei's last 2 SP to 0 so their combo ends! Clash 2: Finish with Basic Light (Opener)!",
		"lesson_summary": "Tiring on Defence (like Tiring Parry or Draining Defence) isn't just about annoying the opponent — draining an attacker's leftover SP to 0 forces their combo to end early, handing Offence straight to you if Momentum is on your side!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 2, "p1_max_sp": 5, "p1_start_sp": 2,
		"p1_cards": ["Tiring Parry", "Basic Parry", "Basic Block", "Basic Light"],
		"p2_max_hp": 6, "p2_start_hp": 1, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Basic Heavy", "Basic Light", "Basic Reversal"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Heavy", "Basic Reversal"],
		"show_enemy_intent": true,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_slip_and_strike",
		"title": "Slip Behind & Strike Back",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 26,
		"difficulty": 3,
		"focus_trait": "DODGE + OPENING → RETALIATE",
		"objective_short": "Survive Clash 1 and KO Sensei (3 HP) from Defence on Clash 2!",
		"briefing_text": "You're at 4 HP on Defence while Sensei (3 HP) comes at you with Basic Technical (Cost 2, Guard Break) followed by Basic Heavy (3 Damage). You can't take the Guard Break's Tiring hit, AND you need an Opening to unlock your lethal Counter!",
		"hint_text": "Clash 1: Play Slip Behind (Cost 3, Dodge 2, Create Opening 1) — it completely dodges Basic Technical AND creates Opening 1! Clash 2: Strike Back (Cost 0, Counter 1, Retaliate, Injure) unlocks and reflects all 3 damage of Basic Heavy back for the KO!",
		"lesson_summary": "Dodge doesn't have to be passive! Slip Behind (Dodge 2 + Create Opening 1) turns a clean evade against Guard Break into an Opening that unlocks Counter payoffs like Strike Back (Retaliate) or Toppling Kick!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 4, "p1_max_sp": 5, "p1_start_sp": 3,
		"p1_cards": ["Slip Behind", "Strike Back", "Basic Dodge", "Basic Block"],
		"p2_max_hp": 6, "p2_start_hp": 3, "p2_max_sp": 5, "p2_start_sp": 5,
		"p2_cards": ["Basic Technical", "Basic Heavy"],
		"start_momentum": 5, "start_combo_attacker": 2,
		"bot_moves": ["Basic Technical", "Basic Heavy"],
		"show_enemy_intent": true,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_master_tech_chain",
		"title": "Master Tech Chain",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 27,
		"difficulty": 3,
		"focus_trait": "GUARD BREAK + OPPORTUNITY CHAIN",
		"objective_short": "KO Sensei (5 HP) within 2 Clashes with only 4 SP! (Inspect Sensei!)",
		"briefing_text": "Sensei has 5 HP and will play Perfect Block on Clash 1, then drop to Basic Block on Clash 2 (out of SP for Perfect Block). With only 4 SP total, Perfect Strike leaves you 1 SP short on Clash 2 — find the Guard Break that funds your finisher!",
		"hint_text": "Clash 1: Play Master Tech (Cost 3, Guard Break, Damage 2, Tiring 1, Opportunity 1) — deals 2 damage through Perfect Block AND grants Opportunity 1! Clash 2: Drop Kick is discounted from 2 SP → 1 SP (your last SP!) and deals 4 − 1 Block = 3 lethal damage!",
		"lesson_summary": "Offensive Opportunity generators like Master Tech (Guard Break + 2 Dmg + Opportunity 1) bridge tight stamina budgets — letting a 3-cost opener discount a 2-cost finisher (Drop Kick) down to 1 SP for a 5-damage 2-clash burst!",
		"token_reward": 10,
		"p1_max_hp": 5, "p1_start_hp": 5, "p1_max_sp": 5, "p1_start_sp": 4,
		"p1_cards": ["Master Tech", "Perfect Strike", "Drop Kick", "Basic Technical"],
		"p2_max_hp": 6, "p2_start_hp": 5, "p2_max_sp": 4, "p2_start_sp": 2,
		"p2_cards": ["Perfect Block", "Basic Block"],
		"start_momentum": 3, "start_combo_attacker": 1,
		"bot_moves": ["Perfect Block", "Basic Block"],
		"show_enemy_intent": false,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

	_trials_cache.append(_make_trial({
		"id": "puzzle_ten_hit_barrage",
		"title": "The Endless Barrage",
		"category": TrialData.Category.TACTICAL_PUZZLE,
		"order": 28,
		"difficulty": 3,
		"focus_trait": "QUICK + WALL + REPEAT SUPER",
		"objective_short": "KO the 9 HP Sensei within 2 Clashes using Quick's Relentless + Super! (Inspect Sensei!)",
		"briefing_text": "Sensei is a towering 9 HP boss at 0 SP (only able to play Basic Reversal), sitting at Momentum 4. You're Quick with 8 SP: you need to push Sensei all the way to the Wall (Momentum 1) on Clash 1 AND keep enough SP for your Repeat-10 Super on Clash 2!",
		"hint_text": "Basic Heavy spends 3 SP for 3 dmg (leaving only 5 SP = 5 hits = 8 total dmg, 1 short!). Instead, Clash 1: Play Roll Punch (Cost 1, Dmg 1, Mom 1, Repeat 3) — spends 3 SP for 3 dmg, pushes Mom 4 → 1 (Wall!), AND Quick's Relentless refunds +1 SP (6 SP left!). Clash 2: Unleash Ultimate Barrage (Super, Repeat 10) for 6 hits = 9 lethal damage!",
		"lesson_summary": "Combining Quick's Relentless SP refund (+1 SP every 3rd combo hit) with Repeat moves like Roll Punch lets you reach the Wall with extra stamina in the tank — turning Ultimate Barrage (Repeat 10) into a devastating multi-hit finisher!",
		"token_reward": 10,
		"p1_name": "Quick Master", "p1_class": CharacterData.ClassType.QUICK,
		"p1_max_hp": 6, "p1_start_hp": 6, "p1_max_sp": 8, "p1_start_sp": 8,
		"p1_cards": ["Roll Punch", "Ultimate Barrage", "Basic Heavy", "Basic Light"],
		"p2_max_hp": 9, "p2_start_hp": 9, "p2_max_sp": 4, "p2_start_sp": 0,
		"p2_cards": ["Basic Reversal", "Basic Dodge"],
		"start_momentum": 4, "start_combo_attacker": 1,
		"bot_moves": ["Basic Reversal", "Basic Reversal"],
		"show_enemy_intent": false,
		"turn_limit": 2, "require_enemy_ko": true,
	}))

#endregion
