extends Node

#region vars

const KEYWORD_DEFS: Dictionary = CombatGlossary.KEYWORD_DEFS
const CombatRulesScript = preload("res://Scripts/Battle/CombatRules.gd")

# ==========================================
# --- ACTIVE MATCH STATE ---
# ==========================================
var state: MatchState = MatchState.new()

### --- MODERN GDSCRIPT 2.0 SIGNALS ---
signal state_changed(new_state: State)
signal clash_resolved(winner_id: int, p1_card: ActionData, p2_card: ActionData, results: Dictionary)
signal combat_log_updated(text: String)
signal game_over(winner_id: int)
signal damage_dealt(target_id: int, amount: int, is_blocked: bool)
signal healing_received(target_id: int, amount: int)
signal status_applied(target_id: int, status_name: String)
signal combat_callout(target_id: int, text: String, color: Color)
signal request_clash_animation(p1_card: ActionData, p2_card: ActionData)
signal clash_animation_finished
signal wall_crush_occurred(player_id: int, damage_amount: int)
signal sync_advance_approved
signal snapshot_applied

# --- CONFIGURATION ---
var TOTAL_MOMENTUM_SLOTS: int = 8 
var current_environment_name: String = "Dojo"
var environment_backgrounds: Dictionary = {}
var MOMENTUM_P1_MAX: int = 4
var MOMENTUM_P2_START: int = 5

# --- MATCH SETUP CONFIG (Typed replacement for loose temp_* globals) ---
class MatchSetupConfig:
	var p1_class_selection: int = 0
	var p2_class_selection: int = 0
	var p1_name: String = ""
	var p2_name: String = ""
	var p1_preset: Resource = null
	var p2_preset: Resource = null

	func reset() -> void:
		p1_class_selection = 0
		p2_class_selection = 0
		p1_name = ""
		p2_name = ""
		p1_preset = null
		p2_preset = null

# --- STATE MACHINE ---
enum State { SETUP, SELECTION, REVEAL, FEINT_CHECK, RESOLUTION, POST_CLASH, GAME_OVER }
var current_state: State = State.SETUP
var match_config: MatchSetupConfig = MatchSetupConfig.new()
var editing_player_index: int = 1
var p2_is_custom: bool = false
enum Difficulty { VERY_EASY, EASY, MEDIUM, HARD }
var ai_difficulty: Difficulty = Difficulty.MEDIUM

# --- PERSISTENT GAME SETUP ---
var next_match_p1_data: CharacterData
var next_match_p2_data: CharacterData

# --- CORE DATA ---
var p1_data: CharacterData
var p2_data: CharacterData

var rival_intro_override: String = ""

# --- NETWORK VARS ---
var p1_network_id: int = 0
var p2_network_id: int = 0
var _is_sync_approved: bool = false
var _match_epoch: int = 0
#endregion

func bump_match_epoch() -> void:
	_match_epoch += 1

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_load_backgrounds()
	
	MOMENTUM_P1_MAX = int(TOTAL_MOMENTUM_SLOTS / 2.0)
	MOMENTUM_P2_START = MOMENTUM_P1_MAX + 1
	
	print("--- GAME MANAGER READY ---")
	print("Momentum Config: Total=", TOTAL_MOMENTUM_SLOTS, " | P1_Max=", MOMENTUM_P1_MAX, " | P2_Start=", MOMENTUM_P2_START)

func start_combat(p1: CharacterData, p2: CharacterData) -> void:
	p1_data = p1
	p2_data = p2
	reset_combat()

func reset_combat() -> void:
	_match_epoch += 1
	current_state = State.SETUP

	# --- 1. RESET STATS ---
	var p1_maintain: bool = RunManager.is_arcade_mode and RunManager.maintain_hp_enabled
	p1_data.reset_stats(p1_maintain) 
	p2_data.reset_stats(false)
	
	# --- 2. INJECT EVENT STATUSES ---
	if RunManager.is_arcade_mode:
		for s: String in RunManager.next_fight_statuses:
			p1_data.statuses[s] = 1
		RunManager.next_fight_statuses.clear()
	
	# --- 3. THE MAGIC RESET ---
	state = MatchState.new()
	
	# --- 4. APPLY PLAYER & ENEMY EQUIPMENT / SPONSOR BONUSES ---
	var total_p1_momentum_bonus: int = 0
	var total_p2_momentum_bonus: int = 0
	var p1_speed_bonus: int = 0
	var p2_speed_bonus: int = 0
	var p1_starting_opportunity: int = 0
	var p2_starting_opportunity: int = 0
	
	var all_p1_modifiers: Array[BaseModifierData] = CombatRulesScript.get_all_modifiers_for(1)
	for mod: BaseModifierData in all_p1_modifiers:
		p1_data.current_sp = maxi(0, p1_data.current_sp + mod.starting_sp_bonus)
		if mod.starting_barrier > 0:
			p1_data.current_hp += mod.starting_barrier
			print("Modifier Barrier Applied: +%d HP" % mod.starting_barrier)
			
		total_p1_momentum_bonus += mod.momentum_start_bonus
		p1_speed_bonus += mod.bonus_speed
		p1_starting_opportunity += mod.starting_opportunity

	if RunManager.is_arcade_mode and RunManager.is_rival_match and RunManager.active_sponsor:
		total_p1_momentum_bonus -= RunManager.active_sponsor.rival_momentum_handicap
		print("Rival Handicap Applied! Momentum shifted by " + str(RunManager.active_sponsor.rival_momentum_handicap))

	var all_p2_modifiers: Array[BaseModifierData] = CombatRulesScript.get_all_modifiers_for(2)
	for item: BaseModifierData in all_p2_modifiers:
		p2_data.current_sp = maxi(0, p2_data.current_sp + item.starting_sp_bonus)
		if item.starting_barrier > 0:
			p2_data.current_hp += item.starting_barrier
		total_p2_momentum_bonus += item.momentum_start_bonus
		p2_speed_bonus += item.bonus_speed
		p2_starting_opportunity += item.starting_opportunity

	if p1_starting_opportunity > 0:
		state.p1_opportunity_stat += p1_starting_opportunity
	if p2_starting_opportunity > 0:
		state.p2_opportunity_stat += p2_starting_opportunity

	# --- 5. APPLY MOMENTUM STARTING POSITION ---
	var net_momentum_bonus: int = total_p1_momentum_bonus - total_p2_momentum_bonus
	if net_momentum_bonus > 0:
		state.momentum = MOMENTUM_P1_MAX - (net_momentum_bonus - 1)
		state.momentum = clampi(state.momentum, 1, MOMENTUM_P1_MAX)
		print(">> P1 Head Start! Momentum set to: " + str(state.momentum))
	elif net_momentum_bonus < 0:
		state.momentum = MOMENTUM_P2_START + (absi(net_momentum_bonus) - 1)
		state.momentum = clampi(state.momentum, MOMENTUM_P2_START, TOTAL_MOMENTUM_SLOTS)
		print(">> P2 Head Start! Momentum set to: " + str(state.momentum))
		
	# --- 6. APPLY GYM BUFFS ---
	if RunManager.is_arcade_mode and RunManager.active_gym_buff != "":
		print("Applying Gym Buff: " + RunManager.active_gym_buff)
		if RunManager.active_gym_buff == "iron_stance":
			state.p1_gym_block_bonus = 1
			print(">> Iron Stance: +1 Global Block")
		elif RunManager.active_gym_buff == "exploit_weakness":
			var damage: int = maxi(1, roundi(p2_data.max_hp * 0.2))
			p2_data.current_hp -= damage
			print(">> Exploit Weakness: Enemy took " + str(damage) + " dmg")
		RunManager.active_gym_buff = ""
	
	# --- 7. CALCULATE PRIORITY (SPEED TIES) ---
	var p1_final_speed: int = p1_data.speed + p1_speed_bonus
	var p2_final_speed: int = p2_data.speed + p2_speed_bonus
	
	if p1_final_speed > p2_final_speed: 
		state.priority_player = 1
	elif p2_final_speed > p1_final_speed: 
		state.priority_player = 2
	else: 
		state.priority_player = randi_range(1, 2)
		
	print("\n>>> COMBAT RESET! Starting from Initial Clash (Neutral) <<<")
	if AudioManager:
		AudioManager.set_music_intensity(1.0, 2.0)

