extends Node

# --- SIGNALS ---
# Notify the UI and TestArena of game events
signal state_changed(new_state)
signal clash_resolved(winner_id, log_text)
signal combat_log_updated(text)
signal game_over(winner_id)

# --- STATE MACHINE ---
enum State { SETUP, SELECTION, REVEAL, FEINT_CHECK, RESOLUTION, POST_CLASH, GAME_OVER }
var current_state = State.SETUP

# --- CORE DATA ---
var p1_data: CharacterData
var p2_data: CharacterData
var priority_player: int = 1 
var momentum: int = 0 
var current_combo_attacker: int = 0

# --- TURN CONSTRAINTS (Persist between turns) ---
# Constraints applied TO a player
var p1_cost_limit: int = 99     
var p2_cost_limit: int = 99
# Opening Stat: Level of "Vulnerability" applied TO a player (allows Counters)
var p1_opening_stat: int = 0    
var p2_opening_stat: int = 0
# Opportunity: Bonus Momentum/Discount for the player's NEXT move
var p1_opportunity_stat: int = 0
var p2_opportunity_stat: int = 0
# Forced Opener: Applied by Parry
var p1_must_opener: bool = false
var p2_must_opener: bool = false

# --- STATUS EFFECTS ---
var p1_is_injured: bool = false
var p2_is_injured: bool = false

# --- CURRENT TURN ACTIONS ---
var p1_action_queue: ActionData
var p2_action_queue: ActionData
var p1_locked_card: ActionData = null # If set, player MUST use this card (Multi)
var p2_locked_card: ActionData = null

# --- FEINT LOGIC ---
var p1_pending_feint: bool = false
var p2_pending_feint: bool = false

# ==============================================================================
# INITIALIZATION & RESET
# ==============================================================================

func start_combat(p1: CharacterData, p2: CharacterData):
	p1_data = p1
	p2_data = p2
	reset_combat()

func reset_combat():
	# Reset Character States
	p1_data.reset_stats()
	p2_data.reset_stats()
	
	# Reset Global Game State
	momentum = 0 
	current_combo_attacker = 0
	p1_locked_card = null
	p2_locked_card = null
	
	# Reset Constraints
	p1_cost_limit = 99; p2_cost_limit = 99
	p1_opening_stat = 0; p2_opening_stat = 0
	p1_opportunity_stat = 0; p2_opportunity_stat = 0
	p1_must_opener = false; p2_must_opener = false
	p1_is_injured = false; p2_is_injured = false
	p1_pending_feint = false; p2_pending_feint = false
	
	# Determine Priority
	if p1_data.speed > p2_data.speed: priority_player = 1
	elif p2_data.speed > p1_data.speed: priority_player = 2
	else: priority_player = randi_range(1, 2)
		
	print("\n>>> COMBAT RESET! Starting from Initial Clash (Neutral) <<<")
	change_state(State.SELECTION)

# Helper: Returns 0 (Neutral), 1 (P1), or 2 (P2)
func get_attacker() -> int:
	if current_combo_attacker != 0: return current_combo_attacker
	if momentum == 0: return 0 
	if momentum <= 4: return 1 
	return 2 

# ==============================================================================
# STATE MACHINE & INPUT
# ==============================================================================

func change_state(new_state: State):
	current_state = new_state
	emit_signal("state_changed", current_state)
	
	match current_state:
		State.SELECTION:
			# If locked by Multi, auto-select the locked card
			if p1_locked_card: player_select_action(1, p1_locked_card)
			if p2_locked_card: player_select_action(2, p2_locked_card)
		State.REVEAL:
			_enter_reveal_phase()
		State.FEINT_CHECK:
			pass # Input handled via signals in TestArena
		State.RESOLUTION:
			resolve_clash()

func player_select_action(player_id: int, action: ActionData):
	if current_state == State.SELECTION:
		if player_id == 1: p1_action_queue = action
		else: p2_action_queue = action
		
		# If both players have selected, proceed
		if p1_action_queue and p2_action_queue:
			change_state(State.REVEAL)
			
	elif current_state == State.FEINT_CHECK:
		_handle_feint_selection(player_id, action)

