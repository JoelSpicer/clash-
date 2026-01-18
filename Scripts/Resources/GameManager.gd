extends Node

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

# --- CONFIGURATION ---
const TOTAL_MOMENTUM_SLOTS: int = 8  #Change this to 4, 6, 10, 12, etc.

# --- DYNAMIC CALCULATIONS ---
# These run once to set the boundaries based on the config above.
# Example for 8 slots: P1_MAX = 4, P2_START = 5.
var MOMENTUM_P1_MAX: int = 4
var MOMENTUM_P2_START: int = 5


# --- STATE MACHINE ---
enum State { SETUP, SELECTION, REVEAL, FEINT_CHECK, RESOLUTION, POST_CLASH, GAME_OVER }
var current_state = State.SETUP
var temp_p1_class_selection: int = 0
var temp_p2_class_selection: int = 0 # New: Remember P2's class choice
var editing_player_index: int = 1    # New: Are we building P1 (1) or P2 (2)?
var p2_is_custom: bool = false       # New: Did the user ask to customize P2?
enum Difficulty { VERY_EASY, EASY, MEDIUM, HARD }
var ai_difficulty: Difficulty = Difficulty.MEDIUM # Default
var attacker_override: int = 0 # 0 = None, 1 = P1 Force Attack, 2 = P2 Force Attack

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

# --- STATUS EFFECTS ---
var p1_is_injured: bool = false
var p2_is_injured: bool = false

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

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready():
	# 1. CALCULATE BOUNDARIES SAFELY
	# We use float division / 2.0 to silence the integer division warning
	MOMENTUM_P1_MAX = int(TOTAL_MOMENTUM_SLOTS / 2.0)
	MOMENTUM_P2_START = MOMENTUM_P1_MAX + 1
	
	print("--- GAME MANAGER READY ---")
	print("Momentum Config: Total=", TOTAL_MOMENTUM_SLOTS, " | P1_Max=", MOMENTUM_P1_MAX, " | P2_Start=", MOMENTUM_P2_START)
	
	# 2. INITIALIZE LOGIC
	priority_player = 1
	momentum = 0

func start_combat(p1: CharacterData, p2: CharacterData):
	p1_data = p1
	p2_data = p2
	reset_combat()

func reset_combat():
	p1_data.reset_stats()
	p2_data.reset_stats()
	momentum = 0 
	current_combo_attacker = 0
	p1_locked_card = null; p2_locked_card = null
	
	p1_cost_limit = 99; p2_cost_limit = 99
	p1_opening_stat = 0; p2_opening_stat = 0
	p1_opportunity_stat = 0; p2_opportunity_stat = 0
	p1_must_opener = false; p2_must_opener = false
	p1_is_injured = false; p2_is_injured = false
	p1_pending_feint = false; p2_pending_feint = false
	
	p1_rage_active = false; p2_rage_active = false
	p1_keep_up_active = false; p2_keep_up_active = false
	
	if p1_data.speed > p2_data.speed: priority_player = 1
	elif p2_data.speed > p1_data.speed: priority_player = 2
	else: priority_player = randi_range(1, 2)
		
	print("\n>>> COMBAT RESET! Starting from Initial Clash (Neutral) <<<")
	change_state(State.SELECTION)

func get_attacker() -> int:
	# 1. Combo Lock (Highest Priority - mid-combo)
	if current_combo_attacker != 0: return current_combo_attacker
	
	# 2. Reversal Override (Crucial Fix)
	# If a reversal happened, this variable tells us who gets the turn,
	# regardless of where the momentum slider actually is.
	if attacker_override == 1: return 1
	if attacker_override == 2: return 2
	
	# 3. Neutral State (Initial Clash)
	if momentum == 0: return 0 
	
	# 4. Standard Momentum Position (Dynamic)
	# Uses the calculated variable instead of hardcoded '4'
	if momentum <= MOMENTUM_P1_MAX: return 1 
	return 2

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
		final_action = action.duplicate() # CRITICAL: Don't edit the original file!
		final_action.cost += 1 # Auto-deduct the 1 SP cost
		
		match tech_idx:
			1: # Opener
				if final_action.type == ActionData.Type.OFFENCE:
					final_action.is_opener = true
					final_action.display_name += "+" # Visual indicator
			2: # Tiring
				final_action.tiring += 1
				final_action.display_name += "+"
			3: # Momentum
				final_action.momentum_gain += 1
				final_action.display_name += "+"
	
	# 2. Standard Logic (Using final_action instead of action)
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
		# Note: Feints use the modified card as the "secondary" card
		_handle_feint_selection(player_id, final_action)