func get_attacker() -> int:
	if state.current_combo_attacker != 0: return state.current_combo_attacker
	if state.attacker_override != 0: return state.attacker_override
	if state.momentum == 0: return 0 
	return 1 if state.momentum <= MOMENTUM_P1_MAX else 2

# ==============================================================================
# STATE MACHINE
# ==============================================================================

func change_state(new_state: State) -> void:
	var my_role: String = "Referee (Server)"
	if multiplayer.has_multiplayer_peer():
		var my_id: int = multiplayer.get_unique_id()
		if my_id == p1_network_id: my_role = "Player 1"
		elif my_id == p2_network_id: my_role = "Player 2"
		
	print("⏱️ [STATE SYNC] ", my_role, " entering state: ", State.keys()[new_state])
	
	current_state = new_state
	emit_signal("state_changed", current_state)
	
	match current_state:
		State.SELECTION:
			pass
		State.REVEAL:
			_enter_reveal_phase()
		State.FEINT_CHECK:
			pass 
		State.RESOLUTION:
			resolve_clash()

func player_select_action(player_id: int, action: ActionData, extra_data: Dictionary = {}) -> void:
	var tech_idx: int = int(extra_data.get("technique", 0))
	var final_action: ActionData = CombatRulesScript.apply_technique(action, tech_idx)
	
	# During FEINT_CHECK, pass the secondary card straight to _handle_feint_selection
	# WITHOUT overwriting state.p1_action_queue / p2_action_queue (which holds the base Feint card).
	if current_state == State.FEINT_CHECK:
		_handle_feint_selection(player_id, final_action)
		return

	if player_id == 1:
		state.p1_action_queue = final_action
		state.p1_rage_active = bool(extra_data.get("rage", false))
	else:
		state.p2_action_queue = final_action
		state.p2_rage_active = bool(extra_data.get("rage", false))
		
	if current_state == State.SELECTION:
		if state.p1_action_queue and state.p2_action_queue:
			change_state(State.REVEAL)

# ==============================================================================
# FEINT MECHANICS
# ==============================================================================

func _enter_reveal_phase() -> void:
	var epoch: int = _match_epoch
	_is_sync_approved = false
	
	combat_log_updated.emit("\nREVEAL: P1 chose " + state.p1_action_queue.display_name + " | P2 chose " + state.p2_action_queue.display_name)
	request_clash_animation.emit(state.p1_action_queue, state.p2_action_queue)

	# --- 1. HEADLESS SERVER FIX & SAFETY TIMER ---
	if multiplayer.is_server() and DisplayServer.get_name() == "headless":
		var net_manager: Node = get_node("/root/NetworkManager")
		net_manager._animation_timeout = get_tree().create_timer(10.0)
		net_manager._animation_timeout.timeout.connect(net_manager._on_handshake_timeout)
	else:
		await clash_animation_finished
		if epoch != _match_epoch or current_state != State.REVEAL:
			return

	# --- 2. NETWORK SYNC CHECK ---
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		if not multiplayer.is_server():
			var net_manager: Node = get_node("/root/NetworkManager")
			net_manager.report_animation_done.rpc_id(1)
			
		if not _is_sync_approved:
			await sync_advance_approved
			if epoch != _match_epoch or current_state != State.REVEAL:
				return

	if state.p1_action_queue == null or state.p2_action_queue == null:
		return

	state.p1_pending_feint = state.p1_action_queue.feint
	state.p2_pending_feint = state.p2_action_queue.feint

	if state.p1_pending_feint or state.p2_pending_feint:
		change_state(State.FEINT_CHECK)
	else:
		change_state(State.RESOLUTION)
		
func _handle_feint_selection(player_id: int, secondary_action: ActionData) -> void:
	if secondary_action == null:
		emit_signal("combat_log_updated", "P" + str(player_id) + " skips Feint combination.")
		_clear_feint_flag(player_id)
		_check_feint_completion()
		return

	var base_card: ActionData = state.p1_action_queue if player_id == 1 else state.p2_action_queue
	var character: CharacterData = p1_data if player_id == 1 else p2_data
	
	var total_cost: int = base_card.cost + secondary_action.cost
	var opp_val: int = _get_opportunity_value(player_id)
	var effective_total: int = maxi(0, total_cost - opp_val)
	
	var combined_card: ActionData = _combine_actions(base_card, secondary_action)
	# Repeat pays per hit (up to repeat_count), so at least 1 hit must be affordable
	var total_required: int = effective_total
	
	var can_afford: bool = false
	if character.current_sp >= total_required:
		can_afford = true
	elif character.can_pay_with_hp and (character.current_sp + character.current_hp) > total_required:
		can_afford = true 
		
	if can_afford:
		emit_signal("combat_log_updated", "P" + str(player_id) + " Feint Successful! Combined into: " + combined_card.display_name)
		combat_callout.emit(player_id, "FEINT COMBINED!", Color(0.45, 0.9, 1.0))
		if player_id == 1: state.p1_action_queue = combined_card
		else: state.p2_action_queue = combined_card
	else:
		emit_signal("combat_log_updated", "P" + str(player_id) + " not enough SP for Feint. Action applies normally.")
	
	_clear_feint_flag(player_id)
	_check_feint_completion()

