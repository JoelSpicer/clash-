extends Node

#region vars
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


# --- CONFIGURATION ---
var TOTAL_MOMENTUM_SLOTS: int = 8 
var current_environment_name: String = "Dojo"

# --- DYNAMIC CALCULATIONS ---
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
var attacker_override: int = 0 

# --- PERSISTENT GAME SETUP ---
var next_match_p1_data: CharacterData
var next_match_p2_data: CharacterData

# --- CORE DATA ---
var p1_data: CharacterData
var p2_data: CharacterData
var priority_player: int = 1 
var momentum: int = 0 
var current_combo_attacker: int = 0

# --- TURN CONSTRAINTS ---
var p1_cost_limit: int = 99; var p2_cost_limit: int = 99
var p1_opening_stat: int = 0; var p2_opening_stat: int = 0
var p1_opportunity_stat: int = 0; var p2_opportunity_stat: int = 0
var p1_must_opener: bool = false; var p2_must_opener: bool = false

## --- STATUS EFFECTS ---
#var p1_is_injured: bool = false
#var p2_is_injured: bool = false

# --- TURN STATE ---
var p1_action_queue: ActionData
var p2_action_queue: ActionData
var p1_locked_card: ActionData = null
var p2_locked_card: ActionData = null

# --- FEINT HELPERS ---
var p1_pending_feint: bool = false
var p2_pending_feint: bool = false

# --- PASSIVES ---
var p1_rage_active: bool = false
var p2_rage_active: bool = false
var p1_keep_up_active: bool = false
var p2_keep_up_active: bool = false

var temp_p1_name: String = ""
var temp_p2_name: String = ""
var temp_p1_preset: Resource = null
var temp_p2_preset: Resource = null
#endregion

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready():
	MOMENTUM_P1_MAX = int(TOTAL_MOMENTUM_SLOTS / 2.0)
	MOMENTUM_P2_START = MOMENTUM_P1_MAX + 1
	
	print("--- GAME MANAGER READY ---")
	print("Momentum Config: Total=", TOTAL_MOMENTUM_SLOTS, " | P1_Max=", MOMENTUM_P1_MAX, " | P2_Start=", MOMENTUM_P2_START)
	
	priority_player = 1
	momentum = 0

func start_combat(p1: CharacterData, p2: CharacterData):
	p1_data = p1
	p2_data = p2
	reset_combat()

func reset_combat():
	# --- FIX: Check if P1 should maintain HP ---
	var p1_maintain = RunManager.is_arcade_mode and RunManager.maintain_hp_enabled
	p1_data.reset_stats(p1_maintain) 
	
	# P2 (The Enemy) always resets to full
	p2_data.reset_stats(false)
	# -------------------------------------------
	momentum = 0 
	current_combo_attacker = 0
	p1_locked_card = null; p2_locked_card = null
	
	p1_cost_limit = 99; p2_cost_limit = 99
	p1_opening_stat = 0; p2_opening_stat = 0
	p1_opportunity_stat = 0; p2_opportunity_stat = 0
	p1_must_opener = false; p2_must_opener = false
	# REMOVED: p1_is_injured = false
	# REMOVED: p2_is_injured = false
	p1_pending_feint = false; p2_pending_feint = false
	
	p1_rage_active = false; p2_rage_active = false
	p1_keep_up_active = false; p2_keep_up_active = false
	
	if p1_data.speed > p2_data.speed: priority_player = 1
	elif p2_data.speed > p1_data.speed: priority_player = 2
	else: priority_player = randi_range(1, 2)
		
	print("\n>>> COMBAT RESET! Starting from Initial Clash (Neutral) <<<")
	change_state(State.SELECTION)

func get_attacker() -> int:
	if current_combo_attacker != 0: return current_combo_attacker
	if attacker_override != 0: return attacker_override
	if momentum == 0: return 0 
	return 1 if momentum <= MOMENTUM_P1_MAX else 2

# ==============================================================================
# STATE MACHINE
# ==============================================================================

