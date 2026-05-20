extends Node

#region vars

# ==========================================
# --- 1. THE DISPOSABLE MATCH CONTAINER ---
# ==========================================
class MatchState:
	var momentum: int = 0
	var current_combo_attacker: int = 0
	var attacker_override: int = 0
	var priority_player: int = 1
	
	var p1_cost_limit: int = 99
	var p2_cost_limit: int = 99
	var p1_opening_stat: int = 0
	var p2_opening_stat: int = 0
	var p1_opportunity_stat: int = 0
	var p2_opportunity_stat: int = 0
	
	var p1_must_opener: bool = false
	var p2_must_opener: bool = false
	var p1_pending_feint: bool = false
	var p2_pending_feint: bool = false
	
	var p1_rage_active: bool = false
	var p2_rage_active: bool = false
	var p1_keep_up_active: bool = false
	var p2_keep_up_active: bool = false
	
	var p1_gym_block_bonus: int = 0
	
	var p1_locked_card: ActionData = null
	var p2_locked_card: ActionData = null
	
	var p1_action_queue: ActionData = null
	var p2_action_queue: ActionData = null

# ==========================================
# --- 2. ACTIVE STATE ---
# ==========================================
var state: MatchState = MatchState.new()

const KEYWORD_DEFS = {
	"Block": "Reduce incoming damage by X",
	"Cost": "lose X stamina",
	"Counter": "You must have used an action with Create Opening X or higher in the previous clash",
	"Create Opening": "Your opponent’s next action cannot have a Cost trait higher than X",
	"Damage": "Reduce your opponent’s health by X",
	"Defence": "Can only be used on the defensive. This action gains the Recover 1 trait.",
	"Feint": "In addition to the action’s listed traits, it gains all the traits of another action that you can use. That action can be chosen after actions are revealed",
	"Dodge": "You ignore the effects of your opponent’s action if its total stamina cost is X or below",
	"Fall Back": "Lose X momentum",
	"Guard Break": "Ignore the ‘Block X’ trait of your opponent’s action",
	"Heal": "Gain X HP",
	"Injure": "Your opponent must lose 1 HP every clash after this until you use an action with the Recover X, Heal X or Fall Back X traits, or the combat ends",
	"Momentum": "Gain X momentum",
	"Multi": "After this action, you may use any other action that has a Cost trait of X or below, and that does not have the multi X trait. This action interacts with your opponent’s previous action. If your opponent’s action would end your combo, you do not get to use this trait. In addition, moves with this trait can be used to start a combo",
	"Offence": "Can only be used on the offensive. If you are reduced to 0SP, your combo ends",
	"Opener": "Only actions with this trait can be used to start a combo",
	"Opportunity": "Increase your next actions momentum by X, and reduce its stamina cost by X",
	"Parry": "Your action steals the Momentum X trait of your opponent’s action. If this causes the momentum tracker to move in your direction, your opponent’s action has no affect on you, and your opponent’s next action must have the Opener trait",
	"Recover": "Gain X stamina",
	"Repeat": "After this action, use the same action again, ignoring the Repeat X trait. This must continue X times. This action interacts with your opponent’s chosen action as normal",
	"Retaliate": "Your opponent takes the same damage as they dealt to you in the previous clash",
	"Reversal": "If the momentum tracker moves closer to your side from this clash, the current combo ends and you take the offence, even if you do not have the momentum advantage. This applies even in the inital clash",
	"Super": "This action can only be used when the momentum tracker has reached the end of your side. You can only use an action with this trait once per combat",
	"Sweep": "This action affects all opponents you are in combat with",
	"Tiring": "Cause the opponent to lose X Stamina"
}

# --- SIGNALS ---
signal state_changed(new_state)
signal clash_resolved(winner_id, log_text)
signal combat_log_updated(text)
signal game_over(winner_id)
signal damage_dealt(target_id: int, amount: int, is_blocked: bool)
signal healing_received(target_id: int, amount: int)
signal status_applied(target_id: int, status_name: String)
signal request_clash_animation(p1_card, p2_card)
signal clash_animation_finished
signal wall_crush_occurred(player_id, damage_amount)
signal sync_advance_approved

# --- CONFIGURATION ---
var TOTAL_MOMENTUM_SLOTS: int = 8 
var current_environment_name: String = "Dojo"
var environment_backgrounds: Dictionary = {}
var MOMENTUM_P1_MAX: int = 4
var MOMENTUM_P2_START: int = 5

# --- STATE MACHINE ---
enum State { SETUP, SELECTION, REVEAL, FEINT_CHECK, RESOLUTION, POST_CLASH, GAME_OVER }
var current_state = State.SETUP
var temp_p1_class_selection: int = 0
var temp_p2_class_selection: int = 0 
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

