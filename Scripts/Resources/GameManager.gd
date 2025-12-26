extends Node

# Signals
signal state_changed(new_state)
signal clash_resolved(winner_id, log_text)
signal feint_triggered(player_id)
signal combat_log_updated(text)
signal game_over(winner_id)

# State Machine
enum State { SETUP, SELECTION, REVEAL, FEINT_CHECK, RESOLUTION, POST_CLASH, GAME_OVER }
var current_state = State.SETUP

# Data
var p1_data: CharacterData
var p2_data: CharacterData
var priority_player: int = 1 
var momentum: int = 0 
var current_combo_attacker: int = 0

# --- PERSISTENT TURN CONSTRAINTS ---
var p1_cost_limit: int = 99     
var p2_cost_limit: int = 99     
var p1_opening_stat: int = 0    
var p2_opening_stat: int = 0
var p1_opportunity_stat: int = 0
var p2_opportunity_stat: int = 0

# NEW: Forced Opener Constraint (from being Parried)
var p1_must_opener: bool = false
var p2_must_opener: bool = false

# --- STATUS EFFECTS ---
var p1_is_injured: bool = false
var p2_is_injured: bool = false

var p1_action_queue: ActionData
var p2_action_queue: ActionData
var p1_locked_card: ActionData = null
var p2_locked_card: ActionData = null

# --- INITIALIZATION ---

func start_combat(p1: CharacterData, p2: CharacterData):
	p1_data = p1
	p2_data = p2
	reset_combat()

func reset_combat():
	p1_data.reset_stats()
	p2_data.reset_stats()
	momentum = 0 
	current_combo_attacker = 0
	p1_locked_card = null
	p2_locked_card = null
	
	p1_cost_limit = 99
	p2_cost_limit = 99
	p1_opening_stat = 0
	p2_opening_stat = 0
	p1_opportunity_stat = 0
	p2_opportunity_stat = 0
	p1_must_opener = false
	p2_must_opener = false
	
	p1_is_injured = false
	p2_is_injured = false
	
	if p1_data.speed > p2_data.speed: priority_player = 1
	elif p2_data.speed > p1_data.speed: priority_player = 2
	else: priority_player = randi_range(1, 2)
		
	print("\n>>> COMBAT RESET! Starting from Initial Clash (Neutral) <<<")
	change_state(State.SELECTION)

# --- PUBLIC HELPER ---

func get_attacker() -> int:
	if current_combo_attacker != 0: return current_combo_attacker
	if momentum == 0: return 0 
	if momentum <= 4: return 1 
	return 2 

# --- STATE MACHINE ---

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

# --- INPUT ---

func player_select_action(player_id: int, action: ActionData):
	if current_state != State.SELECTION and current_state != State.FEINT_CHECK: return
	if player_id == 1: p1_action_queue = action
	else: p2_action_queue = action
	
	if current_state == State.SELECTION and p1_action_queue and p2_action_queue:
		change_state(State.REVEAL)

# --- LOGIC ---

