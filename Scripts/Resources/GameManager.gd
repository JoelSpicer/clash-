extends Node

# --- SIGNALS ---
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

# ==============================================================================
# INITIALIZATION
# ==============================================================================

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
	
	if p1_data.speed > p2_data.speed: priority_player = 1
	elif p2_data.speed > p1_data.speed: priority_player = 2
	else: priority_player = randi_range(1, 2)
		
	print("\n>>> COMBAT RESET! Starting from Initial Clash (Neutral) <<<")
	change_state(State.SELECTION)

func get_attacker() -> int:
	if current_combo_attacker != 0: return current_combo_attacker
	if momentum == 0: return 0 
	if momentum <= 4: return 1 
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

func player_select_action(player_id: int, action: ActionData):
	if current_state == State.SELECTION:
		if player_id == 1: p1_action_queue = action
		else: p2_action_queue = action
		
		if p1_action_queue and p2_action_queue:
			change_state(State.REVEAL)
			
	elif current_state == State.FEINT_CHECK:
		_handle_feint_selection(player_id, action)

# ==============================================================================
# FEINT MECHANICS
# ==============================================================================

func _enter_reveal_phase():
	emit_signal("combat_log_updated", "REVEAL: P1 chose " + p1_action_queue.display_name + " | P2 chose " + p2_action_queue.display_name)
	
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
	var winner_id = 0
	
	# 1. DETERMINE WINNER
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
	
	# --- SNAPSHOT STATUS ---
	var p1_started_injured = p1_is_injured
	var p2_started_injured = p2_is_injured
	
	# --- PHASE 0: PAY COSTS ---
	var p1_active = _pay_cost(1, p1_action_queue)
	var p2_active = _pay_cost(2, p2_action_queue)

	if p1_active and p1_action_queue.is_super:
		p1_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P1 unleashes their Ultimate Art!")
	if p2_active and p2_action_queue.is_super:
		p2_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P2 unleashes their Ultimate Art!")

	# --- PHASE 1: SELF EFFECTS (Recover/Heal) ---
	if p1_active: _apply_phase_1_self_effects(1, p1_action_queue)
	if p2_active: _apply_phase_1_self_effects(2, p2_action_queue)

	# --- MOMENTUM PRE-CALCULATION ---
	
	# 1. Dodge Check
	var p1_is_dodged = false
	var p2_is_dodged = false
	if p2_active and p2_action_queue.dodge_value > 0 and p2_action_queue.dodge_value >= p1_action_queue.cost:
		p1_is_dodged = true
	if p1_active and p1_action_queue.dodge_value > 0 and p1_action_queue.dodge_value >= p2_action_queue.cost:
		p2_is_dodged = true
		
	# 2. Parry Check
	var p1_parries = (p1_active and p1_action_queue.is_parry)
	var p2_parries = (p2_active and p2_action_queue.is_parry)
	
	# 3. Base Gains
	var p1_base_gain = _calculate_projected_momentum(1, p1_action_queue, p1_active)
	var p2_base_gain = _calculate_projected_momentum(2, p2_action_queue, p2_active)
	
	# 4. Final Push
	var p1_contribution = p1_base_gain
	if p2_parries: p1_contribution = 0 
	elif p1_is_dodged: p1_contribution = 0 
	
	var p2_contribution = p2_base_gain
	if p1_parries: p2_contribution = 0 
	elif p2_is_dodged: p2_contribution = 0 
	
	var p1_stolen = p2_base_gain if p1_parries else 0
	var p2_stolen = p1_base_gain if p2_parries else 0
	
	var p1_final_push = p1_contribution + p1_stolen
	var p2_final_push = p2_contribution + p2_stolen
	
	# 5. Delta Calculation
	var p1_fb = p1_action_queue.fall_back_value if p1_active else 0
	var p2_fb = p2_action_queue.fall_back_value if p2_active else 0
	
	var delta = (-p1_final_push + p1_fb) + (p2_final_push - p2_fb)
	
	# 6. Parry Success
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
	
	# --- PHASE 3: MOMENTUM ---
	var p1_is_offence = (p1_action_queue.type == ActionData.Type.OFFENCE)
	var p2_is_offence = (p2_action_queue.type == ActionData.Type.OFFENCE)
	
	if p1_active and p1_is_offence: _apply_phase_3_momentum(1, p1_action_queue, p1_final_push)
	if p2_active and p2_is_offence: _apply_phase_3_momentum(2, p2_action_queue, p2_final_push)
	
	if p1_active and not p1_is_offence: _apply_phase_3_momentum(1, p1_action_queue, p1_final_push)
	if p2_active and not p2_is_offence: _apply_phase_3_momentum(2, p2_action_queue, p2_final_push)
	
	# --- PHASE 4: STATUS TICK ---
	_handle_status_damage(winner_id, p1_started_injured, p2_started_injured)

	# --- CLEANUP ---
	if is_initial_clash:
		momentum = 4 if winner_id == 1 else 5
		emit_signal("combat_log_updated", "Initial Clash Set! Momentum: " + str(momentum))
	
	_check_reversal(winner_id, start_momentum)
	_handle_locks(winner_id)

	p1_action_queue = null
	p2_action_queue = null
	
	change_state(State.POST_CLASH)
	change_state(State.SELECTION)