var temp_p1_name: String = ""
var temp_p2_name: String = ""
var temp_p1_preset: Resource = null
var temp_p2_preset: Resource = null
var rival_intro_override: String = ""

# --- NETWORK VARS ---
var p1_network_id: int = 0
var p2_network_id: int = 0
var _is_sync_approved: bool = false
#endregion

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready():
	_load_backgrounds()
	
	MOMENTUM_P1_MAX = int(TOTAL_MOMENTUM_SLOTS / 2.0)
	MOMENTUM_P2_START = MOMENTUM_P1_MAX + 1
	
	print("--- GAME MANAGER READY ---")
	print("Momentum Config: Total=", TOTAL_MOMENTUM_SLOTS, " | P1_Max=", MOMENTUM_P1_MAX, " | P2_Start=", MOMENTUM_P2_START)

func start_combat(p1: CharacterData, p2: CharacterData):
	p1_data = p1
	p2_data = p2
	reset_combat()

func reset_combat():
	# --- 1. RESET STATS ---
	var p1_maintain = RunManager.is_arcade_mode and RunManager.maintain_hp_enabled
	p1_data.reset_stats(p1_maintain) 
	p2_data.reset_stats(false)
	
	# --- 2. INJECT EVENT STATUSES ---
	if RunManager.is_arcade_mode:
		for s in RunManager.next_fight_statuses:
			p1_data.statuses[s] = 1
		RunManager.next_fight_statuses.clear()
	
	# --- 3. THE MAGIC RESET ---
	state = MatchState.new()
	
	# --- 4. APPLY PLAYER EQUIPMENT & SPONSOR BONUSES ---
	var total_momentum_bonus = 0
	var p1_speed_bonus = 0
	
	var all_p1_modifiers: Array[BaseModifierData] = []
	if RunManager.player_run_data:
		all_p1_modifiers.append_array(RunManager.player_run_data.equipment)
	if RunManager.active_sponsor:
		all_p1_modifiers.append(RunManager.active_sponsor)
		
	for mod in all_p1_modifiers:
		p1_data.current_sp += mod.starting_sp_bonus
		if mod.starting_barrier > 0:
			p1_data.current_hp += mod.starting_barrier
			print("Modifier Barrier Applied: +%d HP" % mod.starting_barrier)
			
		total_momentum_bonus += mod.momentum_start_bonus
		p1_speed_bonus += mod.bonus_speed

	if RunManager.is_rival_match and RunManager.active_sponsor:
		total_momentum_bonus -= RunManager.active_sponsor.rival_momentum_handicap
		print("Rival Handicap Applied! Momentum shifted by " + str(RunManager.active_sponsor.rival_momentum_handicap))
		
	# --- 5. APPLY MOMENTUM STARTING POSITION ---
	if total_momentum_bonus > 0:
		state.momentum = MOMENTUM_P1_MAX - (total_momentum_bonus - 1)
		state.momentum = clampi(state.momentum, 1, MOMENTUM_P1_MAX)
		print(">> Head Start! Momentum set to: " + str(state.momentum))
		
	# --- 6. APPLY ENEMY EQUIPMENT BONUSES ---
	for item in p2_data.equipment:
		p2_data.current_sp += item.starting_sp_bonus
	
	# --- 7. APPLY GYM BUFFS ---
	if RunManager.active_gym_buff != "":
		print("Applying Gym Buff: " + RunManager.active_gym_buff)
		if RunManager.active_gym_buff == "iron_stance":
			state.p1_gym_block_bonus = 1
			print(">> Iron Stance: +1 Global Block")
		elif RunManager.active_gym_buff == "exploit_weakness":
			var damage = max(1, roundi(p2_data.max_hp * 0.2))
			p2_data.current_hp -= damage
			print(">> Exploit Weakness: Enemy took " + str(damage) + " dmg")
		RunManager.active_gym_buff = ""
	
	# --- 8. CALCULATE PRIORITY (SPEED TIES) ---
	var p1_final_speed = p1_data.speed + p1_speed_bonus
	var p2_final_speed = p2_data.speed
	
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

func change_state(new_state: State):
	var my_role = "Referee (Server)"
	if multiplayer.has_multiplayer_peer():
		var my_id = multiplayer.get_unique_id()
		if my_id == p1_network_id: my_role = "Player 1"
		elif my_id == p2_network_id: my_role = "Player 2"
		
	print("⏱️ [STATE SYNC] ", my_role, " entering state: ", State.keys()[new_state])
	
	current_state = new_state
	emit_signal("state_changed", current_state)
	
	match current_state:
		State.SELECTION:
			if state.p1_locked_card: player_select_action(1, state.p1_locked_card)
			if state.p2_locked_card: player_select_action(2, state.p2_locked_card)
		State.REVEAL:
			_enter_reveal_phase()
		State.FEINT_CHECK:
			pass 
		State.RESOLUTION:
			resolve_clash()

