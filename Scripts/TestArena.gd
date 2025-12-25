extends Node2D

@export_group("Setup")
@export var p1_resource: CharacterData
@export var p2_resource: CharacterData
@export var stop_on_game_over: bool = true 

@export_group("Debug Controls")
# Check to play P1 manually. Uncheck to watch AI.
@export var is_player_1_human: bool = true 

# Check to play P2 manually (Hotseat Mode).
@export var is_player_2_human: bool = false 

# If P2 is a Bot, drag a card here to FORCE them to play it every turn.
@export var p2_debug_force_card: ActionData 

# UI REFERENCE
@onready var battle_ui = $BattleUI

var _simulation_active: bool = true
var _current_input_player: int = 1 # Tracks whose turn it is to click the UI

func _ready():
	await get_tree().process_frame
	
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.combat_log_updated.connect(_on_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved)
	GameManager.game_over.connect(_on_game_over)
	
	battle_ui.human_selected_card.connect(_on_human_input_received)
	
	# Initial Load
	battle_ui.load_deck(p1_resource.deck)
	
	print("--- INITIALIZING MATCH ---")
	GameManager.start_combat(p1_resource, p2_resource)

func _on_state_changed(new_state):
	if not _simulation_active: return

	match new_state:
		GameManager.State.SELECTION:
			await get_tree().create_timer(0.5).timeout
			_start_turn_sequence()
			
		GameManager.State.FEINT_CHECK:
			await get_tree().create_timer(0.3).timeout
			print("| --- FEINT PHASE --- |")
			_start_turn_sequence()

		GameManager.State.POST_CLASH:
			_print_status_report()

func _start_turn_sequence():
	# If P1 is human, start with them. Otherwise run P1 Bot.
	if is_player_1_human:
		_prepare_human_turn(1)
	else:
		print("\n| --- NEW TURN: AI P1 --- |")
		_run_bot_turn(1)

# --- HUMAN INPUT HANDLING ---

func _prepare_human_turn(player_id: int):
	_current_input_player = player_id
	
	# 1. Load correct deck
	var character = p1_resource if player_id == 1 else p2_resource
	battle_ui.load_deck(character.deck)
	
	# 2. Check Locks
	if player_id == 1 and GameManager.p1_locked_card:
		print(">>> P1 LOCKED into: " + GameManager.p1_locked_card.display_name)
		_on_human_input_received(GameManager.p1_locked_card) # Auto-submit
		return
	if player_id == 2 and GameManager.p2_locked_card:
		print(">>> P2 LOCKED into: " + GameManager.p2_locked_card.display_name)
		_on_human_input_received(GameManager.p2_locked_card) # Auto-submit
		return

	# 3. Determine Constraints
	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.current_combo_attacker != 0)
	var mom = GameManager.momentum
	
	var required_tab = null
	var requires_opener = false
	var max_cost = 99
	var opening_stat = 0
	
	# Get Data based on ID
	if player_id == 1:
		max_cost = GameManager.p1_cost_limit
		opening_stat = GameManager.p1_opening_stat
	else:
		max_cost = GameManager.p2_cost_limit
		opening_stat = GameManager.p2_opening_stat
	
	# Determine Tab & Opener
	if attacker_id == player_id: 
		required_tab = ActionData.Type.OFFENCE 
		if not is_combo: requires_opener = true
		print("[GUIDE P" + str(player_id) + "] You have the initiative! Attack!")
	elif attacker_id != 0:
		required_tab = ActionData.Type.DEFENCE 
		print("[GUIDE P" + str(player_id) + "] You are under attack! Defend!")
	else:
		print("[GUIDE P" + str(player_id) + "] Neutral state. Anything goes.")
		requires_opener = true
		
	# 4. Unlock UI
	print("| --- WAITING FOR P" + str(player_id) + " INPUT --- |")
	battle_ui.unlock_for_input(
		required_tab, 
		character.current_sp, 
		requires_opener,
		max_cost,
		opening_stat
	)

