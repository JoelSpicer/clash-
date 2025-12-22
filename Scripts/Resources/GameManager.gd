extends Node

# Signals for the UI to listen to
signal state_changed(new_state)
signal clash_resolved(winner_id, log_text)
signal feint_triggered(player_id) # Tells UI to open the Feint menu
signal combat_log_updated(text)

# The State Machine
enum State {
	SETUP,
	SELECTION,      # Waiting for players to pick cards
	REVEAL,         # Cards revealed, costs paid
	FEINT_CHECK,    # Pause for Feint input
	RESOLUTION,     # Math and Damage
	POST_CLASH,     # Cleanup and Multi check
	GAME_OVER
}

var current_state = State.SETUP

# Combat Data
var p1_data: CharacterData
var p2_data: CharacterData

# Turn Logic variables
var priority_player: int = 1 # 1 or 2

# MOMENTUM TRACKER (d8 Logic)
# 0 = Initial Neutral State (Special)
# 1-4 = Player 1 Territory (1 is Max P1, 4 is Weak P1)
# 5-8 = Player 2 Territory (5 is Weak P2, 8 is Max P2)
var momentum: int = 0 

# Action Queues (The cards currently being played)
var p1_action_queue: ActionData
var p2_action_queue: ActionData

# Multi Logic (Persistence)
var p1_locked_card: ActionData = null # If not null, P1 MUST play this next turn
var p2_locked_card: ActionData = null

# --- INITIALIZATION ---

func start_combat(p1: CharacterData, p2: CharacterData):
	p1_data = p1
	p2_data = p2
	
	# NEW: Reset HP and SP to full at start of fight
	p1_data.reset_stats()
	p2_data.reset_stats()
	
	momentum = 0 # Start in the special neutral state
	
	# Rule: Priority goes to the higher Speed
	if p1.speed > p2.speed:
		priority_player = 1
	elif p2.speed > p1.speed:
		priority_player = 2
	else:
		priority_player = randi_range(1, 2) # Coin flip if equal
		
	print("Combat Started! Priority Token: P" + str(priority_player))
	change_state(State.SELECTION)

# --- STATE MACHINE ---

func change_state(new_state: State):
	current_state = new_state
	emit_signal("state_changed", current_state)
	
	match current_state:
		State.SELECTION:
			print("--- SELECTION PHASE ---")
			# If a player is locked by Multi, auto-select their card
			if p1_locked_card:
				print("P1 is locked into: " + p1_locked_card.display_name)
				player_select_action(1, p1_locked_card)
			if p2_locked_card:
				print("P2 is locked into: " + p2_locked_card.display_name)
				player_select_action(2, p2_locked_card)
				
		State.REVEAL:
			print("--- REVEAL PHASE ---")
			_enter_reveal_phase()
			
		State.FEINT_CHECK:
			print("--- FEINT CHECK ---")
			# Logic handled in _enter_reveal_phase
			
		State.RESOLUTION:
			print("--- RESOLUTION ---")
			resolve_clash()

# --- INPUT HANDLING ---

func player_select_action(player_id: int, action: ActionData):
	# Only allow input if we are in the right phase
	if current_state != State.SELECTION and current_state != State.FEINT_CHECK:
		return

	# Store the choice
	if player_id == 1:
		p1_action_queue = action
	else:
		p2_action_queue = action
	
	print("P" + str(player_id) + " selected: " + action.display_name)
	
	# If both have picked (and we are not pausing for Feint), move on
	if current_state == State.SELECTION and p1_action_queue and p2_action_queue:
		change_state(State.REVEAL)
		
	# If we are in Feint phase, we handle re-submission differently (later step)

# --- PHASE LOGIC ---