# ==============================================================================
# PHASE IMPLEMENTATIONS
# ==============================================================================

func _apply_phase_1_self_effects(owner_id: int, my_card: ActionData):
	var owner = p1_data if owner_id == 1 else p2_data
	var total_hits = max(1, my_card.repeat_count)
	
	for i in range(total_hits):
		var actual_recover = my_card.recover_value
		if my_card.type == ActionData.Type.DEFENCE: actual_recover += 1
		
		if actual_recover > 0: 
			owner.current_sp = min(owner.current_sp + actual_recover, owner.max_sp)
			
		if my_card.heal_value > 0: 
			owner.current_hp = min(owner.current_hp + my_card.heal_value, owner.max_hp)

		if my_card.heal_value > 0 or my_card.fall_back_value > 0:
			if owner_id == 1 and p1_is_injured:
				p1_is_injured = false
				emit_signal("combat_log_updated", ">> P1 cures Injury!")
			elif owner_id == 2 and p2_is_injured:
				p2_is_injured = false
				emit_signal("combat_log_updated", ">> P2 cures Injury!")

func _apply_phase_2_combat_effects(owner_id: int, target_id: int, my_card: ActionData, enemy_card: ActionData, target_is_immune: bool) -> Dictionary:
	var owner = p1_data if owner_id == 1 else p2_data
	var target = p2_data if owner_id == 1 else p1_data
	var result = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	if target_is_immune:
		emit_signal("combat_log_updated", "P" + str(owner_id) + " attack NULLIFIED (Dodge/Parry)!")
		return result

	var total_hits = max(1, my_card.repeat_count)
	for i in range(total_hits):
		var enemy_block = enemy_card.block_value 
		if my_card.guard_break: enemy_block = 0
		var net_damage = max(0, my_card.damage - enemy_block)
		
		if net_damage > 0:
			target.current_hp -= net_damage
			emit_signal("combat_log_updated", "P" + str(owner_id) + " hits P" + str(target_id) + ": -" + str(net_damage) + " HP")
			
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
			emit_signal("combat_log_updated", "P" + str(owner_id) + " attack blocked.")

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

		if target.current_hp <= 0:
			result["fatal"] = true
			return result
			
		if my_card.create_opening > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " creates an Opening! (Lvl " + str(my_card.create_opening) + ")")
			result["opening"] = my_card.create_opening
		
		if my_card.opportunity > 0:
			result["opportunity"] = my_card.opportunity
			
	return result

func _apply_phase_3_momentum(owner_id: int, my_card: ActionData, effective_gain: int):
	var loss = my_card.fall_back_value 
	if owner_id == 1:
		momentum = clampi(momentum - effective_gain + loss, 1, 8)
	else:
		momentum = clampi(momentum + effective_gain - loss, 1, 8)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

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

func _handle_status_damage(winner_id, p1_started_injured: bool, p2_started_injured: bool):
	if p1_is_injured and p1_started_injured:
		p1_data.current_hp -= 1
		emit_signal("combat_log_updated", ">> P1 takes 1 damage from Injury.")
		if p1_data.current_hp <= 0: _handle_death(winner_id)

	if p2_is_injured and p2_started_injured:
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
			
			# NEW: If reversal is successful, the player seizes initiative and MUST start with an Opener
			if loser_id == 1: p1_must_opener = true
			else: p2_must_opener = true
			
			emit_signal("combat_log_updated", ">>> REVERSAL! Player " + str(loser_id) + " seizes the Combo! (Must use Opener) <<<")

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