# ==============================================================================
# FEINT MECHANICS
# ==============================================================================

func _enter_reveal_phase():
	emit_signal("combat_log_updated", "REVEAL: P1 chose " + p1_action_queue.display_name + " | P2 chose " + p2_action_queue.display_name)
	
	# Detect if any card has the Feint trait
	p1_pending_feint = p1_action_queue.feint
	p2_pending_feint = p2_action_queue.feint

	if p1_pending_feint or p2_pending_feint:
		change_state(State.FEINT_CHECK)
	else:
		change_state(State.RESOLUTION)

func _handle_feint_selection(player_id: int, secondary_action: ActionData):
	# If secondary_action is null, it means "Skip"
	if secondary_action == null:
		emit_signal("combat_log_updated", "P" + str(player_id) + " skips Feint combination.")
		_clear_feint_flag(player_id)
		_check_feint_completion()
		return

	var base_card = p1_action_queue if player_id == 1 else p2_action_queue
	var character = p1_data if player_id == 1 else p2_data
	
	# Calculate Combined Cost
	var total_cost = base_card.cost + secondary_action.cost
	var opp_val = _get_opportunity_value(player_id)
	var effective_total = max(0, total_cost - opp_val)
	
	# Check Affordability
	if character.current_sp >= effective_total:
		var combined = _combine_actions(base_card, secondary_action)
		emit_signal("combat_log_updated", "P" + str(player_id) + " Feint Successful! Combined into: " + combined.display_name)
		if player_id == 1: p1_action_queue = combined
		else: p2_action_queue = combined
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

# Merges two actions into one new ActionData resource
func _combine_actions(base: ActionData, sec: ActionData) -> ActionData:
	var new_card = base.duplicate()
	new_card.display_name = base.display_name + " + " + sec.display_name
	
	# Sum numeric stats
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
	
	# Take maximum for limits
	new_card.counter_value = max(new_card.counter_value, sec.counter_value) 
	new_card.repeat_count = max(new_card.repeat_count, sec.repeat_count)
	
	# Boolean flags (OR logic)
	if sec.guard_break: new_card.guard_break = true
	if sec.injure: new_card.injure = true
	if sec.retaliate: new_card.retaliate = true
	if sec.is_parry: new_card.is_parry = true
	if sec.is_super: new_card.is_super = true
	if sec.is_opener: new_card.is_opener = true
	
	new_card.feint = false # Prevent recursion
	return new_card

# ==============================================================================
# RESOLUTION LOGIC
# ==============================================================================