func player_select_action(player_id: int, action: ActionData, extra_data: Dictionary = {}):
	var final_action = action
	var tech_idx = extra_data.get("technique", 0)
	
	if action != null and tech_idx > 0:
		final_action = action.duplicate() 
		final_action.cost += 1 
		
		match tech_idx:
			1: 
				if final_action.type == ActionData.Type.OFFENCE:
					final_action.is_opener = true
					final_action.display_name += "+" 
			2: 
				final_action.tiring += 1
				final_action.display_name += "+"
			3: 
				final_action.momentum_gain += 1
				final_action.display_name += "+"
	
	if player_id == 1:
		state.p1_action_queue = final_action
		state.p1_rage_active = extra_data.get("rage", false)
		state.p1_keep_up_active = extra_data.get("keep_up", false)
	else:
		state.p2_action_queue = final_action
		state.p2_rage_active = extra_data.get("rage", false)
		state.p2_keep_up_active = extra_data.get("keep_up", false)
		
	if current_state == State.SELECTION:
		if state.p1_action_queue and state.p2_action_queue:
			change_state(State.REVEAL)
	elif current_state == State.FEINT_CHECK:
		_handle_feint_selection(player_id, final_action)

# ==============================================================================
# FEINT MECHANICS
# ==============================================================================

func _enter_reveal_phase():
	_is_sync_approved = false 
	
	emit_signal("combat_log_updated", "\nREVEAL: P1 chose " + state.p1_action_queue.display_name + " | P2 chose " + state.p2_action_queue.display_name)
	emit_signal("request_clash_animation", state.p1_action_queue, state.p2_action_queue)
	
	# --- 1. HEADLESS SERVER FIX (Skip Visual Await) ---
	if not (multiplayer.is_server() and DisplayServer.get_name() == "headless"):
		await self.clash_animation_finished
	
	# --- 2. NETWORK SYNC CHECK (FIXED) ---
	# We must ensure there are actually connected peers, otherwise Arcade mode freezes here!
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		if not multiplayer.is_server():
			NetworkManager.rpc_id(1, "report_animation_done")
			
		if not _is_sync_approved:
			await self.sync_advance_approved
	
	state.p1_pending_feint = state.p1_action_queue.feint
	state.p2_pending_feint = state.p2_action_queue.feint

	if state.p1_pending_feint or state.p2_pending_feint:
		change_state(State.FEINT_CHECK)
	else:
		change_state(State.RESOLUTION)
		
func _handle_feint_selection(player_id: int, secondary_action: ActionData):
	if secondary_action == null:
		emit_signal("combat_log_updated", "P" + str(player_id) + " skips Feint combination.")
		_clear_feint_flag(player_id)
		_check_feint_completion()
		return

	var base_card = state.p1_action_queue if player_id == 1 else state.p2_action_queue
	var character = p1_data if player_id == 1 else p2_data
	
	var total_cost = base_card.cost + secondary_action.cost
	var opp_val = _get_opportunity_value(player_id)
	var effective_total = max(0, total_cost - opp_val)
	
	var combined_card = _combine_actions(base_card, secondary_action)
	var total_reps = max(1, combined_card.repeat_count)
	var total_required = effective_total * total_reps
	
	var can_afford = false
	if character.current_sp >= total_required:
		can_afford = true
	elif character.class_type == CharacterData.ClassType.HEAVY and (character.current_sp + character.current_hp) > total_required:
		can_afford = true 
		
	if can_afford:
		emit_signal("combat_log_updated", "P" + str(player_id) + " Feint Successful! Combined into: " + combined_card.display_name)
		if player_id == 1: state.p1_action_queue = combined_card
		else: state.p2_action_queue = combined_card
	else:
		emit_signal("combat_log_updated", "P" + str(player_id) + " not enough SP for Feint. Action applies normally.")
	
	_clear_feint_flag(player_id)
	_check_feint_completion()

func _clear_feint_flag(player_id):
	if player_id == 1: state.p1_pending_feint = false
	else: state.p2_pending_feint = false

func _check_feint_completion():
	if not state.p1_pending_feint and not state.p2_pending_feint:
		change_state(State.RESOLUTION)

func _combine_actions(base: ActionData, sec: ActionData) -> ActionData:
	var new_card = base.duplicate()
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
	
	new_card.counter_value = max(new_card.counter_value, sec.counter_value) 
	new_card.repeat_count = max(new_card.repeat_count, sec.repeat_count)
	
	if sec.guard_break: new_card.guard_break = true
	if sec.retaliate: new_card.retaliate = true
	if sec.is_parry: new_card.is_parry = true
	if sec.is_super: new_card.is_super = true
	if sec.is_opener: new_card.is_opener = true
	
	new_card.statuses_to_apply.clear()
	for s in base.statuses_to_apply:
		new_card.statuses_to_apply.append(s.duplicate(true))
	for s in sec.statuses_to_apply:
		new_card.statuses_to_apply.append(s.duplicate(true))
	
	new_card.feint = false 
	return new_card