func change_state(new_state: State):
	current_state = new_state
	emit_signal("state_changed", current_state)
	
	match current_state:
		State.SELECTION:
			if p1_locked_card: player_select_action(1, p1_locked_card)
			if p2_locked_card: player_select_action(2, p2_locked_card)
		State.REVEAL:
			_enter_reveal_phase()
		State.FEINT_CHECK:
			pass 
		State.RESOLUTION:
			resolve_clash()

func player_select_action(player_id: int, action: ActionData, extra_data: Dictionary = {}):
	# 1. Process the Action based on Technique
	var final_action = action
	var tech_idx = extra_data.get("technique", 0)
	
	# Only modify if a technique was actually selected AND action is not null (Skip)
	if action != null and tech_idx > 0:
		final_action = action.duplicate() 
		final_action.cost += 1 
		
		match tech_idx:
			1: # Opener
				if final_action.type == ActionData.Type.OFFENCE:
					final_action.is_opener = true
					final_action.display_name += "+" 
			2: # Tiring
				final_action.tiring += 1
				final_action.display_name += "+"
			3: # Momentum
				final_action.momentum_gain += 1
				final_action.display_name += "+"
	
	# 2. Standard Logic
	if player_id == 1:
		p1_action_queue = final_action
		p1_rage_active = extra_data.get("rage", false)
		p1_keep_up_active = extra_data.get("keep_up", false)
	else:
		p2_action_queue = final_action
		p2_rage_active = extra_data.get("rage", false)
		p2_keep_up_active = extra_data.get("keep_up", false)
		
	if current_state == State.SELECTION:
		if p1_action_queue and p2_action_queue:
			change_state(State.REVEAL)
	elif current_state == State.FEINT_CHECK:
		_handle_feint_selection(player_id, final_action)

# ==============================================================================
# FEINT MECHANICS
# ==============================================================================

func _enter_reveal_phase():
	emit_signal("combat_log_updated", "\nREVEAL: P1 chose " + p1_action_queue.display_name + " | P2 chose " + p2_action_queue.display_name)
	emit_signal("request_clash_animation", p1_action_queue, p2_action_queue)
	await self.clash_animation_finished
	
	p1_pending_feint = p1_action_queue.feint
	p2_pending_feint = p2_action_queue.feint

	if p1_pending_feint or p2_pending_feint:
		change_state(State.FEINT_CHECK)
	else:
		change_state(State.RESOLUTION)

func _handle_feint_selection(player_id: int, secondary_action: ActionData):
	if secondary_action == null:
		emit_signal("combat_log_updated", "P" + str(player_id) + " skips Feint combination.")
		_clear_feint_flag(player_id)
		_check_feint_completion()
		return

	var base_card = p1_action_queue if player_id == 1 else p2_action_queue
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
		if player_id == 1: p1_action_queue = combined_card
		else: p2_action_queue = combined_card
	else:
		emit_signal("combat_log_updated", "P" + str(player_id) + " not enough SP for Feint. Action applies normally.")
	
	_clear_feint_flag(player_id)
	_check_feint_completion()

func _clear_feint_flag(player_id):
	if player_id == 1: p1_pending_feint = false
	else: p2_pending_feint = false

func _check_feint_completion():
	if not p1_pending_feint and not p2_pending_feint:
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
	if sec.injure: new_card.injure = true
	if sec.retaliate: new_card.retaliate = true
	if sec.is_parry: new_card.is_parry = true
	if sec.is_super: new_card.is_super = true
	if sec.is_opener: new_card.is_opener = true
	
	new_card.feint = false 
	return new_card

# ==============================================================================
# RESOLUTION LOGIC
# ==============================================================================

