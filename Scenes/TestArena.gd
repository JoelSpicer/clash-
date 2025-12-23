extends Node2D

@export var p1_resource: CharacterData
@export var p2_resource: CharacterData

@onready var battle_ui = $BattleUI

# --- NEW: TOGGLE SWITCH ---
# Check this box in the Inspector to stop the loop when someone dies.
@export var stop_on_game_over: bool = true 

var _simulation_active: bool = true

func _ready():
	await get_tree().process_frame
	
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.combat_log_updated.connect(_on_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved)
	GameManager.game_over.connect(_on_game_over)
	
	print("--- INITIALIZING SIMULATION ---")
	GameManager.start_combat(p1_resource, p2_resource)
	
	# Initialize UI for Player 1
	battle_ui.load_deck(p1_resource.deck)

func _on_state_changed(new_state):
	# SAFETY CHECK: If simulation is stopped, ignore state changes
	if not _simulation_active:
		return

	match new_state:
		GameManager.State.SELECTION:
			print("\n| --- NEW TURN (Bot Selection) --- |")
			_simulate_turn()
		GameManager.State.FEINT_CHECK:
			print("| --- FEINT (Bot Selection) --- |")
			_simulate_turn()
		GameManager.State.POST_CLASH:
			_print_status_report()

func _simulate_turn():
	await get_tree().create_timer(0.4).timeout
	
	var attacker_id = GameManager.get_attacker()
	
	# 0 = Neutral, 1 = P1, 2 = P2
	var p1_filter = null
	var p2_filter = null
	
	if attacker_id != 0:
		p1_filter = ActionData.Type.OFFENCE if attacker_id == 1 else ActionData.Type.DEFENCE
		p2_filter = ActionData.Type.OFFENCE if attacker_id == 2 else ActionData.Type.DEFENCE
	
	GameManager.player_select_action(1, _get_smart_card_choice(p1_resource, p1_filter))
	GameManager.player_select_action(2, _get_smart_card_choice(p2_resource, p2_filter))

func _get_smart_card_choice(character: CharacterData, type_filter) -> ActionData:
	var valid_options = []
	var affordable_backups = []
	
	for card in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if card.cost <= character.current_sp: valid_options.append(card)
		if card.cost == 0: affordable_backups.append(card)
	
	if valid_options.size() > 0: return valid_options.pick_random()
	
	print("[BOT] " + character.character_name + " Fallback! (Budget/Role Constraint)")
	if type_filter == ActionData.Type.OFFENCE:
		for card in affordable_backups:
			if "Positioning" in card.display_name: return card
	elif type_filter == ActionData.Type.DEFENCE:
		for card in affordable_backups:
			if "Block" in card.display_name: return card

	if affordable_backups.size() > 0: return affordable_backups[0]
	return character.deck[0]

func _on_game_over(winner_id):
	print("\n************************************************")
	print("         VICTORY FOR PLAYER " + str(winner_id) + "!")
	print("************************************************")
	
	# --- NEW: STOP LOGIC ---
	if stop_on_game_over:
		print(">> Simulation Stopped by User Setting <<")
		_simulation_active = false
	else:
		print(">> Resetting for new match... <<")

func _on_clash_resolved(winner_id, _text):
	print("\n>>> Clash Winner: P" + str(winner_id))

func _on_log_updated(text):
	print("   > " + text)

func _print_status_report():
	var p1 = p1_resource
	var p2 = p2_resource
	var mom = GameManager.momentum
	var att = GameManager.get_attacker() 
	
	var visual = "[ "
	for i in range(1, 5): visual += ("P1 " if mom == i else str(i) + " ")
	visual += "| "
	for i in range(5, 9): visual += ("P2 " if mom == i else str(i) + " ")
	visual += "]"
	
	print("\n[STATUS] P1: " + str(p1.current_hp) + "HP/" + str(p1.current_sp) + "SP  vs  P2: " + str(p2.current_hp) + "HP/" + str(p2.current_sp) + "SP")
	print("[MOMENTUM] " + visual)
	
	var control_text = "NEUTRAL"
	if att == 1: control_text = "P1 HAS OFFENCE"
	elif att == 2: control_text = "P2 HAS OFFENCE"
	
	if GameManager.current_combo_attacker != 0:
		control_text += " (COMBO ACTIVE)"
	
	print("[CONTROL] " + control_text)