# ==============================================================================
# RESOLUTION LOGIC
# ==============================================================================

func resolve_clash():
	state.attacker_override = 0
	
	state.p1_action_queue = state.p1_action_queue.duplicate()
	state.p2_action_queue = state.p2_action_queue.duplicate()
	
	_handle_patient_passive(1, state.p1_action_queue)
	_handle_patient_passive(2, state.p2_action_queue)
	
	var winner_id = 0
	
	if state.p1_action_queue.type == ActionData.Type.OFFENCE and state.p2_action_queue.type == ActionData.Type.DEFENCE: winner_id = 1
	elif state.p2_action_queue.type == ActionData.Type.OFFENCE and state.p1_action_queue.type == ActionData.Type.DEFENCE: winner_id = 2
	elif state.p1_action_queue.cost < state.p2_action_queue.cost: winner_id = 1
	elif state.p2_action_queue.cost < state.p1_action_queue.cost: winner_id = 2
	else:
		emit_signal("combat_log_updated", "Tie! Priority Token Used.")
		winner_id = state.priority_player
		swap_priority()

	emit_signal("clash_resolved", winner_id, state.p1_action_queue, state.p2_action_queue, "Clash Winner: P" + str(winner_id))
	
	var is_initial_clash = (state.momentum == 0)
	
	if winner_id == 1 and state.p1_action_queue.type == ActionData.Type.OFFENCE:
		if state.current_combo_attacker != 1: p1_data.combo_action_count = 1
		else: p1_data.combo_action_count += 1
	else:
		p1_data.combo_action_count = 0

	if winner_id == 2 and state.p2_action_queue.type == ActionData.Type.OFFENCE:
		if state.current_combo_attacker != 2: p2_data.combo_action_count = 1
		else: p2_data.combo_action_count += 1
	else:
		p2_data.combo_action_count = 0
	
	var p1_started_injured = has_status(1, "Injured")
	var p2_started_injured = has_status(2, "Injured")
	
	var p1_active = _pay_cost(1, state.p1_action_queue)
	var p2_active = _pay_cost(2, state.p2_action_queue)

	if p1_active and state.p1_action_queue.is_super:
		p1_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P1 unleashes their Ultimate Art!")
	if p2_active and state.p2_action_queue.is_super:
		p2_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P2 unleashes their Ultimate Art!")

	if p1_active: _apply_phase_1_self_effects(1, state.p1_action_queue)
	if p2_active: _apply_phase_1_self_effects(2, state.p2_action_queue)

	var p1_is_dodged = false; var p2_is_dodged = false
	var p1_total_cost = state.p1_action_queue.cost * max(1, state.p1_action_queue.repeat_count)
	var p2_total_cost = state.p2_action_queue.cost * max(1, state.p2_action_queue.repeat_count)
	
	if p2_active and state.p2_action_queue.dodge_value > 0 and state.p2_action_queue.dodge_value >= p1_total_cost: p1_is_dodged = true
	if p1_active and state.p1_action_queue.dodge_value > 0 and state.p1_action_queue.dodge_value >= p2_total_cost: p2_is_dodged = true
	
	var p1_parries = (p1_active and state.p1_action_queue.is_parry)
	var p2_parries = (p2_active and state.p2_action_queue.is_parry)
	
	var p1_single_gain = state.p1_action_queue.momentum_gain + _get_opportunity_value(1)
	var p2_single_gain = state.p2_action_queue.momentum_gain + _get_opportunity_value(2)
	
	var p1_total_gain = _calculate_projected_momentum(1, state.p1_action_queue, p1_active)
	var p2_total_gain = _calculate_projected_momentum(2, state.p2_action_queue, p2_active)
	
	var p1_stolen = p2_single_gain if p1_parries else 0
	var p2_stolen = p1_single_gain if p2_parries else 0
	
	var p1_reps = max(1, state.p1_action_queue.repeat_count) if p1_active else 1
	var p2_reps = max(1, state.p2_action_queue.repeat_count) if p2_active else 1
	
	var p1_fb = (state.p1_action_queue.fall_back_value * p1_reps) if p1_active else 0
	var p2_fb = (state.p2_action_queue.fall_back_value * p2_reps) if p2_active else 0
	
	var p1_net_gain = p1_total_gain + p1_stolen - p1_fb
	var p2_net_gain = p2_total_gain + p2_stolen - p2_fb
	
	var p1_parry_success = (p1_parries and p1_net_gain > 0)
	var p2_parry_success = (p2_parries and p2_net_gain > 0)
	
	if p1_fb > 0 and state.momentum >= TOTAL_MOMENTUM_SLOTS:
		_apply_wall_crush(1, p1_fb)
		p1_fb = 0 
		
	if p2_fb > 0 and state.momentum <= 1:
		_apply_wall_crush(2, p2_fb)
		p2_fb = 0 

	var p1_contribution = p1_total_gain
	if p2_parries: p1_contribution -= p1_single_gain
	if p1_is_dodged: p1_contribution = 0
	
	var p2_contribution = p2_total_gain
	if p1_parries: p2_contribution -= p2_single_gain
	if p2_is_dodged: p2_contribution = 0
	
	var p1_final_push = p1_contribution + p1_stolen
	var p2_final_push = p2_contribution + p2_stolen
	
	var delta = (-p1_final_push + p1_fb) + (p2_final_push - p2_fb)
	
	var p1_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	var p2_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	var p2_immune_or_dodged = p2_parry_success or p1_is_dodged
	var p1_immune_or_dodged = p1_parry_success or p2_is_dodged
	
	if p1_active: p1_results = _apply_phase_2_combat_effects(1, 2, state.p1_action_queue, state.p2_action_queue, p2_immune_or_dodged)
	if p2_active: p2_results = _apply_phase_2_combat_effects(2, 1, state.p2_action_queue, state.p1_action_queue, p1_immune_or_dodged)
	
	_update_turn_constraints(p1_results, p2_results, state.p1_action_queue, state.p2_action_queue, p1_parry_success, p2_parry_success)
	
	if p1_results["fatal"] or p2_results["fatal"]:
		_handle_death(winner_id)
		return 
	
	var p1_reversed = (p1_active and state.p1_action_queue.reversal and delta < 0)
	var p2_reversed = (p2_active and state.p2_action_queue.reversal and delta > 0)

	if is_initial_clash:
		state.momentum = MOMENTUM_P1_MAX if winner_id == 1 else MOMENTUM_P2_START
		print("DEBUG: Initial Clash Winner: P", winner_id, " | Set Mom: ", state.momentum)
		
		if p1_reversed:
			state.attacker_override = 1
			emit_signal("combat_log_updated", ">> P1 Reverses! Seizing Offence.")
		elif p2_reversed:
			state.attacker_override = 2
			emit_signal("combat_log_updated", ">> P2 Reverses! Seizing Offence.")
	else:
		state.momentum = clamp_momentum(state.momentum + delta)
		
		if p1_reversed:
			state.attacker_override = 1
			emit_signal("combat_log_updated", ">> P1 REVERSAL SUCCESSFUL!")
		elif p2_reversed:
			state.attacker_override = 2
			emit_signal("combat_log_updated", ">> P2 REVERSAL SUCCESSFUL!")

	_handle_status_damage(winner_id, p1_started_injured, p2_started_injured)
	_check_reversal_state() 
	_handle_locks(winner_id)
	_update_dynamic_music()

	state.p1_action_queue = null
	state.p2_action_queue = null
	
	if p1_data.current_hp <= 0 or p2_data.current_hp <= 0:
		_handle_death(winner_id)
		return
	
	change_state(State.POST_CLASH)
	change_state(State.SELECTION)