func resolve_clash():
	attacker_override = 0
	
	# Duplicate to ensure we don't modify the original resource
	p1_action_queue = p1_action_queue.duplicate()
	p2_action_queue = p2_action_queue.duplicate()
	
	_handle_patient_passive(1, p1_action_queue)
	_handle_patient_passive(2, p2_action_queue)
	
	var winner_id = 0
	
	if p1_action_queue.type == ActionData.Type.OFFENCE and p2_action_queue.type == ActionData.Type.DEFENCE: winner_id = 1
	elif p2_action_queue.type == ActionData.Type.OFFENCE and p1_action_queue.type == ActionData.Type.DEFENCE: winner_id = 2
	elif p1_action_queue.cost < p2_action_queue.cost: winner_id = 1
	elif p2_action_queue.cost < p1_action_queue.cost: winner_id = 2
	else:
		emit_signal("combat_log_updated", "Tie! Priority Token Used.")
		winner_id = priority_player
		swap_priority()

	emit_signal("clash_resolved", winner_id, p1_action_queue, p2_action_queue, "Clash Winner: P" + str(winner_id))
	
	var is_initial_clash = (momentum == 0)
	
# If P1 wins with Offence...
	if winner_id == 1 and p1_action_queue.type == ActionData.Type.OFFENCE:
		# Check if they were ALREADY comboing. If not (e.g., previous turn was neutral or 0 SP break), start at 1.
		if current_combo_attacker != 1: p1_data.combo_action_count = 1
		else: p1_data.combo_action_count += 1
	else:
		p1_data.combo_action_count = 0

	# Same for P2
	if winner_id == 2 and p2_action_queue.type == ActionData.Type.OFFENCE:
		if current_combo_attacker != 2: p2_data.combo_action_count = 1
		else: p2_data.combo_action_count += 1
	else:
		p2_data.combo_action_count = 0
	
	# --- PHASE 0: PAY COSTS ---
	# FIX: Use helper instead of deleted variable
	var p1_started_injured = has_status(1, "Injured")
	var p2_started_injured = has_status(2, "Injured")
	
	var p1_active = _pay_cost(1, p1_action_queue)
	var p2_active = _pay_cost(2, p2_action_queue)

	if p1_active and p1_action_queue.is_super:
		p1_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P1 unleashes their Ultimate Art!")
	if p2_active and p2_action_queue.is_super:
		p2_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P2 unleashes their Ultimate Art!")

	# --- PHASE 1: SELF EFFECTS ---
	if p1_active: _apply_phase_1_self_effects(1, p1_action_queue)
	if p2_active: _apply_phase_1_self_effects(2, p2_action_queue)

	# --- MOMENTUM CALCULATION ---
	
	# A. Dodge & Parry Checks
	var p1_is_dodged = false; var p2_is_dodged = false
	var p1_total_cost = p1_action_queue.cost * max(1, p1_action_queue.repeat_count)
	var p2_total_cost = p2_action_queue.cost * max(1, p2_action_queue.repeat_count)
	
	if p2_active and p2_action_queue.dodge_value > 0 and p2_action_queue.dodge_value >= p1_total_cost: p1_is_dodged = true
	if p1_active and p1_action_queue.dodge_value > 0 and p1_action_queue.dodge_value >= p2_total_cost: p2_is_dodged = true
	
	var p1_parries = (p1_active and p1_action_queue.is_parry)
	var p2_parries = (p2_active and p2_action_queue.is_parry)
	
	# B. Push/Pull Calculation
	var p1_single_gain = p1_action_queue.momentum_gain + _get_opportunity_value(1)
	var p2_single_gain = p2_action_queue.momentum_gain + _get_opportunity_value(2)
	
	var p1_total_gain = _calculate_projected_momentum(1, p1_action_queue, p1_active)
	var p2_total_gain = _calculate_projected_momentum(2, p2_action_queue, p2_active)
	
	var p1_contribution = p1_total_gain
	if p2_parries: p1_contribution -= p1_single_gain
	if p1_is_dodged: p1_contribution = 0
	
	var p2_contribution = p2_total_gain
	if p1_parries: p2_contribution -= p2_single_gain
	if p2_is_dodged: p2_contribution = 0
	
	var p1_stolen = p2_single_gain if p1_parries else 0
	var p2_stolen = p1_single_gain if p2_parries else 0
	
	var p1_final_push = p1_contribution + p1_stolen
	var p2_final_push = p2_contribution + p2_stolen
	
	# C. Delta Calculation (With Wall Crush Fix)
	var p1_reps = max(1, p1_action_queue.repeat_count) if p1_active else 1
	var p2_reps = max(1, p2_action_queue.repeat_count) if p2_active else 1
	
	var p1_fb = (p1_action_queue.fall_back_value * p1_reps) if p1_active else 0
	var p2_fb = (p2_action_queue.fall_back_value * p2_reps) if p2_active else 0
	
	# --- WALL CRUSH CHECK ---
	if p1_fb > 0 and momentum >= TOTAL_MOMENTUM_SLOTS:
		_apply_wall_crush(1, p1_fb)
		p1_fb = 0 
		
	if p2_fb > 0 and momentum <= 1:
		_apply_wall_crush(2, p2_fb)
		p2_fb = 0 
	# ------------------------------
	
	var delta = (-p1_final_push + p1_fb) + (p2_final_push - p2_fb)
	
	var p1_parry_success = (p1_parries and delta < 0)
	var p2_parry_success = (p2_parries and delta > 0)
	
	# --- PHASE 2: COMBAT EFFECTS ---
	var p1_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	var p2_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	var p2_immune_or_dodged = p2_parry_success or p1_is_dodged
	var p1_immune_or_dodged = p1_parry_success or p2_is_dodged
	
	if p1_active: p1_results = _apply_phase_2_combat_effects(1, 2, p1_action_queue, p2_action_queue, p2_immune_or_dodged)
	if p2_active: p2_results = _apply_phase_2_combat_effects(2, 1, p2_action_queue, p1_action_queue, p1_immune_or_dodged)
	
	_update_turn_constraints(p1_results, p2_results, p1_action_queue, p2_action_queue, p1_parry_success, p2_parry_success)
	
	if p1_results["fatal"] or p2_results["fatal"]:
		_handle_death(winner_id)
		return 
	
	# --- PHASE 3: APPLY MOMENTUM & REVERSAL ---
	var p1_reversed = (p1_active and p1_action_queue.reversal and delta < 0)
	var p2_reversed = (p2_active and p2_action_queue.reversal and delta > 0)

	if is_initial_clash:
		momentum = MOMENTUM_P1_MAX if winner_id == 1 else MOMENTUM_P2_START
		print("DEBUG: Initial Clash Winner: P", winner_id, " | Set Mom: ", momentum)
		
		if p1_reversed:
			attacker_override = 1
			emit_signal("combat_log_updated", ">> P1 Reverses! Seizing Offence.")
		elif p2_reversed:
			attacker_override = 2
			emit_signal("combat_log_updated", ">> P2 Reverses! Seizing Offence.")
			
	else:
		momentum = clamp_momentum(momentum + delta)
		
		if p1_reversed:
			attacker_override = 1
			emit_signal("combat_log_updated", ">> P1 REVERSAL SUCCESSFUL!")
		elif p2_reversed:
			attacker_override = 2
			emit_signal("combat_log_updated", ">> P2 REVERSAL SUCCESSFUL!")

	# --- CLEANUP ---
	_handle_status_damage(winner_id, p1_started_injured, p2_started_injured)
	_check_reversal_state() 
	_handle_locks(winner_id)

	p1_action_queue = null
	p2_action_queue = null
	
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
	
	# --- NEW: EMIT SIGNAL ---
	emit_signal("wall_crush_occurred", player_id, amount)
	# ------------------------
	
	emit_signal("combat_log_updated", ">> P" + str(player_id) + " CRUSHED against the wall!")
	
	if character.current_sp >= amount:
		character.current_sp -= amount
		emit_signal("combat_log_updated", "   Lost " + str(amount) + " SP to hold ground.")
	else:
		var sp_paid = character.current_sp
		var hp_damage = amount - sp_paid
		
		character.current_sp = 0
		character.current_hp -= hp_damage
		
		emit_signal("combat_log_updated", "   Lost " + str(sp_paid) + " SP and took " + str(hp_damage) + " HP DAMAGE!")
		emit_signal("damage_dealt", player_id, hp_damage, false)