func _on_human_input_received(card: ActionData):
	print(">>> P" + str(_current_input_player) + " COMMITTED: " + card.display_name)
	
	# Submit the move
	GameManager.player_select_action(_current_input_player, card)
	
	# DECIDE WHAT HAPPENS NEXT
	if _current_input_player == 1:
		# P1 finished. Now do P2.
		if is_player_2_human:
			await get_tree().create_timer(0.2).timeout
			_prepare_human_turn(2) # Switch UI to P2
		else:
			_run_bot_turn(2) # Run P2 Bot
	else:
		# P2 finished. Round complete.
		# (GameManager handles resolution automatically)
		pass

# --- BOT LOGIC ---

func _run_bot_turn(player_id: int):
	var character = p1_resource if player_id == 1 else p2_resource
	
	# 1. Check Forced Debug Card
	if player_id == 2 and p2_debug_force_card != null:
		print(">>> DEBUG FORCE P2: " + p2_debug_force_card.display_name)
		GameManager.player_select_action(2, p2_debug_force_card)
		return

	# 2. Check Locks
	if player_id == 1 and GameManager.p1_locked_card:
		print(">>> BOT P1 LOCKED into: " + GameManager.p1_locked_card.display_name)
		# GameManager already has it queued, but for flow we can trigger P2
		_handle_bot_completion(player_id)
		return
	if player_id == 2 and GameManager.p2_locked_card:
		print(">>> BOT P2 LOCKED into: " + GameManager.p2_locked_card.display_name)
		return 

	# 3. Standard AI Logic
	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.current_combo_attacker != 0)
	var mom = GameManager.momentum
	
	var filter = null
	if attacker_id != 0:
		filter = ActionData.Type.OFFENCE if attacker_id == player_id else ActionData.Type.DEFENCE
	
	var needs_opener = false
	if mom == 0: needs_opener = true
	elif attacker_id == player_id and not is_combo: needs_opener = true
	
	# Get Constraints
	var limit = GameManager.p1_cost_limit if player_id == 1 else GameManager.p2_cost_limit
	var open_stat = GameManager.p1_opening_stat if player_id == 1 else GameManager.p2_opening_stat
	
	var card = _get_smart_card_choice(character, filter, needs_opener, limit, open_stat)
	print(">>> BOT P" + str(player_id) + " COMMITTED: " + card.display_name)
	GameManager.player_select_action(player_id, card)
	
	_handle_bot_completion(player_id)

func _handle_bot_completion(player_id):
	# If P1 Bot just finished, trigger P2
	if player_id == 1:
		if is_player_2_human:
			_prepare_human_turn(2)
		else:
			_run_bot_turn(2)

# --- BOT BRAIN ---

func _get_smart_card_choice(character: CharacterData, type_filter, must_be_opener: bool = false, max_cost: int = 99, my_opening: int = 0) -> ActionData:
	var valid_options = []
	var affordable_backups = []
	
	for card in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
		if card.cost > max_cost: continue
		if card.counter_value > 0 and my_opening < card.counter_value: continue
			
		if card.cost <= character.current_sp:
			valid_options.append(card)
		
		if card.cost == 0:
			# Safety checks for backups
			if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
			if card.cost > max_cost: continue 
			if card.counter_value > 0 and my_opening < card.counter_value: continue
			affordable_backups.append(card)
	
	if valid_options.size() > 0: return valid_options.pick_random()
	
	print("[BOT] " + character.character_name + " Fallback! (No valid cards found)")
	if affordable_backups.size() > 0: return affordable_backups[0]
	return character.deck[0]

# --- LOGGING ---

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
	var visual = "[ "
	for i in range(1, 5): visual += ("P1 " if mom == i else str(i) + " ")
	visual += "| "
	for i in range(5, 9): visual += ("P2 " if mom == i else str(i) + " ")
	visual += "]"
	
	print("\n[STATUS] P1: " + str(p1.current_hp) + "HP/" + str(p1.current_sp) + "SP  vs  P2: " + str(p2.current_hp) + "HP/" + str(p2.current_sp) + "SP")
	print("[MOMENTUM] " + visual)