func resolve_clash():
	var winner_id = 0
	
	# 1. DETERMINE WINNER (Offence > Defence, Low Cost > High Cost)
	if p1_action_queue.type == ActionData.Type.OFFENCE and p2_action_queue.type == ActionData.Type.DEFENCE: winner_id = 1
	elif p2_action_queue.type == ActionData.Type.OFFENCE and p1_action_queue.type == ActionData.Type.DEFENCE: winner_id = 2
	elif p1_action_queue.cost < p2_action_queue.cost: winner_id = 1
	elif p2_action_queue.cost < p1_action_queue.cost: winner_id = 2
	else:
		emit_signal("combat_log_updated", "Tie! Priority Token Used.")
		winner_id = priority_player
		swap_priority()

	emit_signal("clash_resolved", winner_id, "Clash Winner: P" + str(winner_id))
	
	var is_initial_clash = (momentum == 0)
	var start_momentum = momentum 
	
	# --- PHASE 0: PAY COSTS ---
	var p1_active = _pay_cost(1, p1_action_queue)
	var p2_active = _pay_cost(2, p2_action_queue)

	# Super Check
	if p1_active and p1_action_queue.is_super:
		p1_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P1 unleashes their Ultimate Art!")
	if p2_active and p2_action_queue.is_super:
		p2_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P2 unleashes their Ultimate Art!")

	# --- PHASE 1: SELF EFFECTS (Recover/Heal) ---
	if p1_active: _apply_self_effects(1, p1_action_queue)
	if p2_active: _apply_self_effects(2, p2_action_queue)

	# --- PARRY PRE-CALCULATION ---
	# We calculate Momentum results early to see if a Parry condition is met.
	var p1_parry_win = false
	var p2_parry_win = false
	
	var p1_gain = _calculate_projected_momentum(1, p1_action_queue, p1_active)
	var p2_gain = _calculate_projected_momentum(2, p2_action_queue, p2_active)
	
	# If Parrying, steal opponent's gain
	var p1_eff_gain = p1_gain + (p2_gain if (p1_active and p1_action_queue.is_parry) else 0)
	var p2_eff_gain = p2_gain + (p1_gain if (p2_active and p2_action_queue.is_parry) else 0)
	
	# If I parry you, you generate 0 (unless you parried me too)
	if p1_active and p1_action_queue.is_parry and not (p2_active and p2_action_queue.is_parry): p2_eff_gain = 0
	if p2_active and p2_action_queue.is_parry and not (p1_active and p1_action_queue.is_parry): p1_eff_gain = 0
	
	# Calculate delta to check Parry Success direction
	var delta = -p1_eff_gain + p2_eff_gain # P1 pushes left (-), P2 pushes right (+)
	
	if p1_active and p1_action_queue.is_parry and delta < 0: 
		p1_parry_win = true
		emit_signal("combat_log_updated", ">>> P1 PARRIES! (Momentum Stolen & Immunity)")
		
	if p2_active and p2_action_queue.is_parry and delta > 0: 
		p2_parry_win = true
		emit_signal("combat_log_updated", ">>> P2 PARRIES! (Momentum Stolen & Immunity)")

	# --- PHASE 2: COMBAT EFFECTS (Damage/Injure/Retaliate) ---
	var p1_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	var p2_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	# If opponent won parry, I am Immune
	if p1_active: p1_results = _apply_combat_effects(1, 2, p1_action_queue, p2_action_queue, p2_parry_win)
	if p2_active: p2_results = _apply_combat_effects(2, 1, p2_action_queue, p1_action_queue, p1_parry_win)
	
	_update_turn_constraints(p1_results, p2_results, p1_action_queue, p2_action_queue, p1_parry_win, p2_parry_win)
	
	if p1_results["fatal"] or p2_results["fatal"]:
		_handle_death(winner_id)
		return 
	
	# --- PHASE 3: MOMENTUM ---
	var p1_is_offence = (p1_action_queue.type == ActionData.Type.OFFENCE)
	var p2_is_offence = (p2_action_queue.type == ActionData.Type.OFFENCE)
	
	# Apply Momentum (Offence First) using the Pre-Calculated "Effective Gains" (Parry Steal Logic)
	if p1_active and p1_is_offence: _apply_momentum_effects(1, p1_action_queue, p1_eff_gain)
	if p2_active and p2_is_offence: _apply_momentum_effects(2, p2_action_queue, p2_eff_gain)
	
	if p1_active and not p1_is_offence: _apply_momentum_effects(1, p1_action_queue, p1_eff_gain)
	if p2_active and not p2_is_offence: _apply_momentum_effects(2, p2_action_queue, p2_eff_gain)
	
	# --- PHASE 4: STATUS TICK ---
	_handle_status_damage(winner_id)

	# --- END OF RESOLUTION ---
	if is_initial_clash:
		momentum = 4 if winner_id == 1 else 5
		emit_signal("combat_log_updated", "Initial Clash Set! Momentum: " + str(momentum))
	
	_check_reversal(winner_id, start_momentum)
	_handle_locks(winner_id)

	# Clear queues
	p1_action_queue = null
	p2_action_queue = null
	
	change_state(State.POST_CLASH)
	change_state(State.SELECTION)

# ==============================================================================
# PHASE IMPLEMENTATIONS (The Split)
# ==============================================================================