# ==============================================================================
# FEINT MECHANICS
# ==============================================================================

func _enter_reveal_phase():
	emit_signal("combat_log_updated", "\nREVEAL: P1 chose " + p1_action_queue.display_name + " | P2 chose " + p2_action_queue.display_name)
	
	# --- NEW VISUAL STEP ---
	# 1. Tell UI to play animation
	emit_signal("request_clash_animation", p1_action_queue, p2_action_queue)
	
	# 2. Wait for it to finish
	await self.clash_animation_finished
	# -----------------------
	
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
	
	# Affordability check (Handles Rage Passive for Feints too)
	var can_afford = false
	if character.current_sp >= total_required:
		can_afford = true
	elif character.class_type == CharacterData.ClassType.HEAVY and (character.current_sp + character.current_hp) > total_required:
		can_afford = true # Rage Logic
		
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
	# 1. RESET OVERRIDE
	attacker_override = 0
	
	var winner_id = 0
	
	# 2. DETERMINE WINNER (Standard Priority)
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
	
	# Update Combo Counts (For Passives)
	if winner_id == 1 and p1_action_queue.type == ActionData.Type.OFFENCE: p1_data.combo_action_count += 1
	else: p1_data.combo_action_count = 0
	
	if winner_id == 2 and p2_action_queue.type == ActionData.Type.OFFENCE: p2_data.combo_action_count += 1
	else: p2_data.combo_action_count = 0
	
	# --- PHASE 0: PAY COSTS ---
	var p1_started_injured = p1_is_injured
	var p2_started_injured = p2_is_injured
	
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
	
	# C. Delta Calculation
	var p1_reps = max(1, p1_action_queue.repeat_count) if p1_active else 1
	var p2_reps = max(1, p2_action_queue.repeat_count) if p2_active else 1
	
	var p1_fb = (p1_action_queue.fall_back_value * p1_reps) if p1_active else 0
	var p2_fb = (p2_action_queue.fall_back_value * p2_reps) if p2_active else 0
	
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
	
	# --- PHASE 3: APPLY MOMENTUM & REVERSAL (FIXED) ---
	
	var p1_reversed = (p1_active and p1_action_queue.reversal and delta < 0)
	var p2_reversed = (p2_active and p2_action_queue.reversal and delta > 0)

	if is_initial_clash:
		# A. Initial Clash: Winner sets the physical Momentum Position
		momentum = MOMENTUM_P1_MAX if winner_id == 1 else MOMENTUM_P2_START
		print("DEBUG: Initial Clash Winner: P", winner_id, " | Set Mom: ", momentum)
		
		# B. But Reversal can steal the TURN
		if p1_reversed:
			attacker_override = 1
			emit_signal("combat_log_updated", ">> P1 Reverses! Seizing Offence.")
		elif p2_reversed:
			attacker_override = 2
			emit_signal("combat_log_updated", ">> P2 Reverses! Seizing Offence.")
			
	else:
		# Standard Gameplay
		# 1. Apply Physics (Delta) regardless of reversal
		momentum = clamp_momentum(momentum + delta)
		
		# 2. Apply Turn Override if Reversal happened
		if p1_reversed:
			attacker_override = 1
			emit_signal("combat_log_updated", ">> P1 REVERSAL SUCCESSFUL!")
		elif p2_reversed:
			attacker_override = 2
			emit_signal("combat_log_updated", ">> P2 REVERSAL SUCCESSFUL!")

	# --- CLEANUP ---
	_handle_status_damage(winner_id, p1_started_injured, p2_started_injured)
	
	# Pass the start momentum to check reversal logic
	# (Note: In standard flow, we use the current momentum state to decide next turn)
	_check_reversal_state() 
	
	_handle_locks(winner_id)

	p1_action_queue = null
	p2_action_queue = null
	
	change_state(State.POST_CLASH)
	change_state(State.SELECTION)

# ==============================================================================
# PHASE IMPLEMENTATIONS
# ==============================================================================