func _clear_feint_flag(player_id: int) -> void:
	if player_id == 1: state.p1_pending_feint = false
	else: state.p2_pending_feint = false

func _check_feint_completion() -> void:
	if not state.p1_pending_feint and not state.p2_pending_feint:
		change_state(State.RESOLUTION)

func _combine_actions(base: ActionData, sec: ActionData) -> ActionData:
	var new_card: ActionData = base.duplicate() as ActionData
	new_card.display_name = base.display_name + " + " + sec.display_name
	
	new_card.cost += sec.cost
	new_card.damage += sec.damage
	new_card.block_value += sec.block_value
	new_card.dodge_value += sec.dodge_value
	new_card.momentum_gain += sec.momentum_gain
	new_card.heal_value += sec.heal_value
	new_card.recover_value += sec.recover_value
	new_card.fall_back_value += sec.fall_back_value
	new_card.tiring += sec.tiring
	new_card.create_opening += sec.create_opening
	new_card.multi_limit += sec.multi_limit
	new_card.opportunity += sec.opportunity
	
	new_card.counter_value = maxi(new_card.counter_value, sec.counter_value) 
	new_card.repeat_count = maxi(new_card.repeat_count, sec.repeat_count)
	
	if sec.guard_break: new_card.guard_break = true
	if sec.retaliate: new_card.retaliate = true
	if sec.is_parry: new_card.is_parry = true
	if sec.reversal: new_card.reversal = true
	if sec.sweep: new_card.sweep = true
	if sec.is_super: new_card.is_super = true
	if sec.is_opener: new_card.is_opener = true
	
	new_card.statuses_to_apply.clear()
	for s: Dictionary in base.statuses_to_apply:
		new_card.statuses_to_apply.append(s.duplicate(true))
	for s: Dictionary in sec.statuses_to_apply:
		new_card.statuses_to_apply.append(s.duplicate(true))
	
	new_card.feint = false 
	return new_card

# ==============================================================================
# RESOLUTION LOGIC
# ==============================================================================

### ==============================================================================
### RESOLUTION LOGIC (GDScript 2.0 Modernized)
### ==============================================================================