# ==============================================================================
# PHASE IMPLEMENTATIONS
# ==============================================================================

func _apply_wall_crush(player_id: int, amount: int):
	var character = p1_data if player_id == 1 else p2_data
	var attacker_data = p2_data if player_id == 1 else p1_data
	var final_amount = amount
	
	for item in attacker_data.equipment:
		final_amount += item.wall_crush_damage_bonus
	
	emit_signal("wall_crush_occurred", player_id, final_amount)
	emit_signal("combat_log_updated", ">> P" + str(player_id) + " CRUSHED against the wall!")
	
	if character.current_sp >= final_amount:
		character.current_sp -= final_amount
		emit_signal("combat_log_updated", "   Lost " + str(final_amount) + " SP to hold ground.")
	else:
		var sp_paid = character.current_sp
		var hp_damage = final_amount - sp_paid
		
		character.current_sp = 0
		character.current_hp -= hp_damage
		
		emit_signal("combat_log_updated", "   Lost " + str(sp_paid) + " SP and took " + str(hp_damage) + " HP DAMAGE!")
		emit_signal("damage_dealt", player_id, hp_damage, false)

func _apply_phase_1_self_effects(owner_id: int, my_card: ActionData):
	var character = p1_data if owner_id == 1 else p2_data
	var total_hits = max(1, my_card.repeat_count)
	
	if character.combo_sp_recovery_rate > 0:
		if character.combo_action_count > 0 and (character.combo_action_count % character.combo_sp_recovery_rate == 0):
			character.current_sp = min(character.current_sp + 1, character.max_sp)
			emit_signal("combat_log_updated", ">> Relentless! P" + str(owner_id) + " recovers 1 SP.")
	
	for i in range(total_hits):
		var actual_recover = my_card.recover_value
		if my_card.type == ActionData.Type.DEFENCE: actual_recover += 1
		
		if actual_recover > 0: 
			character.current_sp = min(character.current_sp + actual_recover, character.max_sp)
			
		if my_card.heal_value > 0: 
			character.current_hp = min(character.current_hp + my_card.heal_value, character.max_hp)
			emit_signal("healing_received", owner_id, my_card.heal_value)

		if my_card.heal_value > 0 or my_card.fall_back_value > 0:
			if has_status(owner_id, "Injured"):
				remove_status(owner_id, "Injured")
				emit_signal("combat_log_updated", ">> P" + str(owner_id) + " cures Injury!")

