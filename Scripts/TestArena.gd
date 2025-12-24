extends Node2D

@export var p1_resource: CharacterData
@export var p2_resource: CharacterData
@export var stop_on_game_over: bool = true 
@export var is_player_1_human: bool = true 

@onready var battle_ui = $BattleUI
var _simulation_active: bool = true

func _ready():
	await get_tree().process_frame
	
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.combat_log_updated.connect(_on_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved)
	GameManager.game_over.connect(_on_game_over)
	
	battle_ui.human_selected_card.connect(_on_human_input_received)
	battle_ui.load_deck(p1_resource.deck)
	
	print("--- INITIALIZING MATCH ---")
	GameManager.start_combat(p1_resource, p2_resource)

func _on_state_changed(new_state):
	if not _simulation_active: return

	match new_state:
		GameManager.State.SELECTION:
			await get_tree().create_timer(0.5).timeout
			if is_player_1_human:
				print("\n| --- NEW TURN: Waiting for Player Input... --- |")
				_prepare_human_turn()
			else:
				print("\n| --- NEW TURN: AI vs AI --- |")
				_run_full_bot_turn()
			
		GameManager.State.FEINT_CHECK:
			await get_tree().create_timer(0.3).timeout
			if is_player_1_human:
				print("| --- FEINT: Waiting for Player Input... --- |")
				_prepare_human_turn()
			else:
				print("| --- FEINT: Bot Reaction --- |")
				_run_full_bot_turn()

		GameManager.State.POST_CLASH:
			_print_status_report()

# --- HUMAN TURN ---

func _prepare_human_turn():
	if GameManager.p1_locked_card:
		print(">>> PLAYER LOCKED into: " + GameManager.p1_locked_card.display_name)
		_run_enemy_bot_turn()
		return

	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.current_combo_attacker != 0)
	var mom = GameManager.momentum
	
	var required_tab = null
	var requires_opener = false
	
	if attacker_id == 1: 
		required_tab = ActionData.Type.OFFENCE 
		print("[GUIDE] You have the initiative! Attack!")
		if not is_combo: requires_opener = true
	elif attacker_id == 2:
		required_tab = ActionData.Type.DEFENCE 
		print("[GUIDE] You are under attack! Defend!")
	else:
		print("[GUIDE] Neutral state. Anything goes.")
		requires_opener = true
		
	# NEW: Pass P1's constraints to the UI
	battle_ui.unlock_for_input(
		required_tab, 
		p1_resource.current_sp, 
		requires_opener,
		GameManager.p1_cost_limit,   # My Max Cost
		GameManager.p1_opening_stat  # My Counter Ability
	)

func _on_human_input_received(p1_card: ActionData):
	print(">>> PLAYER COMMITTED: " + p1_card.display_name)
	GameManager.player_select_action(1, p1_card)
	_run_enemy_bot_turn()

# --- BOT LOGIC (P2) ---

func _run_enemy_bot_turn():
	if GameManager.p2_locked_card:
		print(">>> BOT P2 LOCKED into: " + GameManager.p2_locked_card.display_name)
		return 

	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.current_combo_attacker != 0)
	var mom = GameManager.momentum
	
	var p2_filter = null
	if attacker_id != 0:
		p2_filter = ActionData.Type.OFFENCE if attacker_id == 2 else ActionData.Type.DEFENCE
	
	var p2_needs_opener = false
	if mom == 0: p2_needs_opener = true 
	elif attacker_id == 2 and not is_combo: p2_needs_opener = true 
	
	# NEW: Pass P2's constraints to the Brain
	var p2_card = _get_smart_card_choice(
		p2_resource, 
		p2_filter, 
		p2_needs_opener, 
		GameManager.p2_cost_limit, 
		GameManager.p2_opening_stat
	)
	GameManager.player_select_action(2, p2_card)

# --- BOT LOGIC (P1 - AI vs AI) ---

func _run_full_bot_turn():
	if GameManager.p1_locked_card:
		print(">>> BOT P1 LOCKED into: " + GameManager.p1_locked_card.display_name)
	else:
		var attacker_id = GameManager.get_attacker()
		var is_combo = (GameManager.current_combo_attacker != 0)
		var mom = GameManager.momentum
		
		var p1_filter = null
		if attacker_id != 0:
			p1_filter = ActionData.Type.OFFENCE if attacker_id == 1 else ActionData.Type.DEFENCE
			
		var p1_needs_opener = false
		if mom == 0: p1_needs_opener = true
		elif attacker_id == 1 and not is_combo: p1_needs_opener = true
		
		# NEW: Pass P1's constraints
		var p1_card = _get_smart_card_choice(
			p1_resource, 
			p1_filter, 
			p1_needs_opener, 
			GameManager.p1_cost_limit, 
			GameManager.p1_opening_stat
		)
		print(">>> BOT P1 COMMITTED: " + p1_card.display_name)
		GameManager.player_select_action(1, p1_card)
	
	_run_enemy_bot_turn()

# --- BOT BRAIN ---

# UPDATED: Now accepts 'max_cost' and 'my_opening'
func _get_smart_card_choice(character: CharacterData, type_filter, must_be_opener: bool = false, max_cost: int = 99, my_opening: int = 0) -> ActionData:
	var valid_options = []
	var affordable_backups = []
	
	for card in character.deck:
		if type_filter != null and card.type != type_filter: continue
		
		# 1. Opener Check
		if must_be_opener and card.type == ActionData.Type.OFFENCE:
			if not card.is_opener: continue
		
		# 2. Cost Constraint (Create Opening)
		if card.cost > max_cost: continue

		# 3. Counter Requirement
		if card.counter_value > 0 and my_opening < card.counter_value: continue
			
		# 4. Affordability
		if card.cost <= character.current_sp:
			valid_options.append(card)
		
		if card.cost == 0:
			# Validate backups too!
			if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
			if card.cost > max_cost: continue # Redundant for 0, but good safety
			if card.counter_value > 0 and my_opening < card.counter_value: continue
			
			affordable_backups.append(card)
	
	if valid_options.size() > 0:
		return valid_options.pick_random()
	
	print("[BOT] " + character.character_name + " Fallback! (No valid cards found)")
	
	if affordable_backups.size() > 0:
		return affordable_backups[0]

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