# Phase 1: Recover SP, Heal HP
func _apply_self_effects(owner_id: int, my_card: ActionData):
	var owner = p1_data if owner_id == 1 else p2_data
	var total_hits = max(1, my_card.repeat_count)
	
	for i in range(total_hits):
		# DEFENCE PASSIVE: All Defence cards get +1 Recover
		var actual_recover = my_card.recover_value
		if my_card.type == ActionData.Type.DEFENCE:
			actual_recover += 1
		
		if actual_recover > 0: 
			owner.current_sp = min(owner.current_sp + actual_recover, owner.max_sp)
			
		if my_card.heal_value > 0: 
			owner.current_hp = min(owner.current_hp + my_card.heal_value, owner.max_hp)

		# Cure Injury (Heal or Fall Back cleanses it)
		if my_card.heal_value > 0 or my_card.fall_back_value > 0:
			if owner_id == 1 and p1_is_injured:
				p1_is_injured = false
				emit_signal("combat_log_updated", ">> P1 cures Injury!")
			elif owner_id == 2 and p2_is_injured:
				p2_is_injured = false
				emit_signal("combat_log_updated", ">> P2 cures Injury!")

# Phase 2: Combat (Damage, Block, Status App)
func _apply_combat_effects(owner_id: int, target_id: int, my_card: ActionData, enemy_card: ActionData, target_is_immune: bool) -> Dictionary:
	var owner = p1_data if owner_id == 1 else p2_data
	var target = p2_data if owner_id == 1 else p1_data
	var result = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	# PARRY/IMMUNITY CHECK
	if target_is_immune:
		emit_signal("combat_log_updated", "P" + str(owner_id) + " attack PARRIED/NULLIFIED!")
		return result

	var total_hits = max(1, my_card.repeat_count)
	for i in range(total_hits):
		# 1. Calculate Damage
		var enemy_block = enemy_card.block_value + enemy_card.dodge_value
		if my_card.guard_break: enemy_block = 0
		var net_damage = max(0, my_card.damage - enemy_block)
		
		if net_damage > 0:
			target.current_hp -= net_damage
			emit_signal("combat_log_updated", "P" + str(owner_id) + " hits P" + str(target_id) + ": -" + str(net_damage) + " HP")
			
			# On-Hit Effects
			if my_card.tiring > 0:
				target.current_sp = max(0, target.current_sp - my_card.tiring)
				emit_signal("combat_log_updated", ">> Tiring! P" + str(target_id) + " drained of " + str(my_card.tiring) + " SP.")
			
			if my_card.injure:
				if target_id == 1 and not p1_is_injured:
					p1_is_injured = true
					emit_signal("combat_log_updated", ">> P1 is Injured!")
				elif target_id == 2 and not p2_is_injured:
					p2_is_injured = true
					emit_signal("combat_log_updated", ">> P2 is Injured!")

		elif my_card.damage > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " attack blocked/dodged.")

		# 2. Retaliate Check
		if my_card.damage > 0 and enemy_card.retaliate:
			var raw_recoil = my_card.damage
			var self_block = my_card.block_value + my_card.dodge_value
			var net_recoil = max(0, raw_recoil - self_block)
			if net_recoil > 0:
				owner.current_hp -= net_recoil
				emit_signal("combat_log_updated", ">> RETALIATE! P" + str(target_id) + " reflects " + str(net_recoil) + " dmg!")
				if owner.current_hp <= 0:
					result["fatal"] = true
					return result
			else:
				emit_signal("combat_log_updated", ">> RETALIATE! Reflected damage blocked by P" + str(owner_id) + ".")

		# 3. Check Death
		if target.current_hp <= 0:
			result["fatal"] = true
			return result
			
		# 4. Result Stats
		if my_card.create_opening > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " creates an Opening! (Lvl " + str(my_card.create_opening) + ")")
			result["opening"] = my_card.create_opening
		
		if my_card.opportunity > 0:
			result["opportunity"] = my_card.opportunity
			
	return result

# Phase 3: Momentum
# 'eff_gain' is pre-calculated in resolve_clash (accounting for Parry steals)
func _apply_momentum_effects(owner_id: int, my_card: ActionData, eff_gain: int):
	var loss = my_card.fall_back_value 
	if owner_id == 1:
		momentum = clampi(momentum - eff_gain + loss, 1, 8)
	else:
		momentum = clampi(momentum + eff_gain - loss, 1, 8)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Calculates raw momentum output (Card + Opportunity) without Parry logic