func resolve_clash() -> void:
	state.attacker_override = 0

	# --- RECORD AI MEMORY BEFORE QUEUES ARE CLEARED ---
	if state.p1_action_queue != null:
		state.p1_last_action_name = state.p1_action_queue.display_name
		state.p1_last_cost = state.p1_action_queue.cost
	else:
		state.p1_last_action_name = ""
		state.p1_last_cost = 0

	if state.p2_action_queue != null:
		state.p2_last_action_name = state.p2_action_queue.display_name
		state.p2_last_cost = state.p2_action_queue.cost
	else:
		state.p2_last_action_name = ""
		state.p2_last_cost = 0

	state.p1_action_queue = state.p1_action_queue.duplicate()
	state.p2_action_queue = state.p2_action_queue.duplicate()

	var winner_id: int = 0

	if state.p1_action_queue.type == ActionData.Type.OFFENCE and state.p2_action_queue.type == ActionData.Type.DEFENCE: 
		winner_id = 1
	elif state.p2_action_queue.type == ActionData.Type.OFFENCE and state.p1_action_queue.type == ActionData.Type.DEFENCE: 
		winner_id = 2
	elif state.p1_action_queue.cost < state.p2_action_queue.cost: 
		winner_id = 1
	elif state.p2_action_queue.cost < state.p1_action_queue.cost: 
		winner_id = 2
	else:
		combat_log_updated.emit("Tie! Priority Token Used.")
		winner_id = state.priority_player
		swap_priority()

	var log_text: String = "Clash Winner: P" + str(winner_id)
	clash_resolved.emit(winner_id, state.p1_action_queue, state.p2_action_queue, {"log_text": log_text})

	var is_initial_clash: bool = (state.momentum == 0)

	var p1_started_injured: bool = has_status(1, "Injured")
	var p2_started_injured: bool = has_status(2, "Injured")

	var p1_hits: int = _pay_cost_for_hits(1, state.p1_action_queue)
	var p2_hits: int = _pay_cost_for_hits(2, state.p2_action_queue)
	var p1_active: bool = (p1_hits > 0)
	var p2_active: bool = (p2_hits > 0)

	if p1_active:
		_handle_patient_passive(1, state.p1_action_queue)
	if p2_active:
		_handle_patient_passive(2, state.p2_action_queue)

	# Count each Repeat hit toward combo_action_count & Relentless SP recovery
	if p1_active and winner_id == 1 and state.p1_action_queue.type == ActionData.Type.OFFENCE:
		if state.current_combo_attacker != 1:
			p1_data.combo_action_count = 0
		_advance_combo_hits(1, p1_hits)
	else:
		p1_data.combo_action_count = 0

	if p2_active and winner_id == 2 and state.p2_action_queue.type == ActionData.Type.OFFENCE:
		if state.current_combo_attacker != 2:
			p2_data.combo_action_count = 0
		_advance_combo_hits(2, p2_hits)
	else:
		p2_data.combo_action_count = 0

	if p1_active and state.p1_action_queue.is_super:
		p1_data.has_used_super = true
		combat_log_updated.emit(">> P1 unleashes their Ultimate Art!")
	if p2_active and state.p2_action_queue.is_super:
		p2_data.has_used_super = true
		combat_log_updated.emit(">> P2 unleashes their Ultimate Art!")

	if p1_active: _apply_phase_1_self_effects(1, state.p1_action_queue, p1_hits)
	if p2_active: _apply_phase_1_self_effects(2, state.p2_action_queue, p2_hits)

	var p1_is_dodged: bool = false
	var p2_is_dodged: bool = false
	
	var p1_reps: int = p1_hits if p1_active else 1
	var p2_reps: int = p2_hits if p2_active else 1
	
	var p1_total_cost: int = state.p1_action_queue.cost * p1_reps
	var p2_total_cost: int = state.p2_action_queue.cost * p2_reps

	if p2_active and state.p2_action_queue.dodge_value > 0 and state.p2_action_queue.dodge_value >= p1_total_cost: 
		p1_is_dodged = true
	if p1_active and state.p1_action_queue.dodge_value > 0 and state.p1_action_queue.dodge_value >= p2_total_cost: 
		p2_is_dodged = true

	var p1_parries: bool = (p1_active and state.p1_action_queue.is_parry)
	var p2_parries: bool = (p2_active and state.p2_action_queue.is_parry)

	var p1_single_gain: int = (state.p1_action_queue.momentum_gain + _get_opportunity_value(1)) if p1_active else 0
	var p2_single_gain: int = (state.p2_action_queue.momentum_gain + _get_opportunity_value(2)) if p2_active else 0

	var p1_total_gain: int = _calculate_projected_momentum(1, state.p1_action_queue, p1_active, p1_hits)
	var p2_total_gain: int = _calculate_projected_momentum(2, state.p2_action_queue, p2_active, p2_hits)

	var p1_stolen: int = p2_single_gain if p1_parries else 0
	var p2_stolen: int = p1_single_gain if p2_parries else 0

	var p1_fb: int = (state.p1_action_queue.fall_back_value * p1_reps) if p1_active else 0
	var p2_fb: int = (state.p2_action_queue.fall_back_value * p2_reps) if p2_active else 0

	if p1_fb > 0 and state.momentum >= TOTAL_MOMENTUM_SLOTS:
		_apply_wall_crush(1, p1_fb)
		p1_fb = 0 
		
	if p2_fb > 0 and state.momentum <= 1:
		_apply_wall_crush(2, p2_fb)
		p2_fb = 0 

	var p1_contribution: int = p1_total_gain
	if p2_parries: p1_contribution = max(0, p1_contribution - p1_single_gain)
	if p1_is_dodged: p1_contribution = 0

	var p2_contribution: int = p2_total_gain
	if p1_parries: p2_contribution = max(0, p2_contribution - p2_single_gain)
	if p2_is_dodged: p2_contribution = 0

	var p1_final_push: int = p1_contribution + p1_stolen
	var p2_final_push: int = p2_contribution + p2_stolen

	var delta: int = (-p1_final_push + p1_fb) + (p2_final_push - p2_fb)

	# Glossary rule: Parry succeeds iff it causes the momentum tracker to move in the parrier's direction
	var p1_parry_success: bool = (p1_parries and delta < 0)
	var p2_parry_success: bool = (p2_parries and delta > 0)
	if p1_parry_success:
		combat_callout.emit(1, "PARRIED!", Color(1.0, 0.88, 0.25))
	if p2_parry_success:
		combat_callout.emit(2, "PARRIED!", Color(1.0, 0.88, 0.25))

	var p1_results: Dictionary = { "fatal": false, "opening": 0, "opportunity": 0 }
	var p2_results: Dictionary = { "fatal": false, "opening": 0, "opportunity": 0 }

	var p2_immune_or_dodged: bool = p2_parry_success or p1_is_dodged
	var p1_immune_or_dodged: bool = p1_parry_success or p2_is_dodged

	if p1_active: 
		p1_results = _apply_phase_2_combat_effects(1, 2, state.p1_action_queue, state.p2_action_queue, p2_immune_or_dodged, p1_hits, p2_active)
	if p2_active: 
		p2_results = _apply_phase_2_combat_effects(2, 1, state.p2_action_queue, state.p1_action_queue, p1_immune_or_dodged, p2_hits, p1_active)

	_update_turn_constraints(p1_results, p2_results, state.p1_action_queue, state.p2_action_queue, p1_parry_success, p2_parry_success, p1_active, p2_active)

	if p1_results.get("fatal", false) or p2_results.get("fatal", false):
		_handle_death(winner_id)
		return 

	var p1_reversed: bool = (p1_active and state.p1_action_queue.reversal and delta < 0)
	var p2_reversed: bool = (p2_active and state.p2_action_queue.reversal and delta > 0)

	if is_initial_clash:
		state.momentum = MOMENTUM_P1_MAX if winner_id == 1 else MOMENTUM_P2_START
		print("DEBUG: Initial Clash Winner: P", winner_id, " | Set Mom: ", state.momentum)
		
		if p1_reversed:
			state.attacker_override = 1
			combat_callout.emit(1, "REVERSAL!", Color(0.35, 1.0, 0.85))
			combat_log_updated.emit(">> P1 Reverses! Seizing Offence.")
		elif p2_reversed:
			state.attacker_override = 2
			combat_callout.emit(2, "REVERSAL!", Color(0.35, 1.0, 0.85))
			combat_log_updated.emit(">> P2 Reverses! Seizing Offence.")
	else:
		state.momentum = clamp_momentum(state.momentum + delta)
		
		if p1_reversed:
			state.attacker_override = 1
			combat_callout.emit(1, "REVERSAL!", Color(0.35, 1.0, 0.85))
			combat_log_updated.emit(">> P1 REVERSAL SUCCESSFUL!")
		elif p2_reversed:
			state.attacker_override = 2
			combat_callout.emit(2, "REVERSAL!", Color(0.35, 1.0, 0.85))
			combat_log_updated.emit(">> P2 REVERSAL SUCCESSFUL!")

	_handle_status_damage(p1_started_injured, p2_started_injured)
	_check_reversal_state() 
	_handle_locks(winner_id, p1_active, p2_active)
	_update_dynamic_music()

	state.p1_action_queue = null
	state.p2_action_queue = null

	if p1_data.current_hp <= 0 or p2_data.current_hp <= 0:
		_handle_death(winner_id)
		return

	# [NEW] Optional intermediate POST_CLASH phase, removed double SELECTION call
	change_state(State.POST_CLASH)

	# [NEW SYNC TRIGGER] 
	# Force clients to align with the server's final calculation before the next turn starts
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		broadcast_state_snapshot()
		
	change_state(State.SELECTION)

# ==============================================================================
# PHASE IMPLEMENTATIONS
# ==============================================================================

func _apply_wall_crush(player_id: int, amount: int) -> void:
	var character: CharacterData = p1_data if player_id == 1 else p2_data
	var attacker_id: int = 2 if player_id == 1 else 1
	var final_amount: int = amount
	
	for mod: BaseModifierData in CombatRulesScript.get_all_modifiers_for(attacker_id):
		final_amount += mod.wall_crush_damage_bonus
	
	emit_signal("wall_crush_occurred", player_id, final_amount)
	combat_callout.emit(player_id, "WALL CRUSH -" + str(final_amount) + "!", Color(1.0, 0.25, 0.25))
	emit_signal("combat_log_updated", ">> P" + str(player_id) + " CRUSHED against the wall!")
	
	if character.current_sp >= final_amount:
		character.current_sp -= final_amount
		emit_signal("combat_log_updated", "   Lost " + str(final_amount) + " SP to hold ground.")
	else:
		var sp_paid: int = character.current_sp
		var hp_damage: int = final_amount - sp_paid
		
		character.current_sp = 0
		character.current_hp -= hp_damage
		
		emit_signal("combat_log_updated", "   Lost " + str(sp_paid) + " SP and took " + str(hp_damage) + " HP DAMAGE!")
		emit_signal("damage_dealt", player_id, hp_damage, false)