func _apply_phase_1_self_effects(owner_id: int, my_card: ActionData):
	var character = p1_data if owner_id == 1 else p2_data
	var total_hits = max(1, my_card.repeat_count)
	
	if character.class_type == CharacterData.ClassType.QUICK:
		if character.combo_action_count > 0 and (character.combo_action_count % 3 == 0):
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

	var total_hits = max(1, my_card.repeat_count)
	for i in range(total_hits):
		var enemy_block = enemy_card.block_value 
		if my_card.guard_break: enemy_block = 0
		var net_damage = max(0, my_card.damage - enemy_block)
		
		if my_card.tiring > 0:
			if target.class_type == CharacterData.ClassType.HEAVY and target.current_sp < my_card.tiring:
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
		
		# --- NEW: GENERIC STATUS APPLICATION ---
		for effect in my_card.statuses_to_apply:
			# Default keys: "name" (String), "amount" (int), "self" (bool)
			var s_name = effect.get("name", "Unknown")
			var s_val = effect.get("amount", 1)
			var is_self = effect.get("self", false)
			
			var dest_id = owner_id if is_self else target_id
			
			# Apply it (using our helper from the previous step)
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
		elif my_card.damage > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " attack blocked (0 Dmg).")
			emit_signal("damage_dealt", target_id, 0, true)

		if my_card.damage > 0 and enemy_card.retaliate:
			var raw_recoil = my_card.damage
			var self_block = my_card.block_value + my_card.dodge_value 
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
	return p1_opportunity_stat if player_id == 1 else p2_opportunity_stat

