extends Node2D

@export var p1_resource: CharacterData
@export var p2_resource: CharacterData
@export var stop_on_game_over: bool = true 

# UI REFERENCE
@onready var battle_ui = $BattleUI

var _simulation_active: bool = true

func _ready():
	await get_tree().process_frame
	
	# 1. Connect Game Signals
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.combat_log_updated.connect(_on_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved)
	GameManager.game_over.connect(_on_game_over)
	
	# 2. Connect UI Signals (This bridges the gap!)
	battle_ui.human_selected_card.connect(_on_human_input_received)
	
	# 3. Load Deck into UI
	battle_ui.load_deck(p1_resource.deck)
	
	print("--- INITIALIZING HUMAN vs BOT MATCH ---")
	GameManager.start_combat(p1_resource, p2_resource)

func _on_state_changed(new_state):
	if not _simulation_active: return

	match new_state:
		GameManager.State.SELECTION:
			# ADD THIS WAIT! 
			# Breaks the stack, lets the UI clean up, and improves pacing.
			await get_tree().create_timer(0.5).timeout
			
			print("\n| --- NEW TURN: Waiting for Player Input... --- |")
			_prepare_human_turn()
			
		GameManager.State.FEINT_CHECK:
			# Add a small delay here too for consistency
			await get_tree().create_timer(0.3).timeout
			print("| --- FEINT: Waiting for Player Input... --- |")
			_prepare_human_turn()
			
		GameManager.State.POST_CLASH:
			_print_status_report()

# --- TURN LOGIC ---

func _prepare_human_turn():
	# 1. Determine who is attacking so we show the right tab
	var attacker_id = GameManager.get_attacker()
	
	var required_tab = null
	if attacker_id == 1: 
		required_tab = ActionData.Type.OFFENCE # P1 Attacking
		print("[GUIDE] You have the initiative! Attack!")
	elif attacker_id == 2:
		required_tab = ActionData.Type.DEFENCE # P1 Defending
		print("[GUIDE] You are under attack! Defend!")
	else:
		print("[GUIDE] Neutral state. Anything goes.")
		
	# 2. Unlock the UI for the player
	battle_ui.unlock_for_input(required_tab)

func _on_human_input_received(p1_card: ActionData):
	# This triggers when you click a button in BattleUI
	print(">>> PLAYER COMMITTED: " + p1_card.display_name)
	
	# 1. Submit Player Move
	GameManager.player_select_action(1, p1_card)
	
	# 2. Submit Bot Move (Immediate response)
	_run_enemy_bot_turn()

func _run_enemy_bot_turn():
	# Logic is the same as before, but only for P2
	var attacker_id = GameManager.get_attacker()
	
	var p2_filter = null
	if attacker_id != 0:
		p2_filter = ActionData.Type.OFFENCE if attacker_id == 2 else ActionData.Type.DEFENCE
	
	var p2_card = _get_smart_card_choice(p2_resource, p2_filter)
	
	# Submit Bot Move
	GameManager.player_select_action(2, p2_card)

# --- BOT BRAIN (Same as before) ---

func _get_smart_card_choice(character: CharacterData, type_filter) -> ActionData:
	var valid_options = []
	var affordable_backups = []
	
	for card in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if card.cost <= character.current_sp: valid_options.append(card)
		if card.cost == 0: affordable_backups.append(card)
	
	if valid_options.size() > 0: return valid_options.pick_random()
	
	# Fallback Logic
	if type_filter == ActionData.Type.OFFENCE:
		for card in affordable_backups:
			if "Positioning" in card.display_name: return card
	elif type_filter == ActionData.Type.DEFENCE:
		for card in affordable_backups:
			if "Block" in card.display_name: return card

	if affordable_backups.size() > 0: return affordable_backups[0]
	return character.deck[0]

# --- LOGGING & REPORTS ---

func _on_game_over(winner_id):
	print("\n*** VICTORY FOR PLAYER " + str(winner_id) + "! ***")
	if stop_on_game_over: _simulation_active = false

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
