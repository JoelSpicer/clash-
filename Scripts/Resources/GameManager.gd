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
var momentum: int = 0 # 0 is center. Negative = P1 Adv, Positive = P2 Adv.

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
	# 1. Pay Initial Costs
	# (Note: In a real game, you'd check p1_data.current_sp here)
	print("Costs paid.")

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
	
	# B. HANDLE MULTI (PERSISTENCE)
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
	
	change_state(State.SELECTION)

func swap_priority():
	# Flips 1 to 2, and 2 to 1
	priority_player = 3 - priority_player
	print("Priority Token moved to P" + str(priority_player))