## Returns true if [param player_id] has any equipment or sponsor that disables Supers.
func is_super_disabled(player_id: int) -> bool:
	for mod: BaseModifierData in CombatRulesScript.get_all_modifiers_for(player_id):
		if mod.disable_supers:
			return true
	return false

## Returns true if [param player_id] has any equipment or sponsor that reveals the enemy opener.
func has_reveal_enemy_opener(player_id: int) -> bool:
	for mod: BaseModifierData in CombatRulesScript.get_all_modifiers_for(player_id):
		if mod.reveal_enemy_opener:
			return true
	return false

## Returns the effective combo hit interval for SP recovery (0 = disabled).
func get_effective_combo_sp_rate(owner_id: int) -> int:
	var character: CharacterData = p1_data if owner_id == 1 else p2_data
	if character == null:
		return 0
	var bonus: int = 0
	for mod: BaseModifierData in CombatRulesScript.get_all_modifiers_for(owner_id):
		bonus += mod.combo_sp_regen_bonus
	if character.combo_sp_recovery_rate > 0:
		return maxi(2, character.combo_sp_recovery_rate - bonus)
	if bonus > 0:
		return maxi(2, 4 - bonus)
	return 0

func _advance_combo_hits(owner_id: int, hits: int) -> void:
	var character: CharacterData = p1_data if owner_id == 1 else p2_data
	var rate: int = get_effective_combo_sp_rate(owner_id)
	for _i in range(hits):
		character.combo_action_count += 1
		if rate > 0 and (character.combo_action_count % rate == 0):
			character.current_sp = mini(character.current_sp + 1, character.max_sp)
			combat_callout.emit(owner_id, "RELENTLESS +1 SP!", Color(0.45, 1.0, 0.55))
			emit_signal("combat_log_updated", ">> Flow! P" + str(owner_id) + " recovers 1 SP.")

func _apply_phase_1_self_effects(owner_id: int, my_card: ActionData, hits: int = -1) -> void:
	var character: CharacterData = p1_data if owner_id == 1 else p2_data
	var total_hits: int = hits if hits > 0 else maxi(1, my_card.repeat_count)
	
	for i in range(total_hits):
		var actual_recover: int = my_card.recover_value
		if my_card.type == ActionData.Type.DEFENCE: actual_recover += 1
		
		if actual_recover > 0: 
			character.current_sp = mini(character.current_sp + actual_recover, character.max_sp)
			
		if my_card.heal_value > 0: 
			character.current_hp = mini(character.current_hp + my_card.heal_value, character.max_hp)
			emit_signal("healing_received", owner_id, my_card.heal_value)

		if my_card.heal_value > 0 or my_card.fall_back_value > 0 or my_card.recover_value > 0:
			if has_status(owner_id, "Injured"):
				remove_status(owner_id, "Injured")
				emit_signal("combat_log_updated", ">> P" + str(owner_id) + " cures Injury!")

func _apply_phase_2_combat_effects(owner_id: int, target_id: int, my_card: ActionData, enemy_card: ActionData, target_is_immune: bool, hits: int = -1, enemy_active: bool = true) -> Dictionary:
	var character: CharacterData = p1_data if owner_id == 1 else p2_data
	var target: CharacterData = p2_data if owner_id == 1 else p1_data
	var result: Dictionary = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	if target_is_immune:
		emit_signal("combat_log_updated", "P" + str(owner_id) + " attack NULLIFIED (Dodge/Parry)!")
		emit_signal("status_applied", owner_id, "MISS")
		emit_signal("status_applied", target_id, "DODGED")
		return result

	var dmg_mod: int = 0
	var attacker_block_mod: int = 0 
	var defender_block_mod: int = 0
	var thorns_dmg: int = 0
	
	for mod: BaseModifierData in CombatRulesScript.get_all_modifiers_for(owner_id):
		dmg_mod += mod.damage_modifier
		attacker_block_mod += mod.block_modifier
		
	for mod: BaseModifierData in CombatRulesScript.get_all_modifiers_for(target_id):
		defender_block_mod += mod.block_modifier
		thorns_dmg += mod.thorns
		
	if owner_id == 1:
		attacker_block_mod += state.p1_gym_block_bonus
	elif target_id == 1:
		defender_block_mod += state.p1_gym_block_bonus
		
	var total_hits: int = hits if hits > 0 else maxi(1, my_card.repeat_count)
	for i in range(total_hits):
		# Only buff cards that actually deal damage (so +Damage equipment doesn't turn Block/Positioning into attacks)
		var total_damage: int = maxi(0, my_card.damage + dmg_mod) if my_card.damage > 0 else 0
		var enemy_block: int = (maxi(0, enemy_card.block_value + defender_block_mod) if enemy_card.block_value > 0 else 0) if enemy_active else 0
		
		if my_card.guard_break:
			if enemy_block > 0 and i == 0:
				combat_callout.emit(target_id, "GUARD BREAK!", Color(1.0, 0.55, 0.15))
			enemy_block = 0
			
		var net_damage: int = maxi(0, total_damage - enemy_block)
		
		if my_card.tiring > 0:
			if target.tiring_drains_hp and target.current_sp < my_card.tiring:
				var drain_amount: int = my_card.tiring
				var sp_avail: int = target.current_sp
				var hp_cost: int = drain_amount - sp_avail
				target.current_sp = 0
				target.current_hp -= hp_cost
				combat_callout.emit(target_id, "TIRING -" + str(hp_cost) + " HP!", Color(1.0, 0.4, 0.25))
				emit_signal("combat_log_updated", ">> Rage! P" + str(target_id) + " takes " + str(hp_cost) + " HP dmg instead of SP.")
				emit_signal("damage_dealt", target_id, hp_cost, false)
			else:
				var prev_sp: int = target.current_sp
				target.current_sp = maxi(0, target.current_sp - my_card.tiring)
				var drained_sp: int = prev_sp - target.current_sp
				if drained_sp > 0:
					combat_callout.emit(target_id, "TIRING -" + str(drained_sp) + " SP", Color(1.0, 0.82, 0.35))
				emit_signal("combat_log_updated", ">> Tiring! P" + str(target_id) + " drained of " + str(my_card.tiring) + " SP.")
		
		for effect: Dictionary in my_card.statuses_to_apply:
			var s_name: String = str(effect.get("name", "Unknown"))
			var s_val: int = int(effect.get("amount", 1))
			var is_self: bool = bool(effect.get("self", false))
			var dest_id: int = owner_id if is_self else target_id
			
			if not has_status(dest_id, s_name):
				apply_status(dest_id, s_name, s_val)

		if my_card.create_opening > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " creates an Opening! (Lvl " + str(my_card.create_opening) + ")")
			result["opening"] = my_card.create_opening
		
		if my_card.opportunity > 0:
			result["opportunity"] = my_card.opportunity

		if net_damage > 0:
			target.current_hp -= net_damage
			emit_signal("damage_dealt", target_id, net_damage, false)
			emit_signal("combat_log_updated", "P" + str(owner_id) + " hits P" + str(target_id) + ": -" + str(net_damage) + " HP")
			
			if thorns_dmg > 0:
				character.current_hp -= thorns_dmg
				emit_signal("damage_dealt", owner_id, thorns_dmg, false)
				emit_signal("combat_log_updated", ">> Spikes! P" + str(owner_id) + " took " + str(thorns_dmg) + " Thorns damage!")
				
				if character.current_hp <= 0:
					result["fatal"] = true
					return result
					
		elif total_damage > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " attack blocked (0 Dmg).")
			emit_signal("damage_dealt", target_id, 0, true)

		if total_damage > 0 and enemy_active and enemy_card.retaliate:
			var raw_recoil: int = total_damage
			var self_block_val: int = maxi(0, my_card.block_value + attacker_block_mod) if my_card.block_value > 0 else 0
			var self_block: int = self_block_val + my_card.dodge_value
			var net_recoil: int = maxi(0, raw_recoil - self_block)
			
			if net_recoil > 0:
				character.current_hp -= net_recoil
				combat_callout.emit(owner_id, "RETALIATE -" + str(net_recoil) + "!", Color(1.0, 0.35, 0.85))
				emit_signal("damage_dealt", owner_id, net_recoil, false)
				emit_signal("combat_log_updated", ">> RETALIATE! P" + str(target_id) + " reflects " + str(net_recoil) + " dmg!")
				
				if character.current_hp <= 0:
					result["fatal"] = true
					return result
			else:
				emit_signal("combat_log_updated", ">> RETALIATE! Reflected damage blocked by P" + str(owner_id) + ".")

		if target.current_hp <= 0:
			result["fatal"] = true
			return result
			
	RunManager.check_danger_state()		
	return result

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func _calculate_projected_momentum(player_id: int, card: ActionData, is_active: bool, hits: int = -1) -> int:
	if not is_active: return 0
	var opp_val: int = _get_opportunity_value(player_id)
	var total_hits: int = hits if hits > 0 else max(1, card.repeat_count)
	# Opportunity applies once per action (not multiplied by Repeat)
	return (card.momentum_gain * total_hits) + opp_val