func _apply_phase_1_self_effects(owner_id: int, my_card: ActionData):
	var character = p1_data if owner_id == 1 else p2_data
	var total_hits = max(1, my_card.repeat_count)
	
	# FIX: Use 'character' instead of 'owner'
	if character.class_type == CharacterData.ClassType.QUICK:
		if character.combo_action_count > 0 and (character.combo_action_count % 3 == 0):
			character.current_sp = min(character.current_sp + 1, character.max_sp)
			emit_signal("combat_log_updated", ">> Relentless! P" + str(owner_id) + " recovers 1 SP.")
	
	for i in range(total_hits):
		var actual_recover = my_card.recover_value
		if my_card.type == ActionData.Type.DEFENCE: actual_recover += 1
		
		if actual_recover > 0: 
			# FIX: Use 'character' here
			character.current_sp = min(character.current_sp + actual_recover, character.max_sp)
			
		if my_card.heal_value > 0: 
			# FIX: Use 'character' here
			character.current_hp = min(character.current_hp + my_card.heal_value, character.max_hp)
			emit_signal("healing_received", owner_id, my_card.heal_value)

		if my_card.heal_value > 0 or my_card.fall_back_value > 0:
			if owner_id == 1 and p1_is_injured:
				p1_is_injured = false
				emit_signal("combat_log_updated", ">> P1 cures Injury!")
				emit_signal("status_applied", 1, "CURED!")
			elif owner_id == 2 and p2_is_injured:
				p2_is_injured = false
				emit_signal("combat_log_updated", ">> P2 cures Injury!")
				emit_signal("status_applied", 2, "CURED!")

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
		
		# --- STATUS EFFECTS ---
		if my_card.tiring > 0:
			# PASSIVE: RAGE (Heavy Class) - Losing SP from Tiring can be taken as HP
			if target.class_type == CharacterData.ClassType.HEAVY and target.current_sp < my_card.tiring:
				# Simple Logic: If SP runs out, take remaining as damage
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
		
		if my_card.injure:
			if target_id == 1 and not p1_is_injured:
				p1_is_injured = true
				emit_signal("combat_log_updated", ">> P1 is Injured!")
			elif target_id == 2 and not p2_is_injured:
				p2_is_injured = true
				emit_signal("combat_log_updated", ">> P2 is Injured!")

		if my_card.create_opening > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " creates an Opening! (Lvl " + str(my_card.create_opening) + ")")
			result["opening"] = my_card.create_opening
		
		if my_card.opportunity > 0:
			result["opportunity"] = my_card.opportunity

		# --- DAMAGE ---
		if net_damage > 0:
			target.current_hp -= net_damage
			emit_signal("damage_dealt", target_id, net_damage, false)
			emit_signal("combat_log_updated", "P" + str(owner_id) + " hits P" + str(target_id) + ": -" + str(net_damage) + " HP")
		elif my_card.damage > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " attack blocked (0 Dmg).")
			emit_signal("damage_dealt", target_id, 0, true)

		# --- RETALIATE ---
		if my_card.damage > 0 and enemy_card.retaliate:
			var raw_recoil = my_card.damage
			var self_block = my_card.block_value + my_card.dodge_value 
			var net_recoil = max(0, raw_recoil - self_block)
			if net_recoil > 0:
				# FIX: Use 'character' instead of 'owner'
				character.current_hp -= net_recoil
				emit_signal("combat_log_updated", ">> RETALIATE! P" + str(target_id) + " reflects " + str(net_recoil) + " dmg!")
				
				# FIX: Use 'character' here too
				if character.current_hp <= 0:
					result["fatal"] = true
					return result
			else:
				emit_signal("combat_log_updated", ">> RETALIATE! Reflected damage blocked by P" + str(owner_id) + ".")

		if target.current_hp <= 0:
			result["fatal"] = true
			return result
			
	return result

func _apply_phase_3_momentum(owner_id: int, my_card: ActionData, effective_gain: int):
	var character = p1_data if owner_id == 1 else p2_data
	var keep_up_is_on = (p1_keep_up_active if owner_id == 1 else p2_keep_up_active)
	
	var reps = max(1, my_card.repeat_count)
	var total_loss = my_card.fall_back_value * reps
	
	#keep up logic
	if keep_up_is_on and character.class_type == CharacterData.ClassType.PATIENT and total_loss > 0:
		if character.current_sp >= total_loss:
			character.current_sp -= total_loss
			total_loss = 0
			emit_signal("combat_log_updated", ">> KEEP-UP! P" + str(owner_id) + " spent SP to hold ground.")
	
	if owner_id == 1:
		momentum = clamp_momentum(momentum - effective_gain + total_loss)
	else:
		momentum = clamp_momentum(momentum + effective_gain - total_loss)
		

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
	
	# --- RAGE LOGIC ---
	# If Rage is ON, we pay with HP.
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
		# PASSIVE: RAGE (Heavy Class)
		# "Whenever you would lose SP, you can instead choose to lose the same amount of HP."
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