func _enter_reveal_phase():
	emit_signal("combat_log_updated", "REVEAL: P1 chose " + p1_action_queue.display_name + " | P2 chose " + p2_action_queue.display_name)
	var p1_feinting = p1_action_queue.feint
	var p2_feinting = p2_action_queue.feint

	if p1_feinting or p2_feinting:
		change_state(State.FEINT_CHECK)
		if p1_feinting: emit_signal("feint_triggered", 1)
		if p2_feinting: emit_signal("feint_triggered", 2)
	else:
		change_state(State.RESOLUTION)

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
	var p1_is_free = (p1_locked_card != null)
	var p2_is_free = (p2_locked_card != null)
	
	var p1_started_injured = p1_is_injured
	var p2_started_injured = p2_is_injured
	
	# --- PHASE 0: PAY COSTS ---
	var p1_active = _pay_cost(1, p1_action_queue, p1_is_free, p1_opportunity_stat)
	var p2_active = _pay_cost(2, p2_action_queue, p2_is_free, p2_opportunity_stat)

	if p1_active and p1_action_queue.is_super:
		p1_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P1 unleashes their Ultimate Art!")
	if p2_active and p2_action_queue.is_super:
		p2_data.has_used_super = true
		emit_signal("combat_log_updated", ">> P2 unleashes their Ultimate Art!")

	# --- PHASE 1: SELF EFFECTS (Recover/Heal) ---
	# Args: (owner, target, my, enemy, ignore, override, use_fixed, self, combat, momentum, immune)
	if p1_active: process_card_effects(1, 2, p1_action_queue, p2_action_queue, is_initial_clash, 0, false, true, false, false, false)
	if p2_active: process_card_effects(2, 1, p2_action_queue, p1_action_queue, is_initial_clash, 0, false, true, false, false, false)

	# --- PARRY PRE-CALCULATION ---
	
	# 1. Base Momentum Gains (including Opportunity)
	var p1_base_gain = (p1_action_queue.momentum_gain + p1_opportunity_stat) if p1_active else 0
	var p2_base_gain = (p2_action_queue.momentum_gain + p2_opportunity_stat) if p2_active else 0
	var p1_fb = p1_action_queue.fall_back_value if p1_active else 0
	var p2_fb = p2_action_queue.fall_back_value if p2_active else 0
	
	# 2. Determine "Effective" Gains (Parry Steal)
	var p1_eff_gain = p1_base_gain
	var p2_eff_gain = p2_base_gain
	var p1_parrying = (p1_active and p1_action_queue.is_parry)
	var p2_parrying = (p2_active and p2_action_queue.is_parry)
	
	if p1_parrying: p1_eff_gain += p2_base_gain
	if p2_parrying: p2_eff_gain += p1_base_gain
	
	if p1_parrying and not p2_parrying: p2_eff_gain = 0
	if p2_parrying and not p1_parrying: p1_eff_gain = 0
	
	# 3. Calculate Projected Delta
	var delta = -p1_eff_gain + p1_fb + p2_eff_gain - p2_fb
	
	# 4. Check Success
	var p1_parry_win = false
	var p2_parry_win = false
	
	if p1_parrying and delta < 0: # Net movement Left (P1 Direction)
		p1_parry_win = true
		emit_signal("combat_log_updated", ">>> P1 PARRIES! (Momentum Stolen & Immunity)")
		
	if p2_parrying and delta > 0: # Net movement Right (P2 Direction)
		p2_parry_win = true
		emit_signal("combat_log_updated", ">>> P2 PARRIES! (Momentum Stolen & Immunity)")

	# --- PHASE 2: COMBAT EFFECTS (Damage/Injure/Retaliate) ---
	var p1_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	var p2_results = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	# Note: 'is_immune' arg applies to the TARGET of the effect.
	# If P2 won parry, P1's attack on P2 should fail (P2 is immune).
	var p2_is_immune = p2_parry_win 
	var p1_is_immune = p1_parry_win
	
	# Args: (..., override, use_fixed, self, combat, momentum, immune)
	if p1_active: p1_results = process_card_effects(1, 2, p1_action_queue, p2_action_queue, is_initial_clash, 0, false, false, true, false, p2_is_immune)
	if p2_active: p2_results = process_card_effects(2, 1, p2_action_queue, p1_action_queue, is_initial_clash, 0, false, false, true, false, p1_is_immune)
	
	_update_turn_constraints(p1_results, p2_results, p1_action_queue, p2_action_queue, p1_parry_win, p2_parry_win)
	
	if p1_results["fatal"] or p2_results["fatal"]:
		_handle_death(winner_id)
		return 
	
	# --- PHASE 3: MOMENTUM (With Stolen Values) ---
	var p1_is_offence = (p1_action_queue.type == ActionData.Type.OFFENCE)
	var p2_is_offence = (p2_action_queue.type == ActionData.Type.OFFENCE)
	
	# Args: (..., override, use_fixed, self, combat, momentum, immune)
	# IMPORTANT: 'do_momentum' is TRUE here. 'use_fixed' is TRUE.
	
	if p1_active and p1_is_offence: process_card_effects(1, 2, p1_action_queue, p2_action_queue, is_initial_clash, p1_eff_gain, true, false, false, true, false)
	if p2_active and p2_is_offence: process_card_effects(2, 1, p2_action_queue, p1_action_queue, is_initial_clash, p2_eff_gain, true, false, false, true, false)
	
	if p1_active and not p1_is_offence: process_card_effects(1, 2, p1_action_queue, p2_action_queue, is_initial_clash, p1_eff_gain, true, false, false, true, false)
	if p2_active and not p2_is_offence: process_card_effects(2, 1, p2_action_queue, p1_action_queue, is_initial_clash, p2_eff_gain, true, false, false, true, false)
	
	# --- PHASE 4: STATUS TICK ---
	if p1_started_injured and p1_is_injured:
		p1_data.current_hp -= 1
		emit_signal("combat_log_updated", ">> P1 takes 1 damage from Injury.")
		if p1_data.current_hp <= 0:
			_handle_death(winner_id)
			return

	if p2_started_injured and p2_is_injured:
		p2_data.current_hp -= 1
		emit_signal("combat_log_updated", ">> P2 takes 1 damage from Injury.")
		if p2_data.current_hp <= 0:
			_handle_death(winner_id)
			return

	# --- END OF RESOLUTION ---
	
	if is_initial_clash:
		momentum = 4 if winner_id == 1 else 5
		emit_signal("combat_log_updated", "Initial Clash Set! Momentum: " + str(momentum))
	
	_check_reversal(winner_id, start_momentum)
	_handle_locks(winner_id)

	p1_action_queue = null
	p2_action_queue = null
	
	change_state(State.POST_CLASH)
	change_state(State.SELECTION)