func _apply_phase_2_combat_effects(owner_id: int, target_id: int, my_card: ActionData, enemy_card: ActionData, target_is_immune: bool) -> Dictionary:
	var character = p1_data if owner_id == 1 else p2_data
	var target = p2_data if owner_id == 1 else p1_data
	var result = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	if target_is_immune:
		emit_signal("combat_log_updated", "P" + str(owner_id) + " attack NULLIFIED (Dodge/Parry)!")
		emit_signal("status_applied", owner_id, "MISS")
		emit_signal("status_applied", target_id, "DODGED")
		return result

	var dmg_mod = 0
	var attacker_block_mod = 0 
	var defender_block_mod = 0
	var thorns_dmg = 0
	
	var attacker_mods: Array[BaseModifierData] = []
	attacker_mods.append_array(character.equipment) 
	if owner_id == 1 and RunManager.active_sponsor:
		attacker_mods.append(RunManager.active_sponsor)
		
	for mod in attacker_mods:
		dmg_mod += mod.damage_modifier
		attacker_block_mod += mod.block_modifier
		
	var defender_mods: Array[BaseModifierData] = []
	defender_mods.append_array(target.equipment)
	if target_id == 1 and RunManager.active_sponsor:
		defender_mods.append(RunManager.active_sponsor)
		
	for mod in defender_mods:
		defender_block_mod += mod.block_modifier
		thorns_dmg += mod.thorns
		
	if owner_id == 1:
		attacker_block_mod += state.p1_gym_block_bonus
	elif target_id == 1:
		defender_block_mod += state.p1_gym_block_bonus
		
	var total_hits = max(1, my_card.repeat_count)
	for i in range(total_hits):
		var total_damage = max(0, my_card.damage + dmg_mod)
		var enemy_block = enemy_card.block_value + defender_block_mod
		
		if my_card.guard_break: 
			enemy_block = 0
			
		var net_damage = max(0, total_damage - enemy_block)
		
		if my_card.tiring > 0:
			if target.tiring_drains_hp and target.current_sp < my_card.tiring:
				var drain_amount = my_card.tiring
				var sp_avail = target.current_sp
				var hp_cost = drain_amount - sp_avail
				target.current_sp = 0
				target.current_hp -= hp_cost
				emit_signal("combat_log_updated", ">> Rage! P" + str(target_id) + " takes " + str(hp_cost) + " HP dmg instead of SP.")
				emit_signal("damage_dealt", target_id, hp_cost, false)
			else:
				target.current_sp = max(0, target.current_sp - my_card.tiring)
				emit_signal("combat_log_updated", ">> Tiring! P" + str(target_id) + " drained of " + str(my_card.tiring) + " SP.")
		
		for effect in my_card.statuses_to_apply:
			var s_name = effect.get("name", "Unknown")
			var s_val = effect.get("amount", 1)
			var is_self = effect.get("self", false)
			var dest_id = owner_id if is_self else target_id
			
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

		if total_damage > 0 and enemy_card.retaliate:
			var raw_recoil = total_damage
			var self_block = my_card.block_value + my_card.dodge_value + attacker_block_mod 
			var net_recoil = max(0, raw_recoil - self_block)
			
			if net_recoil > 0:
				character.current_hp -= net_recoil
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

func _calculate_projected_momentum(player_id: int, card: ActionData, is_active: bool) -> int:
	if not is_active: return 0
	var opp_val = _get_opportunity_value(player_id)
	var single_gain = card.momentum_gain + opp_val
	var total_gain = single_gain * max(1, card.repeat_count)
	return total_gain

func _get_opportunity_value(player_id: int) -> int:
	return state.p1_opportunity_stat if player_id == 1 else state.p2_opportunity_stat