func _enter_reveal_phase():
	# 1. Pay Initial Costs (Costs paid on reveal)
	print("Cards Revealed.")

	# 2. Check for Feint Trait
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
	
	# A. DETERMINE WINNER
	
	# 1. Type Advantage (Offence > Defence)
	if p1_action_queue.type == ActionData.Type.OFFENCE and p2_action_queue.type == ActionData.Type.DEFENCE:
		winner_id = 1
	elif p2_action_queue.type == ActionData.Type.OFFENCE and p1_action_queue.type == ActionData.Type.DEFENCE:
		winner_id = 2
	
	# 2. Stamina Advantage (Lower Cost wins)
	elif p1_action_queue.cost < p2_action_queue.cost:
		winner_id = 1
	elif p2_action_queue.cost < p1_action_queue.cost:
		winner_id = 2
		
	# 3. Priority Token Tiebreaker
	else:
		print("Tie detected! Priority Token used by P" + str(priority_player))
		winner_id = priority_player
		swap_priority() # Token MUST swap after use

	emit_signal("clash_resolved", winner_id, "Winner is P" + str(winner_id))
	
	# CHECK FOR INITIAL CLASH (d8 Logic: if 0, we are at start)
	var is_initial_clash = (momentum == 0)
	
	# B. EXECUTE ATTACKS
	# We pass 'is_initial_clash' to tell the logic to skip normal momentum math
	if winner_id == 1:
		execute_attack(1, 2, p1_action_queue, p2_action_queue, is_initial_clash)
	else:
		execute_attack(2, 1, p2_action_queue, p1_action_queue, is_initial_clash)
	
	# C. HANDLE INITIAL CLASH SNAP (Rule Page 5)
	# If we were at 0, we snap to the starting position based on winner.
	if is_initial_clash:
		if winner_id == 1:
			momentum = 4 # P1 starts at their "Weakest Advantage" (closest to center)
		else:
			momentum = 5 # P2 starts at their "Weakest Advantage" (closest to center)
		print("Initial Clash Resolved: Momentum snapped to " + str(momentum))

	
	# D. HANDLE MULTI (PERSISTENCE)
	p1_locked_card = null
	p2_locked_card = null
	
	var winner_card = p1_action_queue if winner_id == 1 else p2_action_queue
	var loser_card = p2_action_queue if winner_id == 1 else p1_action_queue
	
	# If winner used Multi, the loser is locked next turn
	if winner_card.multi_limit > 0:
		print("Multi Triggered! Loser is locked next turn.")
		if winner_id == 1:
			p2_locked_card = loser_card
		else:
			p1_locked_card = loser_card

	# Cleanup for next turn
	p1_action_queue = null
	p2_action_queue = null
	
	change_state(State.POST_CLASH)
	change_state(State.SELECTION)

func execute_attack(attacker_id: int, _defender_id: int, attack_card: ActionData, defense_card: ActionData, ignore_momentum: bool = false):
	var attacker = p1_data if attacker_id == 1 else p2_data
	var defender = p2_data if attacker_id == 1 else p1_data
	
	print("--- Executing: " + attack_card.display_name + " ---")
	
	# REPEAT LOGIC
	# Ensure loop runs at least once even if Repeat is 0
	var total_hits = max(1, attack_card.repeat_count)
	
	for i in range(total_hits):
		
		# 1. Check & Pay Stamina
		if attacker.current_sp >= attack_card.cost:
			attacker.current_sp -= attack_card.cost
			emit_signal("combat_log_updated", "Hit " + str(i+1) + ": Paid " + str(attack_card.cost) + " SP")
		else:
			emit_signal("combat_log_updated", "Not enough SP for repeat! Combo ends.")
			break 
			
		# 2. Calculate Block
		var block_amt = defense_card.block_value
		if attack_card.guard_break:
			block_amt = 0
			emit_signal("combat_log_updated", "Guard Break! Block ignored.")
			
		# 3. Calculate Net Damage
		var net_damage = attack_card.damage - block_amt
		if net_damage < 0: net_damage = 0
		
		# 4. Apply Damage
		if net_damage > 0:
			defender.current_hp -= net_damage
			emit_signal("combat_log_updated", "Dealt " + str(net_damage) + " Damage. (HP: " + str(defender.current_hp) + ")")
		else:
			emit_signal("combat_log_updated", "Blocked.")
			
		# 5. Apply Self-Healing & Recovery
		if attack_card.recover_value > 0:
			attacker.current_sp = min(attacker.current_sp + attack_card.recover_value, attacker.max_sp)
			emit_signal("combat_log_updated", "Recovered " + str(attack_card.recover_value) + " SP.")
			
		if attack_card.heal_value > 0:
			attacker.current_hp = min(attacker.current_hp + attack_card.heal_value, attacker.max_hp)
			emit_signal("combat_log_updated", "Healed " + str(attack_card.heal_value) + " HP.")

		# 6. Apply Status Effects
		if attack_card.injure:
			print("Applied Injure status!")
			
		# 7. Apply Momentum (d8 Scale 1-8)
		# Skip this math if it is the Initial Clash (flag set in resolve_clash)
		if not ignore_momentum:
			var gain = attack_card.momentum_gain
			var loss = attack_card.fall_back_value 
			
			if attacker_id == 1:
				# P1 wants to reach 1. 
				# Gain moves DOWN (towards 1). Loss (Fall Back) moves UP (towards 8).
				momentum -= gain 
				momentum += loss 
			else:
				# P2 wants to reach 8. 
				# Gain moves UP (towards 8). Loss (Fall Back) moves DOWN (towards 1).
				momentum += gain 
				momentum -= loss
			
			# Clamp to 1-8 Range (Tabletop Logic)
			# Even if P1 has huge momentum, they can't go below 1.
			momentum = clampi(momentum, 1, 8)
		else:
			emit_signal("combat_log_updated", "Momentum gain ignored (Initial Clash rule).")

func swap_priority():
	# Flips 1 to 2, and 2 to 1
	priority_player = 3 - priority_player
	print("Priority Token moved to P" + str(priority_player))
