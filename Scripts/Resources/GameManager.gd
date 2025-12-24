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

# --- NEW: PERSISTENT TURN CONSTRAINTS ---
# These track the "Opening" status from the PREVIOUS clash.
var p1_cost_limit: int = 99     # Limits P1's max cost (Default high)
var p2_cost_limit: int = 99     # Limits P2's max cost
var p1_opening_stat: int = 0    # P1's "Create Opening" value from last turn
var p2_opening_stat: int = 0    # P2's "Create Opening" value from last turn

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
	
	# Reset Constraints
	p1_cost_limit = 99
	p2_cost_limit = 99
	p1_opening_stat = 0
	p2_opening_stat = 0
	
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
	
	# --- RESET NEXT TURN CONSTRAINTS ---
	# We start fresh for the next turn, assuming no constraints unless a card adds them.
	var next_p1_limit = 99
	var next_p2_limit = 99
	var next_p1_opening = 0
	var next_p2_opening = 0
	
	# 2. EXECUTE BOTH CARDS
	# We pass the constraint containers to process_card_effects so they can fill them.
	var p1_results = process_card_effects(1, 2, p1_action_queue, p2_action_queue, is_initial_clash, p1_is_free)
	var p2_results = process_card_effects(2, 1, p2_action_queue, p1_action_queue, is_initial_clash, p2_is_free)
	
	var p1_fatal = p1_results["fatal"]
	var p2_fatal = p2_results["fatal"]
	
	# Update Constraints based on results (Create Opening)
	if p1_results["opening"] > 0:
		next_p2_limit = p1_results["opening"] # Opponent constrained
		next_p1_opening = p1_results["opening"] # My Counter stat
	
	if p2_results["opening"] > 0:
		next_p1_limit = p2_results["opening"]
		next_p2_opening = p2_results["opening"]
		
	# Apply to Globals
	p1_cost_limit = next_p1_limit
	p2_cost_limit = next_p2_limit
	p1_opening_stat = next_p1_opening
	p2_opening_stat = next_p2_opening
	
	# 3. CHECK FOR DEATH
	if p1_fatal or p2_fatal:
		var game_winner = 0
		if p1_data.current_hp > 0: game_winner = 1
		elif p2_data.current_hp > 0: game_winner = 2
		else: game_winner = winner_id 
		emit_signal("game_over", game_winner)
		reset_combat() 
		return 
	
	# 4. INITIAL CLASH SNAP
	if is_initial_clash:
		momentum = 4 if winner_id == 1 else 5
		emit_signal("combat_log_updated", "Initial Clash Set! Momentum: " + str(momentum))
	
	# 5. REVERSAL / INITIATIVE CHECK
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

	# 6. MULTI / LOCK LOGIC
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

# Updated to return Dictionary so we can pass back Opening stats
func process_card_effects(owner_id: int, target_id: int, my_card: ActionData, enemy_card: ActionData, ignore_momentum: bool = false, is_free: bool = false) -> Dictionary:
	var owner = p1_data if owner_id == 1 else p2_data
	var target = p2_data if owner_id == 1 else p1_data
	var result = { "fatal": false, "opening": 0 }
	
	# 1. Pay Costs
	var effective_cost = my_card.cost
	if is_free:
		effective_cost = 0
		emit_signal("combat_log_updated", "P" + str(owner_id) + " locked by Multi: Action is FREE.")

	if owner.current_sp >= effective_cost:
		owner.current_sp -= effective_cost
	else:
		emit_signal("combat_log_updated", ">> P" + str(owner_id) + " Out of SP! Action Fails!")
		return result
	
	var total_hits = max(1, my_card.repeat_count)
	
	for i in range(total_hits):
		var block_amt = enemy_card.block_value + enemy_card.dodge_value
		if my_card.guard_break: block_amt = 0
		var net_damage = max(0, my_card.damage - block_amt)
		
		if net_damage > 0:
			target.current_hp -= net_damage
			emit_signal("combat_log_updated", "P" + str(owner_id) + " hits P" + str(target_id) + ": -" + str(net_damage) + " HP")
		elif my_card.damage > 0:
			emit_signal("combat_log_updated", "P" + str(owner_id) + " attack blocked/dodged.")

		if target.current_hp <= 0:
			emit_signal("combat_log_updated", ">> FATAL HIT on P" + str(target_id) + "! <<")
			result["fatal"] = true
			return result

		if my_card.recover_value > 0: 
			owner.current_sp = min(owner.current_sp + my_card.recover_value, owner.max_sp)
		if my_card.heal_value > 0: 
			owner.current_hp = min(owner.current_hp + my_card.heal_value, owner.max_hp)

		if not ignore_momentum:
			var gain = my_card.momentum_gain
			var loss = my_card.fall_back_value 
			if owner_id == 1:
				momentum = clampi(momentum - gain + loss, 1, 8)
			else:
				momentum = clampi(momentum + gain - loss, 1, 8)
				
	# --- NEW: Check for Create Opening ---
	# We pass this back to resolve_clash to set next turn's variables
	if my_card.create_opening > 0:
		emit_signal("combat_log_updated", "P" + str(owner_id) + " creates an Opening! (Lvl " + str(my_card.create_opening) + ")")
		result["opening"] = my_card.create_opening
		
	return result

func swap_priority():
	priority_player = 3 - priority_player