func _get_opportunity_value(player_id: int) -> int:
	return state.p1_opportunity_stat if player_id == 1 else state.p2_opportunity_stat

## Returns how many hits (0..repeat_count) [param character] can afford for [param card].
## Opportunity discounts only the first hit; subsequent Repeat hits pay card.cost each while SP lasts.
func get_effective_repeat_count(character: CharacterData, card: ActionData, opp_val: int = 0, is_free: bool = false, rage_is_on: bool = false) -> int:
	var max_reps: int = max(1, card.repeat_count)
	if is_free:
		return max_reps
	var single_cost: int = max(0, card.cost)
	var first_hit_cost: int = max(0, single_cost - opp_val)
	if single_cost == 0:
		return max_reps
	if rage_is_on and character.can_pay_with_hp:
		var hp_budget: int = max(0, character.current_hp - 1)
		if hp_budget < first_hit_cost:
			return 0
		return 1 + min(max_reps - 1, floori(float(hp_budget - first_hit_cost) / float(single_cost)))
	if character.current_sp >= first_hit_cost:
		return 1 + min(max_reps - 1, floori(float(character.current_sp - first_hit_cost) / float(single_cost)))
	if character.can_pay_with_hp and (character.current_sp + character.current_hp) > first_hit_cost:
		return 1
	return 0

func _pay_cost_for_hits(player_id: int, card: ActionData) -> int:
	var character: CharacterData = p1_data if player_id == 1 else p2_data
	var is_free: bool = (state.p1_locked_card != null if player_id == 1 else state.p2_locked_card != null)
	var rage_is_on: bool = (state.p1_rage_active if player_id == 1 else state.p2_rage_active)
	var opp_val: int = _get_opportunity_value(player_id)

	var hits: int = get_effective_repeat_count(character, card, opp_val, is_free, rage_is_on)
	if hits <= 0:
		if rage_is_on and character.can_pay_with_hp:
			emit_signal("combat_log_updated", ">> RAGE failed! Not enough HP.")
		else:
			emit_signal("combat_log_updated", ">> P" + str(player_id) + " Out of SP! Action Fails!")
		return 0

	var single_cost: int = max(0, card.cost)
	var first_hit_cost: int = max(0, single_cost - opp_val)
	var total_cost: int = 0 if is_free else (first_hit_cost + single_cost * (hits - 1))

	if rage_is_on and character.can_pay_with_hp:
		character.current_hp -= total_cost
		combat_callout.emit(player_id, "RAGE -" + str(total_cost) + " HP!", Color(1.0, 0.3, 0.3))
		emit_signal("combat_log_updated", ">> RAGE! P" + str(player_id) + " pays " + str(total_cost) + " HP.")
		emit_signal("damage_dealt", player_id, total_cost, false)
		return hits

	if character.current_sp >= total_cost:
		character.current_sp -= total_cost
		return hits

	if character.can_pay_with_hp and (character.current_sp + character.current_hp) > total_cost:
		var sp_avail: int = character.current_sp
		var hp_cost: int = total_cost - sp_avail
		character.current_sp = 0
		character.current_hp -= hp_cost
		emit_signal("combat_log_updated", ">> Rage! P" + str(player_id) + " pays " + str(hp_cost) + " HP for action.")
		emit_signal("damage_dealt", player_id, hp_cost, false)
		return hits

	emit_signal("combat_log_updated", ">> P" + str(player_id) + " Out of SP! Action Fails!")
	return 0

func _handle_status_damage(p1_started_injured: bool, p2_started_injured: bool) -> void:
	for id: int in [1, 2]:
		var player: CharacterData = p1_data if id == 1 else p2_data
		var started_injured: bool = p1_started_injured if id == 1 else p2_started_injured
		
		for s_name: String in player.statuses.keys():
			match s_name:
				"Injured":
					if started_injured:
						player.current_hp -= 1
						emit_signal("combat_log_updated", ">> P" + str(id) + " suffers Injury damage!")
						emit_signal("damage_dealt", id, 1, false)
				"Poison":
					var stacks: int = int(player.statuses["Poison"])
					player.current_hp -= stacks
					emit_signal("combat_log_updated", ">> P" + str(id) + " takes Poison dmg!")
					emit_signal("damage_dealt", id, stacks, false)