func _handle_status_damage(winner_id, p1_started_injured: bool, p2_started_injured: bool):
	if p1_is_injured and p1_started_injured:
		p1_data.current_hp -= 1
		emit_signal("combat_log_updated", ">> P1 takes 1 damage from Injury.")
		emit_signal("damage_dealt", 1, 1, false) # Trigger VFX (Target 1, Amount 1, Not Blocked)
		if p1_data.current_hp <= 0: _handle_death(winner_id)

	if p2_is_injured and p2_started_injured:
		p2_data.current_hp -= 1
		emit_signal("combat_log_updated", ">> P2 takes 1 damage from Injury.")
		emit_signal("damage_dealt", 2, 1, false) # Trigger VFX
		if p2_data.current_hp <= 0: _handle_death(winner_id)

func _handle_death(winner_id):
	var game_winner = 0
	if p1_data.current_hp > 0: game_winner = 1
	elif p2_data.current_hp > 0: game_winner = 2
	else: game_winner = winner_id 
	emit_signal("game_over", game_winner)
	reset_combat() 

func _check_reversal_state():
	# 1. Check if a Reversal Triggered (Logic copied from resolve_clash for safety)
	# But actually, we already set attacker_override in resolve_clash.
	# We just need to update 'current_combo_attacker' based on the FINAL state.
	
	var active_attacker = get_attacker()
	
	# Handle Reversal "Must Opener" penalty
	if attacker_override != 0:
		# A reversal happened this turn
		current_combo_attacker = attacker_override # Reverser starts new combo
		
		# The VICTIM of the reversal must use an opener next time they get a turn
		if attacker_override == 1: p2_must_opener = true
		else: p1_must_opener = true
		return

	# Handle Standard Flow
	if active_attacker != 0:
		var att_data = p1_data if active_attacker == 1 else p2_data
		
		# If Attacker is out of SP, combo breaks
		if att_data.current_sp <= 0:
			emit_signal("combat_log_updated", ">> Attacker Out of SP. Combo Ends.")
			current_combo_attacker = 0 
		else:
			# CRITICAL FIX: Maintain the combo state!
			# If I am the attacker now, I am starting/continuing a combo.
			current_combo_attacker = active_attacker
	else:
		# Neutral state (Momentum 0?)
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


# Returns the data for the requested player ID
func get_player(id: int) -> CharacterData:
	return p1_data if id == 1 else p2_data

# Returns the data for the OTHER player (the enemy of 'id')
func get_opponent(id: int) -> CharacterData:
	return p2_data if id == 1 else p1_data



func is_p1_attacker() -> bool:
	# 1. Check Overrides (Reversals)
	if attacker_override == 1: return true
	if attacker_override == 2: return false
	
	# 2. Check Momentum
	# If momentum is 0 (error case), default to P1
	if momentum == 0: return true
	
	# Standard Check: Is momentum on the left side (1 to P1_MAX)?
	return momentum <= MOMENTUM_P1_MAX

# Clamps momentum to the configured range
func clamp_momentum(val: int) -> int:
	return clampi(val, 1, TOTAL_MOMENTUM_SLOTS)

# Returns the "Winning" momentum value for a specific player (Used for Reversals/Initial Clash)
func get_advantage_momentum(player_id: int) -> int:
	if player_id == 1:
		# P1 wants to be one step inward from their max.
		# E.g. (4 slots -> 1), (8 slots -> 3), (10 slots -> 4)
		return max(1, MOMENTUM_P1_MAX - 1)
	else:
		# P2 wants to be one step inward from their start.
		# E.g. (4 slots -> 4), (8 slots -> 6), (10 slots -> 7)
		return min(TOTAL_MOMENTUM_SLOTS, MOMENTUM_P2_START + 1)

# Returns the "Wall" momentum value (Used for cornered logic)
func get_wall_momentum(player_id: int) -> int:
	if player_id == 1: return 1
	else: return TOTAL_MOMENTUM_SLOTS
