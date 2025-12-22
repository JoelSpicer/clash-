extends Node2D

@export var p1_resource: CharacterData
@export var p2_resource: CharacterData

# Config for visualizer
const D8_TRACK_SIZE = 8

func _ready():
	await get_tree().process_frame
	
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.combat_log_updated.connect(_on_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved)
	
	print("--- INITIALIZING SIMULATION ---")
	GameManager.start_combat(p1_resource, p2_resource)

func _on_state_changed(new_state):
	match new_state:
		GameManager.State.SELECTION:
			# Start of a new turn
			print("\n==============================================")
			print("               NEW TURN START")
			print("==============================================")
			print("[PHASE] Selection (Bots are thinking...)")
			_simulate_turn()
			
		GameManager.State.FEINT_CHECK:
			print("[PHASE] Feint Triggered! (Selecting follow-up...)")
			_simulate_turn()
			
		GameManager.State.POST_CLASH:
			# End of turn - This runs AFTER all damage/costs are calculated
			_print_end_of_turn_report()

func _simulate_turn():
	# Small delay so the log doesn't print instantly
	await get_tree().create_timer(0.5).timeout
	
	var mom = GameManager.momentum
	
	# --- AI LOGIC (d8 Scale) ---
	# 0 = Neutral (Start)
	# 1-4 = P1 Advantage | 5-8 = P2 Advantage
	
	var p1_is_attacker = false
	var p2_is_attacker = false
	var is_neutral = (mom == 0)
	
	if not is_neutral:
		if mom <= 4:
			p1_is_attacker = true
		else:
			p2_is_attacker = true
	
	# Filter Logic
	var p1_filter = null
	if not is_neutral:
		p1_filter = ActionData.Type.OFFENCE if p1_is_attacker else ActionData.Type.DEFENCE
		
	var p2_filter = null
	if not is_neutral:
		p2_filter = ActionData.Type.OFFENCE if p2_is_attacker else ActionData.Type.DEFENCE
	
	# Pick Cards
	var p1_card = _get_valid_card(p1_resource, p1_filter)
	var p2_card = _get_valid_card(p2_resource, p2_filter)
	
	# Log the choice slightly before the resolution for clarity
	print("[INPUT] P1 Chose: " + p1_card.display_name)
	print("[INPUT] P2 Chose: " + p2_card.display_name)
	
	GameManager.player_select_action(1, p1_card)
	GameManager.player_select_action(2, p2_card)

func _get_valid_card(character: CharacterData, type_filter) -> ActionData:
	var valid_options = []
	for card in character.deck:
		if card.cost > character.current_sp: continue
		if type_filter != null and card.type != type_filter: continue
		valid_options.append(card)
	
	if valid_options.size() > 0:
		return valid_options.pick_random()
	else:
		# Fallback to any affordable card
		for card in character.deck:
			if card.cost == 0: return card
		return character.deck[0]

func _on_clash_resolved(winner_id, _log_text):
	# This triggers BEFORE execution, so we just announce the winner here
	print("\n>>> CLASH WINNER: Player " + str(winner_id) + " <<<")
	print("    Resolving Effects...")

func _on_log_updated(text):
	# Indent combat logs to make them look distinct from phase headers
	print("    > " + text)

func _print_end_of_turn_report():
	var p1 = p1_resource
	var p2 = p2_resource
	var mom = GameManager.momentum
	
	print("\n--- TURN STATUS REPORT ---")
	print("   [P1] " + p1.character_name + ": " + str(p1.current_hp) + " HP | " + str(p1.current_sp) + " SP")
	print("   [P2] " + p2.character_name + ": " + str(p2.current_hp) + " HP | " + str(p2.current_sp) + " SP")
	
	# Momentum Visualizer [ 1 2 3 4 | 5 6 7 8 ]
	var visual = "[ "
	# P1 Side
	for i in range(1, 5):
		visual += "P1 " if mom == i else str(i) + "  "
	visual += "| "
	# P2 Side
	for i in range(5, 9):
		visual += "P2 " if mom == i else str(i) + "  "
	visual += "]"
	
	print("   MOMENTUM: " + visual)
	
	var status_text = "NEUTRAL"
	if mom != 0:
		status_text = "P1 ADVANTAGE" if mom <= 4 else "P2 ADVANTAGE"
	print("   CONTROL: " + status_text)
	print("==============================================\n")