# --- HELPER FUNCTIONS ---

func _pay_cost(player_id: int, card: ActionData, is_free: bool, opportunity_val: int) -> bool:
	var character = p1_data if player_id == 1 else p2_data
	var raw_cost = card.cost
	var effective_cost = max(0, raw_cost - opportunity_val)
	
	if is_free: 
		effective_cost = 0
		emit_signal("combat_log_updated", "P" + str(player_id) + " locked by Multi: Action is FREE.")
	
	if character.current_sp >= effective_cost:
		character.current_sp -= effective_cost
		return true
	else:
		emit_signal("combat_log_updated", ">> P" + str(player_id) + " Out of SP! Action Fails!")
		return false

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

func _update_turn_constraints(p1_res, p2_res, p1_card, p2_card, p1_parry_win: bool = false, p2_parry_win: bool = false):
	var next_p1_limit = 99
	var next_p2_limit = 99
	var next_p1_opening = 0
	var next_p2_opening = 0
	
	# Reset Forced Opener defaults
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
		
	# NEW: Apply Forced Opener if Parried
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

# --- CORE LOGIC ---
# Signature has exactly 11 Arguments.
func process_card_effects(
	owner_id: int, 
	target_id: int, 
	my_card: ActionData, 
	enemy_card: ActionData, 
	ignore_momentum: bool, 
	momentum_override: int, 
	use_fixed_momentum: bool, 
	do_self: bool, 
	do_combat: bool, 
	do_momentum: bool,
	is_immune: bool = false
) -> Dictionary:
	
	var owner = p1_data if owner_id == 1 else p2_data
	var target = p2_data if owner_id == 1 else p1_data
	var result = { "fatal": false, "opening": 0, "opportunity": 0 }
	
	var total_hits = max(1, my_card.repeat_count)
	for i in range(total_hits):
		
		# --- PHASE 1: SELF ---
		if do_self:
			if my_card.recover_value > 0: 
				owner.current_sp = min(owner.current_sp + my_card.recover_value, owner.max_sp)
			if my_card.heal_value > 0: 
				owner.current_hp = min(owner.current_hp + my_card.heal_value, owner.max_hp)

			if my_card.heal_value > 0 or my_card.fall_back_value > 0:
				if owner_id == 1 and p1_is_injured:
					p1_is_injured = false
					emit_signal("combat_log_updated", ">> P1 cures Injury!")
				elif owner_id == 2 and p2_is_injured:
					p2_is_injured = false
					emit_signal("combat_log_updated", ">> P2 cures Injury!")

		# --- PHASE 2: COMBAT ---
		if do_combat:
			# IMMUNITY CHECK (PARRY)
			# 'is_immune' means "Target is immune".
			if is_immune:
				emit_signal("combat_log_updated", "P" + str(owner_id) + " attack PARRIED/NULLIFIED!")
				return result
			
			var enemy_block = enemy_card.block_value + enemy_card.dodge_value
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
				emit_signal("combat_log_updated", "P" + str(owner_id) + " attack blocked/dodged.")

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

		# --- PHASE 3: MOMENTUM ---
		if do_momentum and not ignore_momentum:
			var actual_gain = 0
			
			if use_fixed_momentum:
				actual_gain = momentum_override
			else:
				actual_gain = my_card.momentum_gain + momentum_override # override is opp_val
			
			var loss = my_card.fall_back_value 
			if owner_id == 1:
				momentum = clampi(momentum - actual_gain + loss, 1, 8)
			else:
				momentum = clampi(momentum + actual_gain - loss, 1, 8)
				
	return result
	
func swap_priority():
	priority_player = 3 - priority_player