func _pay_cost(player_id: int, card: ActionData) -> bool:
	var character = p1_data if player_id == 1 else p2_data
	var is_free = (p1_locked_card != null if player_id == 1 else p2_locked_card != null)
	var rage_is_on = (p1_rage_active if player_id == 1 else p2_rage_active)
	
	var raw_cost = card.cost
	var opp_val = _get_opportunity_value(player_id)
	var effective_single_cost = max(0, raw_cost - opp_val)
	var total_reps = max(1, card.repeat_count)
	var total_cost = effective_single_cost * total_reps
	
	if is_free: total_cost = 0
	
	if rage_is_on and character.class_type == CharacterData.ClassType.HEAVY:
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
		if character.class_type == CharacterData.ClassType.HEAVY:
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

# Change arguments from '_p1_started_injured' to 'p1_started_injured' (remove underscores)
func _handle_status_damage(winner_id, p1_started_injured, p2_started_injured):
	# We iterate through players to apply End-of-Turn effects
	for id in [1, 2]:
		var player = p1_data if id == 1 else p2_data
		var started_injured = p1_started_injured if id == 1 else p2_started_injured
		
		# Check every status this player has
		for s_name in player.statuses.keys():
			match s_name:
				"Injured":
					if started_injured:
						player.current_hp -= 1
						emit_signal("combat_log_updated", ">> P" + str(id) + " suffers Injury damage!")
						emit_signal("damage_dealt", id, 1, false)
				"Poison":
					# EXAMPLE: Future proofing!
					var stacks = player.statuses["Poison"]
					player.current_hp -= stacks
					emit_signal("combat_log_updated", ">> P" + str(id) + " takes Poison dmg!")
					# Decay poison?
					# player.statuses["Poison"] -= 1
					
		if player.current_hp <= 0:
			_handle_death(winner_id)
			return

func _handle_death(winner_id):
	var game_winner = 0
	if p1_data.current_hp > 0: game_winner = 1
	elif p2_data.current_hp > 0: game_winner = 2
	else: game_winner = winner_id 
	emit_signal("game_over", game_winner)
	
	# REMOVED: reset_combat() 
	# We want the stats to stay at 0 so the player can see the final board state. 