func _handle_death(winner_id: int) -> void:
	if current_state == State.GAME_OVER:
		return
	current_state = State.GAME_OVER
	state.p1_action_queue = null
	state.p2_action_queue = null

	var game_winner: int = 0
	if p1_data.current_hp > 0: game_winner = 1
	elif p2_data.current_hp > 0: game_winner = 2
	else: game_winner = winner_id 
	
	if game_winner == 1 and RunManager.is_arcade_mode:
		var heal_amt: int = 0
		for mod: BaseModifierData in CombatRulesScript.get_all_modifiers_for(1):
			heal_amt += mod.heal_on_win
		
		if heal_amt > 0:
			p1_data.current_hp = mini(p1_data.current_hp + heal_amt, p1_data.max_hp)
			emit_signal("combat_log_updated", ">> Victory Sustain! Recovered " + str(heal_amt) + " HP.")
			print("Victory Heal: +%d HP" % heal_amt)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		broadcast_state_snapshot()

	emit_signal("game_over", game_winner)

func _check_reversal_state() -> void:
	var active_attacker: int = get_attacker()
	
	if state.attacker_override != 0:
		state.current_combo_attacker = state.attacker_override 
		if state.attacker_override == 1: state.p2_must_opener = true
		else: state.p1_must_opener = true
		return

	if active_attacker != 0:
		var att_data: CharacterData = p1_data if active_attacker == 1 else p2_data
		if att_data.current_sp <= 0:
			emit_signal("combat_log_updated", ">> Attacker Out of SP. Combo Ends.")
			state.current_combo_attacker = 0 
		else:
			state.current_combo_attacker = active_attacker
	else:
		state.current_combo_attacker = 0

func _handle_locks(winner_id: int, p1_active: bool = true, p2_active: bool = true) -> void:
	state.p1_locked_card = null; state.p2_locked_card = null
	var winner_active: bool = p1_active if winner_id == 1 else p2_active
	if not winner_active:
		return
	var winner_card: ActionData = state.p1_action_queue if winner_id == 1 else state.p2_action_queue
	var loser_card_obj: ActionData = state.p2_action_queue if winner_id == 1 else state.p1_action_queue 
	if winner_card.multi_limit > 0:
		emit_signal("combat_log_updated", "Multi Triggered! Loser Locked.")
		if winner_id == 1: state.p2_locked_card = loser_card_obj
		else: state.p1_locked_card = loser_card_obj

func _update_turn_constraints(p1_res: Dictionary, p2_res: Dictionary, p1_card: ActionData, p2_card: ActionData, p1_parry_win: bool, p2_parry_win: bool, p1_active: bool = true, p2_active: bool = true) -> void:
	var next_p1_limit: int = 99
	var next_p2_limit: int = 99
	var next_p1_opening: int = 0
	var next_p2_opening: int = 0
	state.p1_must_opener = false; state.p2_must_opener = false
	
	var p1_open: int = int(p1_res.get("opening", 0))
	var p2_open: int = int(p2_res.get("opening", 0))
	if p1_open > 0:
		next_p2_limit = mini(next_p2_limit, p1_open) 
		next_p1_opening = p1_open 
	if p2_open > 0:
		next_p1_limit = mini(next_p1_limit, p2_open)
		next_p2_opening = p2_open
	
	if p1_active and p1_card.multi_limit > 0: next_p1_limit = mini(next_p1_limit, p1_card.multi_limit)
	if p2_active and p2_card.multi_limit > 0: next_p2_limit = mini(next_p2_limit, p2_card.multi_limit)
		
	if p1_parry_win:
		state.p2_must_opener = true
		emit_signal("combat_log_updated", ">> P2 is unbalanced! Must use Opener next turn.")
	if p2_parry_win:
		state.p1_must_opener = true
		emit_signal("combat_log_updated", ">> P1 is unbalanced! Must use Opener next turn.")

	state.p1_cost_limit = next_p1_limit
	state.p2_cost_limit = next_p2_limit
	state.p1_opening_stat = next_p1_opening
	state.p2_opening_stat = next_p2_opening

	state.p1_opportunity_stat = int(p1_res.get("opportunity", 0))
	state.p2_opportunity_stat = int(p2_res.get("opportunity", 0))
	
	if state.p1_opportunity_stat > 0: emit_signal("combat_log_updated", "P1 gains Opportunity.")
	if state.p2_opportunity_stat > 0: emit_signal("combat_log_updated", "P2 gains Opportunity.")

func swap_priority() -> void:
	state.priority_player = 3 - state.priority_player

func get_player(id: int) -> CharacterData:
	return p1_data if id == 1 else p2_data

func get_opponent(id: int) -> CharacterData:
	return p2_data if id == 1 else p1_data

func is_p1_attacker() -> bool:
	if state.attacker_override == 1: return true
	if state.attacker_override == 2: return false
	if state.momentum == 0: return true
	return state.momentum <= MOMENTUM_P1_MAX

func clamp_momentum(val: int) -> int:
	return clampi(val, 1, TOTAL_MOMENTUM_SLOTS)

func get_advantage_momentum(player_id: int) -> int:
	if player_id == 1:
		return maxi(1, MOMENTUM_P1_MAX - 1)
	else:
		return mini(TOTAL_MOMENTUM_SLOTS, MOMENTUM_P2_START + 1)

func get_wall_momentum(player_id: int) -> int:
	if player_id == 1: return 1
	else: return TOTAL_MOMENTUM_SLOTS

func apply_environment_rules(env_type: String) -> void:
	current_environment_name = env_type
	match env_type:
		"Ring": TOTAL_MOMENTUM_SLOTS = 6
		"Dojo": TOTAL_MOMENTUM_SLOTS = 8
		"Street": TOTAL_MOMENTUM_SLOTS = 10
		_: TOTAL_MOMENTUM_SLOTS = 8 
			
	MOMENTUM_P1_MAX = int(TOTAL_MOMENTUM_SLOTS / 2.0)
	MOMENTUM_P2_START = MOMENTUM_P1_MAX + 1
	
	print(">>> ENVIRONMENT SET: " + env_type + " (Momentum: " + str(TOTAL_MOMENTUM_SLOTS) + ")")

func _handle_patient_passive(player_id: int, card: ActionData) -> void:
	var character: CharacterData = p1_data if player_id == 1 else p2_data
	if not character.has_bide_mechanic: return
	var consumed_buff: bool = false
	
	if character.patient_buff_active and card.damage > 0:
		card.damage += 1
		character.patient_buff_active = false 
		consumed_buff = true
		combat_callout.emit(player_id, "BIDE +1 DMG!", Color(1.0, 0.88, 0.3))
		emit_signal("combat_log_updated", ">> P" + str(player_id) + " BIDE Unleashed! (+1 Dmg)")
		
	var total_fb: int = card.fall_back_value
	if total_fb > 0 and not consumed_buff and not character.patient_buff_active:
		character.patient_buff_active = true
		combat_callout.emit(player_id, "BIDE ARMED", Color(0.55, 0.85, 1.0))
		emit_signal("combat_log_updated", ">> P" + str(player_id) + " Bides their time... (Next Attack Buffed)")