func _calculate_projected_momentum(player_id: int, card: ActionData, is_active: bool) -> int:
	if not is_active: return 0
	var opp_val = _get_opportunity_value(player_id)
	return card.momentum_gain + opp_val

func _get_opportunity_value(player_id: int) -> int:
	return p1_opportunity_stat if player_id == 1 else p2_opportunity_stat

func _pay_cost(player_id: int, card: ActionData) -> bool:
	var character = p1_data if player_id == 1 else p2_data
	var is_free = (p1_locked_card != null if player_id == 1 else p2_locked_card != null)
	
	var raw_cost = card.cost
	var opp_val = _get_opportunity_value(player_id)
	var effective_cost = max(0, raw_cost - opp_val)
	
	if is_free: 
		effective_cost = 0
		emit_signal("combat_log_updated", "P" + str(player_id) + " locked by Multi: Action is FREE.")
	
	if character.current_sp >= effective_cost:
		character.current_sp -= effective_cost
		return true
	else:
		emit_signal("combat_log_updated", ">> P" + str(player_id) + " Out of SP! Action Fails!")
		return false

func _handle_status_damage(winner_id):
	# Note: Damage applies if you started injured AND are still injured
	# (For simplicity, we check current state, assuming status tick happens at end)
	if p1_is_injured:
		p1_data.current_hp -= 1
		emit_signal("combat_log_updated", ">> P1 takes 1 damage from Injury.")
		if p1_data.current_hp <= 0: _handle_death(winner_id)

	if p2_is_injured:
		p2_data.current_hp -= 1
		emit_signal("combat_log_updated", ">> P2 takes 1 damage from Injury.")
		if p2_data.current_hp <= 0: _handle_death(winner_id)

func _handle_death(winner_id):
	var game_winner = 0
	if p1_data.current_hp > 0: game_winner = 1
	elif p2_data.current_hp > 0: game_winner = 2
	else: game_winner = winner_id 
	emit_signal("game_over", game_winner)
	reset_combat() 

func _check_reversal(winner_id, start_momentum):
	var loser_id = 3 - winner_id
	var loser_card = p1_action_queue if loser_id == 1 else p2_action_queue
	
	var reversal_triggered = false
	if loser_card.reversal:
		var moved_closer = false
		if loser_id == 1 and momentum < start_momentum: moved_closer = true
		if loser_id == 2 and momentum > start_momentum: moved_closer = true
		
		if moved_closer:
			current_combo_attacker = loser_id 
			reversal_triggered = true
			emit_signal("combat_log_updated", ">>> REVERSAL! Player " + str(loser_id) + " seizes the Combo! <<<")

	var active_attacker = get_attacker()
	if active_attacker != 0:
		var att_data = p1_data if active_attacker == 1 else p2_data
		if att_data.current_sp <= 0:
			emit_signal("combat_log_updated", ">> Attacker Out of SP. Combo Ends.")
			current_combo_attacker = 0 
		else:
			if not reversal_triggered:
				current_combo_attacker = active_attacker

func _handle_locks(winner_id):
	p1_locked_card = null
	p2_locked_card = null
	
	var winner_card = p1_action_queue if winner_id == 1 else p2_action_queue
	var loser_card_obj = p2_action_queue if winner_id == 1 else p1_action_queue 
	
	if winner_card.multi_limit > 0:
		emit_signal("combat_log_updated", "Multi Triggered! Loser Locked.")
		if winner_id == 1: p2_locked_card = loser_card_obj
		else: p1_locked_card = loser_card_obj

func _update_turn_constraints(p1_res, p2_res, p1_card, p2_card, p1_parry_win: bool, p2_parry_win: bool):
	var next_p1_limit = 99
	var next_p2_limit = 99
	var next_p1_opening = 0
	var next_p2_opening = 0
	
	p1_must_opener = false
	p2_must_opener = false
	
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