func _check_reversal_state():
	var active_attacker = get_attacker()
	
	if attacker_override != 0:
		current_combo_attacker = attacker_override 
		if attacker_override == 1: p2_must_opener = true
		else: p1_must_opener = true
		return

	if active_attacker != 0:
		var att_data = p1_data if active_attacker == 1 else p2_data
		if att_data.current_sp <= 0:
			emit_signal("combat_log_updated", ">> Attacker Out of SP. Combo Ends.")
			current_combo_attacker = 0 
		else:
			current_combo_attacker = active_attacker
	else:
		current_combo_attacker = 0

func _handle_locks(winner_id):
	p1_locked_card = null; p2_locked_card = null
	var winner_card = p1_action_queue if winner_id == 1 else p2_action_queue
	var loser_card_obj = p2_action_queue if winner_id == 1 else p1_action_queue 
	if winner_card.multi_limit > 0:
		emit_signal("combat_log_updated", "Multi Triggered! Loser Locked.")
		if winner_id == 1: p2_locked_card = loser_card_obj
		else: p1_locked_card = loser_card_obj

func _update_turn_constraints(p1_res, p2_res, p1_card, p2_card, p1_parry_win: bool, p2_parry_win: bool):
	var next_p1_limit = 99; var next_p2_limit = 99
	var next_p1_opening = 0; var next_p2_opening = 0
	p1_must_opener = false; p2_must_opener = false
	
	if p1_res["opening"] > 0:
		next_p2_limit = min(next_p2_limit, p1_res["opening"]) 
		next_p1_opening = p1_res["opening"] 
	if p2_res["opening"] > 0:
		next_p1_limit = min(next_p1_limit, p2_res["opening"])
		next_p2_opening = p2_res["opening"]
	
	if p1_card.multi_limit > 0: next_p1_limit = min(next_p1_limit, p1_card.multi_limit)
	if p2_card.multi_limit > 0: next_p2_limit = min(next_p2_limit, p2_card.multi_limit)
		
	if p1_parry_win:
		p2_must_opener = true
		emit_signal("combat_log_updated", ">> P2 is unbalanced! Must use Opener next turn.")
	if p2_parry_win:
		p1_must_opener = true
		emit_signal("combat_log_updated", ">> P1 is unbalanced! Must use Opener next turn.")

	p1_cost_limit = next_p1_limit
	p2_cost_limit = next_p2_limit
	p1_opening_stat = next_p1_opening
	p2_opening_stat = next_p2_opening

	p1_opportunity_stat = p1_res["opportunity"]
	p2_opportunity_stat = p2_res["opportunity"]
	
	if p1_opportunity_stat > 0: emit_signal("combat_log_updated", "P1 gains Opportunity.")
	if p2_opportunity_stat > 0: emit_signal("combat_log_updated", "P2 gains Opportunity.")

func swap_priority():
	priority_player = 3 - priority_player

func get_player(id: int) -> CharacterData:
	return p1_data if id == 1 else p2_data

func get_opponent(id: int) -> CharacterData:
	return p2_data if id == 1 else p1_data

func is_p1_attacker() -> bool:
	if attacker_override == 1: return true
	if attacker_override == 2: return false
	if momentum == 0: return true
	return momentum <= MOMENTUM_P1_MAX

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
	if character.class_type != CharacterData.ClassType.PATIENT: return
	
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
	action.description = "Offence, Defence, Recover 1, Fall Back 2"
	action.type = force_type
	action.cost = 0
	
	# Stats: Recover 1, Fall Back 1
	# Note: Defence actions naturally get +1 Recover in the rules, 
	# so Struggle (Def) will actually recover 2 SP, which makes sense (catching breath).
	action.recover_value = 1 
	action.fall_back_value = 2
	
	return action

func apply_status(target_id: int, status_name: String, value: int = 1):
	var target = p1_data if target_id == 1 else p2_data
	
	# Logic: If already exists, you might want to stack it or refresh it.
	# For "Injured", it's just a binary state (1), so overwriting is fine.
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
		emit_signal("status_applied", target_id, "CURED") # Generic cure msg
