extends Node

# Signals
signal state_changed(new_state)
signal clash_resolved(winner_id, log_text)
signal feint_triggered(player_id)
signal combat_log_updated(text)
signal game_over(winner_id)

# State Machine
enum State {
	SETUP,
	SELECTION,
	REVEAL,
	FEINT_CHECK,
	RESOLUTION,
	POST_CLASH,
	GAME_OVER
}

var current_state = State.SETUP

# Data
var p1_data: CharacterData
var p2_data: CharacterData
var priority_player: int = 1 

# MOMENTUM (d8 Scale: 0=Neutral, 1-4=P1, 5-8=P2)
var momentum: int = 0 

# REVERSAL / INITIATIVE LOGIC
# If this is non-zero, this player HAS INITIATIVE (is Attacker) regardless of momentum.
# This persists until the Combo Ends (Out of SP or voluntarily stopping).
var current_combo_attacker: int = 0

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
	
	if p1_data.speed > p2_data.speed: priority_player = 1
	elif p2_data.speed > p1_data.speed: priority_player = 2
	else: priority_player = randi_range(1, 2)
		
	print("\n>>> COMBAT RESET! Starting from Initial Clash (Neutral) <<<")
	change_state(State.SELECTION)

# --- PUBLIC HELPER ---

func get_attacker() -> int:
	# 1. If someone is mid-combo (via Reversal or just winning), they keep attack
	if current_combo_attacker != 0:
		return current_combo_attacker
		
	# 2. Otherwise, check Momentum
	if momentum == 0: return 0 # Neutral
	if momentum <= 4: return 1 # P1 has Advantage
	return 2 # P2 has Advantage

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
	
	# Determine Winner
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
	var start_momentum = momentum # Snapshot for Reversal check
	var fight_ended = false
	
	# Execute
	if winner_id == 1:
		fight_ended = execute_attack(1, 2, p1_action_queue, p2_action_queue, is_initial_clash)
	else:
		fight_ended = execute_attack(2, 1, p2_action_queue, p1_action_queue, is_initial_clash)
	
	if fight_ended:
		emit_signal("game_over", winner_id)
		reset_combat() 
		return 
	
	# Initial Snap
	if is_initial_clash:
		momentum = 4 if winner_id == 1 else 5
		emit_signal("combat_log_updated", "Initial Clash Set! Momentum: " + str(momentum))
	
	# --- REVERSAL / INITIATIVE CHECK ---
	var loser_id = 3 - winner_id
	var loser_card = p1_action_queue if loser_id == 1 else p2_action_queue
	
	# Check 1: Did a Reversal happen?
	var reversal_triggered = false
	if loser_card.reversal:
		var moved_closer = false
		if loser_id == 1 and momentum < start_momentum: moved_closer = true
		if loser_id == 2 and momentum > start_momentum: moved_closer = true
		
		if moved_closer:
			current_combo_attacker = loser_id # Force Initiative Swap
			reversal_triggered = true
			emit_signal("combat_log_updated", ">>> REVERSAL! Player " + str(loser_id) + " seizes the Combo! <<<")

	# Check 2: Combo Maintenance (End of Turn Check)
	# If we are in a combo (someone is attacking), can they afford to keep going?
	
	var active_attacker = get_attacker()
	if active_attacker != 0:
		var att_data = p1_data if active_attacker == 1 else p2_data
		
		# If Out of SP, Combo Breaks.
		if att_data.current_sp <= 0:
			emit_signal("combat_log_updated", ">> Attacker Out of SP. Combo Ends.")
			current_combo_attacker = 0 # Reset override
		else:
			# If we didn't just Reversal, keep the combo going normally
			if not reversal_triggered:
				current_combo_attacker = active_attacker

	# Multi Logic
	p1_locked_card = null
	p2_locked_card = null
	var winner_card = p1_action_queue if winner_id == 1 else p2_action_queue
	var loser_card_obj = p2_action_queue if winner_id == 1 else p1_action_queue 
	
	if winner_card.multi_limit > 0:
		emit_signal("combat_log_updated", "Multi Triggered! Loser Locked.")
		if winner_id == 1: p2_locked_card = loser_card_obj
		else: p1_locked_card = loser_card_obj

	p1_action_queue = null
	p2_action_queue = null
	
	change_state(State.POST_CLASH)
	change_state(State.SELECTION)

func execute_attack(attacker_id: int, _defender_id: int, attack_card: ActionData, defense_card: ActionData, ignore_momentum: bool = false) -> bool:
	var attacker = p1_data if attacker_id == 1 else p2_data
	var defender = p2_data if attacker_id == 1 else p1_data
	
	# DEFENDER PAYS COSTS
	var defender_paid = false
	if defender.current_sp >= defense_card.cost:
		defender.current_sp -= defense_card.cost
		defender_paid = true
		if defense_card.cost > 0: emit_signal("combat_log_updated", "Defender paid " + str(defense_card.cost) + " SP.")
	else:
		emit_signal("combat_log_updated", ">> Defender Out of Stamina! Defence Fails! <<")
	
	var total_hits = max(1, attack_card.repeat_count)
	
	for i in range(total_hits):
		if attacker.current_sp >= attack_card.cost:
			attacker.current_sp -= attack_card.cost
		else:
			emit_signal("combat_log_updated", ">> Attacker Out of Stamina! Combo ends.")
			# Note: The Loop breaks here, and the Combo Check in resolve_clash will see 0 SP and end the turn sequence.
			break 
		
		var block_amt = 0
		if defender_paid: block_amt = defense_card.block_value + defense_card.dodge_value
		if attack_card.guard_break: block_amt = 0
		var net_damage = max(0, attack_card.damage - block_amt)
		
		if net_damage > 0:
			defender.current_hp -= net_damage
			emit_signal("combat_log_updated", "Hit " + str(i+1) + ": -" + str(net_damage) + " HP")
		else:
			emit_signal("combat_log_updated", "Hit " + str(i+1) + ": Blocked/Dodged")

		if defender.current_hp <= 0:
			emit_signal("combat_log_updated", ">> FATAL HIT! Player " + str(3-attacker_id) + " Defeated! <<")
			return true 

		if attack_card.recover_value > 0: attacker.current_sp = min(attacker.current_sp + attack_card.recover_value, attacker.max_sp)
		if attack_card.heal_value > 0: attacker.current_hp = min(attacker.current_hp + attack_card.heal_value, attacker.max_hp)

		if not ignore_momentum:
			var atk_gain = attack_card.momentum_gain
			var atk_loss = attack_card.fall_back_value 
			var def_loss = 0
			if defender_paid: def_loss = defense_card.fall_back_value
			
			if attacker_id == 1:
				momentum = clampi(momentum - atk_gain + atk_loss - def_loss, 1, 8)
			else:
				momentum = clampi(momentum + atk_gain - atk_loss + def_loss, 1, 8)
	
	return false 

func swap_priority():
	priority_player = 3 - priority_player