func _pay_cost(player_id: int, card: ActionData) -> bool:
	var character = p1_data if player_id == 1 else p2_data
	var is_free = (state.p1_locked_card != null if player_id == 1 else state.p2_locked_card != null)
	var rage_is_on = (state.p1_rage_active if player_id == 1 else state.p2_rage_active)
	
	var raw_cost = card.cost
	var opp_val = _get_opportunity_value(player_id)
	var effective_single_cost = max(0, raw_cost - opp_val)
	var total_reps = max(1, card.repeat_count)
	var total_cost = effective_single_cost * total_reps
	
	if is_free: total_cost = 0
	
	if rage_is_on and character.can_pay_with_hp:
		if character.current_hp > total_cost:
			character.current_hp -= total_cost
			emit_signal("combat_log_updated", ">> RAGE! P" + str(player_id) + " pays " + str(total_cost) + " HP.")
			emit_signal("damage_dealt", player_id, total_cost, false)
			return true
		else:
			emit_signal("combat_log_updated", ">> RAGE failed! Not enough HP.")
			return false
	
	if character.current_sp >= total_cost:
		character.current_sp -= total_cost
		return true
	else:
		if character.can_pay_with_hp:
			if (character.current_sp + character.current_hp) > total_cost:
				var sp_avail = character.current_sp
				var hp_cost = total_cost - sp_avail
				character.current_sp = 0
				character.current_hp -= hp_cost
				emit_signal("combat_log_updated", ">> Rage! P" + str(player_id) + " pays " + str(hp_cost) + " HP for action.")
				emit_signal("damage_dealt", player_id, hp_cost, false)
				return true
		
		emit_signal("combat_log_updated", ">> P" + str(player_id) + " Out of SP! Action Fails!")
		return false

func _handle_status_damage(winner_id, p1_started_injured, p2_started_injured):
	for id in [1, 2]:
		var player = p1_data if id == 1 else p2_data
		var started_injured = p1_started_injured if id == 1 else p2_started_injured
		
		for s_name in player.statuses.keys():
			match s_name:
				"Injured":
					if started_injured:
						player.current_hp -= 1
						emit_signal("combat_log_updated", ">> P" + str(id) + " suffers Injury damage!")
						emit_signal("damage_dealt", id, 1, false)
				"Poison":
					var stacks = player.statuses["Poison"]
					player.current_hp -= stacks
					emit_signal("combat_log_updated", ">> P" + str(id) + " takes Poison dmg!")
					
		if player.current_hp <= 0:
			_handle_death(winner_id)
			return

func _handle_death(winner_id):
	var game_winner = 0
	if p1_data.current_hp > 0: game_winner = 1
	elif p2_data.current_hp > 0: game_winner = 2
	else: game_winner = winner_id 
	
	if game_winner == 1 and RunManager.player_run_data:
		var heal_amt = 0
		for eq in RunManager.player_run_data.equipment:
			heal_amt += eq.heal_on_win
		
		if heal_amt > 0:
			p1_data.current_hp = min(p1_data.current_hp + heal_amt, p1_data.max_hp)
			emit_signal("combat_log_updated", ">> Victory Sustain! Recovered " + str(heal_amt) + " HP.")
			print("Victory Heal: +%d HP" % heal_amt)
			
	emit_signal("game_over", game_winner)

func _check_reversal_state():
	var active_attacker = get_attacker()
	
	if state.attacker_override != 0:
		state.current_combo_attacker = state.attacker_override 
		if state.attacker_override == 1: state.p2_must_opener = true
		else: state.p1_must_opener = true
		return

	if active_attacker != 0:
		var att_data = p1_data if active_attacker == 1 else p2_data
		if att_data.current_sp <= 0:
			emit_signal("combat_log_updated", ">> Attacker Out of SP. Combo Ends.")
			state.current_combo_attacker = 0 
		else:
			state.current_combo_attacker = active_attacker
	else:
		state.current_combo_attacker = 0

func _handle_locks(winner_id):
	state.p1_locked_card = null; state.p2_locked_card = null
	var winner_card = state.p1_action_queue if winner_id == 1 else state.p2_action_queue
	var loser_card_obj = state.p2_action_queue if winner_id == 1 else state.p1_action_queue 
	if winner_card.multi_limit > 0:
		emit_signal("combat_log_updated", "Multi Triggered! Loser Locked.")
		if winner_id == 1: state.p2_locked_card = loser_card_obj
		else: state.p1_locked_card = loser_card_obj