func get_struggle_action(force_type: ActionData.Type) -> ActionData:
	var action: ActionData = ActionData.new()
	action.display_name = "Struggle"
	action.is_struggle = true
	action.description = "Offence, Defence, Recover 1, Fall Back 2"
	action.type = force_type
	action.cost = 0
	action.recover_value = 1 
	action.fall_back_value = 2
	return action

func apply_status(target_id: int, status_name: String, value: int = 1) -> void:
	var target: CharacterData = p1_data if target_id == 1 else p2_data
	target.statuses[status_name] = value
	emit_signal("status_applied", target_id, status_name)
	emit_signal("combat_log_updated", ">> P" + str(target_id) + " gained status: " + status_name)

func has_status(target_id: int, status_name: String) -> bool:
	var target: CharacterData = p1_data if target_id == 1 else p2_data
	return target.statuses.has(status_name)

func remove_status(target_id: int, status_name: String) -> void:
	var target: CharacterData = p1_data if target_id == 1 else p2_data
	if target.statuses.has(status_name):
		target.statuses.erase(status_name)
		emit_signal("status_applied", target_id, "CURED")

func _load_backgrounds() -> void:
	var path: String = "res://Art/Background/"
	var dir: DirAccess = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name: String = file_name.replace(".import", "").replace(".remap", "")
				if clean_name.ends_with(".png") or clean_name.ends_with(".jpg"):
					var key: String = clean_name.get_basename()
					if not environment_backgrounds.has(key):
						environment_backgrounds[key] = load(path + clean_name)
						print(">> Loaded Environment Art: " + key)
			
			file_name = dir.get_next()
	else:
		print("ERROR: Could not find 'res://Art/Background/' folder.")

func _update_dynamic_music() -> void:
	if p1_data.max_hp <= 0: return
	
	var hp_percent: float = float(p1_data.current_hp) / float(p1_data.max_hp)
	
	if hp_percent <= 0.33:
		AudioManager.set_music_intensity(0.5, 1.5) 
		if GlobalCinematics.has_method("set_danger_vignette"):
			GlobalCinematics.set_danger_vignette(true)
	else:
		AudioManager.set_music_intensity(1.0, 2.0)
		if GlobalCinematics.has_method("set_danger_vignette"):
			GlobalCinematics.set_danger_vignette(false)


### ==============================================================================
### AUTHORITATIVE STATE SYNC (GDScript 2.0)
### ==============================================================================

func broadcast_state_snapshot() -> void:
	# Only the authoritative headless server (or the host, if P2P) is allowed to broadcast truth
	if not multiplayer.is_server():
		return
		
	var snapshot: Dictionary = {
		"match_state": state.to_dict(),
		"p1_hp": p1_data.current_hp,
		"p1_sp": p1_data.current_sp,
		"p2_hp": p2_data.current_hp,
		"p2_sp": p2_data.current_sp,
		"p1_statuses": p1_data.statuses.duplicate(true),
		"p2_statuses": p2_data.statuses.duplicate(true),
		"p1_combo": p1_data.combo_action_count,
		"p2_combo": p2_data.combo_action_count,
		"p1_bide": p1_data.patient_buff_active,
		"p2_bide": p2_data.patient_buff_active,
		"p1_used_super": p1_data.has_used_super,
		"p2_used_super": p2_data.has_used_super,
		"p1_locked_card_data": CombatRulesScript.serialize_action_snapshot(state.p1_locked_card),
		"p2_locked_card_data": CombatRulesScript.serialize_action_snapshot(state.p2_locked_card),
	}
	
	print("📡 [SERVER] Broadcasting Authoritative Snapshot to Clients...")
	receive_state_snapshot.rpc(snapshot)


@rpc("authority", "call_remote", "reliable")
func receive_state_snapshot(snapshot: Dictionary) -> void:
	print("📥 [CLIENT] Received Authoritative Snapshot. Enforcing server math.")
	
	# 1. Overwrite Core Health, SP, Status & Passive State
	p1_data.current_hp = int(snapshot.get("p1_hp", p1_data.current_hp))
	p1_data.current_sp = int(snapshot.get("p1_sp", p1_data.current_sp))
	p2_data.current_hp = int(snapshot.get("p2_hp", p2_data.current_hp))
	p2_data.current_sp = int(snapshot.get("p2_sp", p2_data.current_sp))
	if snapshot.has("p1_statuses"):
		p1_data.statuses = (snapshot["p1_statuses"] as Dictionary).duplicate(true)
	if snapshot.has("p2_statuses"):
		p2_data.statuses = (snapshot["p2_statuses"] as Dictionary).duplicate(true)
	p1_data.combo_action_count = int(snapshot.get("p1_combo", p1_data.combo_action_count))
	p2_data.combo_action_count = int(snapshot.get("p2_combo", p2_data.combo_action_count))
	p1_data.patient_buff_active = bool(snapshot.get("p1_bide", p1_data.patient_buff_active))
	p2_data.patient_buff_active = bool(snapshot.get("p2_bide", p2_data.patient_buff_active))
	p1_data.has_used_super = bool(snapshot.get("p1_used_super", p1_data.has_used_super))
	p2_data.has_used_super = bool(snapshot.get("p2_used_super", p2_data.has_used_super))
	
	# 2. Overwrite the MatchState Variables
	var ms_data: Dictionary = snapshot.get("match_state", {})
	state.from_dict(ms_data)
	
	# 3. Re-hydrate Locked Cards faithfully (supports Technical +, Feint combos, and Struggle)
	var p1_locked_dict: Dictionary = snapshot.get("p1_locked_card_data", {})
	var p2_locked_dict: Dictionary = snapshot.get("p2_locked_card_data", {})
	if not p1_locked_dict.is_empty():
		state.p1_locked_card = CombatRulesScript.deserialize_action_snapshot(p1_locked_dict)
	else:
		var p1_card_name: String = str(ms_data.get("p1_locked_card_name", ""))
		state.p1_locked_card = ClassFactory.find_action_resource(p1_card_name) if p1_card_name != "" else null
	if not p2_locked_dict.is_empty():
		state.p2_locked_card = CombatRulesScript.deserialize_action_snapshot(p2_locked_dict)
	else:
		var p2_card_name: String = str(ms_data.get("p2_locked_card_name", ""))
		state.p2_locked_card = ClassFactory.find_action_resource(p2_card_name) if p2_card_name != "" else null
	
	# 4. Refresh HUD visuals without re-triggering SELECTION/FEINT state transitions
	snapshot_applied.emit()