func _update_turn_constraints(p1_res, p2_res, p1_card, p2_card, p1_parry_win: bool, p2_parry_win: bool):
	var next_p1_limit = 99; var next_p2_limit = 99
	var next_p1_opening = 0; var next_p2_opening = 0
	state.p1_must_opener = false; state.p2_must_opener = false
	
	if p1_res["opening"] > 0:
		next_p2_limit = min(next_p2_limit, p1_res["opening"]) 
		next_p1_opening = p1_res["opening"] 
	if p2_res["opening"] > 0:
		next_p1_limit = min(next_p1_limit, p2_res["opening"])
		next_p2_opening = p2_res["opening"]
	
	if p1_card.multi_limit > 0: next_p1_limit = min(next_p1_limit, p1_card.multi_limit)
	if p2_card.multi_limit > 0: next_p2_limit = min(next_p2_limit, p2_card.multi_limit)
		
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

	state.p1_opportunity_stat = p1_res["opportunity"]
	state.p2_opportunity_stat = p2_res["opportunity"]
	
	if state.p1_opportunity_stat > 0: emit_signal("combat_log_updated", "P1 gains Opportunity.")
	if state.p2_opportunity_stat > 0: emit_signal("combat_log_updated", "P2 gains Opportunity.")

func swap_priority():
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
		return max(1, MOMENTUM_P1_MAX - 1)
	else:
		return min(TOTAL_MOMENTUM_SLOTS, MOMENTUM_P2_START + 1)

func get_wall_momentum(player_id: int) -> int:
	if player_id == 1: return 1
	else: return TOTAL_MOMENTUM_SLOTS

func apply_environment_rules(env_type: String):
	current_environment_name = env_type
	match env_type:
		"Ring": TOTAL_MOMENTUM_SLOTS = 6
		"Dojo": TOTAL_MOMENTUM_SLOTS = 8
		"Street": TOTAL_MOMENTUM_SLOTS = 10
		_: TOTAL_MOMENTUM_SLOTS = 8 
			
	MOMENTUM_P1_MAX = int(TOTAL_MOMENTUM_SLOTS / 2.0)
	MOMENTUM_P2_START = MOMENTUM_P1_MAX + 1
	
	print(">>> ENVIRONMENT SET: " + env_type + " (Momentum: " + str(TOTAL_MOMENTUM_SLOTS) + ")")

func _handle_patient_passive(player_id: int, card: ActionData):
	var character = p1_data if player_id == 1 else p2_data
	if not character.has_bide_mechanic: return
	var consumed_buff = false
	
	if character.patient_buff_active:
		card.damage += 1
		character.patient_buff_active = false 
		consumed_buff = true
		emit_signal("combat_log_updated", ">> P" + str(player_id) + " BIDE Unleashed! (+1 Dmg)")
		
	var total_fb = card.fall_back_value
	if total_fb > 0 and not consumed_buff:
		character.patient_buff_active = true
		emit_signal("combat_log_updated", ">> P" + str(player_id) + " Bides their time... (Next Action Buffed)")

func get_struggle_action(force_type: ActionData.Type) -> ActionData:
	var action = ActionData.new()
	action.display_name = "Struggle"
	action.is_struggle = true
	action.description = "Offence, Defence, Recover 1, Fall Back 2"
	action.type = force_type
	action.cost = 0
	action.recover_value = 1 
	action.fall_back_value = 2
	return action

func apply_status(target_id: int, status_name: String, value: int = 1):
	var target = p1_data if target_id == 1 else p2_data
	target.statuses[status_name] = value
	emit_signal("status_applied", target_id, status_name)
	emit_signal("combat_log_updated", ">> P" + str(target_id) + " gained status: " + status_name)

func has_status(target_id: int, status_name: String) -> bool:
	var target = p1_data if target_id == 1 else p2_data
	return target.statuses.has(status_name)

func remove_status(target_id: int, status_name: String):
	var target = p1_data if target_id == 1 else p2_data
	if target.statuses.has(status_name):
		target.statuses.erase(status_name)
		emit_signal("status_applied", target_id, "CURED")

func _load_backgrounds():
	var path = "res://Art/Background/"
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.replace(".import", "").replace(".remap", "")
				if clean_name.ends_with(".png") or clean_name.ends_with(".jpg"):
					var key = clean_name.get_basename()
					if not environment_backgrounds.has(key):
						environment_backgrounds[key] = load(path + clean_name)
						print(">> Loaded Environment Art: " + key)
			
			file_name = dir.get_next()
	else:
		print("ERROR: Could not find 'res://Art/Background/' folder.")

func _update_dynamic_music():
	if p1_data.max_hp <= 0: return
	
	var hp_percent = float(p1_data.current_hp) / float(p1_data.max_hp)
	
	if hp_percent <= 0.33:
		AudioManager.set_music_intensity(0.5, 1.5) 
		if GlobalCinematics.has_method("set_danger_vignette"):
			GlobalCinematics.set_danger_vignette(true)
	else:
		AudioManager.set_music_intensity(1.0, 2.0)
		if GlobalCinematics.has_method("set_danger_vignette"):
			GlobalCinematics.set_danger_vignette(false)
