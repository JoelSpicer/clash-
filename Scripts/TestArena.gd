extends Node2D

@export_group("Setup")
@export var p1_resource: CharacterData
@export var p2_resource: CharacterData
@export var stop_on_game_over: bool = true 

@export_group("Debug Controls")
@export var is_player_1_human: bool = true 
@export var is_player_2_human: bool = false 
@export var p2_debug_force_card: ActionData 

@onready var battle_ui = $BattleUI
var _simulation_active: bool = true
var _current_input_player: int = 1 

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
			_start_turn_sequence()
		GameManager.State.FEINT_CHECK:
			await get_tree().create_timer(0.3).timeout
			print("| --- FEINT PHASE --- |")
			_start_turn_sequence()
		GameManager.State.POST_CLASH:
			_print_status_report()

func _start_turn_sequence():
	if is_player_1_human:
		_prepare_human_turn(1)
	else:
		print("\n| --- NEW TURN: AI P1 --- |")
		_run_bot_turn(1)

# --- NEW HELPER: CONSOLIDATED LOGIC ---
func _get_player_constraints(player_id: int) -> Dictionary:
	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.current_combo_attacker != 0)
	var mom = GameManager.momentum
	
	var c = {
		"filter": null,          
		"required_tab": null,   
		"needs_opener": false,
		"max_cost": 99,
		"opening_stat": 0,
		"can_use_super": false # NEW: Super Permission
	}
	
	# 1. Fetch Stats & Check Super Conditions
	if player_id == 1:
		c.max_cost = GameManager.p1_cost_limit
		c.opening_stat = GameManager.p1_opening_stat
		# P1 Super Condition: Momentum must be 1 (End of P1 Side) AND Not Used
		if mom == 1 and not p1_resource.has_used_super:
			c.can_use_super = true
	else:
		c.max_cost = GameManager.p2_cost_limit
		c.opening_stat = GameManager.p2_opening_stat
		# P2 Super Condition: Momentum must be 8 (End of P2 Side) AND Not Used
		if mom == 8 and not p2_resource.has_used_super:
			c.can_use_super = true

	# 2. Determine Role
	if attacker_id != 0:
		if attacker_id == player_id:
			c.filter = ActionData.Type.OFFENCE
			c.required_tab = ActionData.Type.OFFENCE
		else:
			c.filter = ActionData.Type.DEFENCE
			c.required_tab = ActionData.Type.DEFENCE
			
	# 3. Opener Logic
	if mom == 0:
		c.needs_opener = true
	elif attacker_id == player_id and not is_combo:
		c.needs_opener = true
		
	return c

# --- HUMAN INPUT ---

func _prepare_human_turn(player_id: int):
	_current_input_player = player_id
	var character = p1_resource if player_id == 1 else p2_resource
	battle_ui.load_deck(character.deck)
	
	# Check Locks
	var locked_card = GameManager.p1_locked_card if player_id == 1 else GameManager.p2_locked_card
	if locked_card:
		print(">>> P" + str(player_id) + " LOCKED into: " + locked_card.display_name)
		_on_human_input_received(locked_card)
		return

	# Use Helper
	var c = _get_player_constraints(player_id)
	
	# Guide Print
	if c.required_tab == ActionData.Type.OFFENCE: print("[GUIDE P" + str(player_id) + "] Attack!")
	elif c.required_tab == ActionData.Type.DEFENCE: print("[GUIDE P" + str(player_id) + "] Defend!")
	else: print("[GUIDE P" + str(player_id) + "] Neutral.")
		
	print("| --- WAITING FOR P" + str(player_id) + " INPUT --- |")
	
	# Pass "can_use_super" to UI
	battle_ui.unlock_for_input(
		c.required_tab, 
		character.current_sp, 
		c.needs_opener, 
		c.max_cost, 
		c.opening_stat,
		c.can_use_super 
	)

func _on_human_input_received(card: ActionData):
	print(">>> P" + str(_current_input_player) + " COMMITTED: " + card.display_name)
	GameManager.player_select_action(_current_input_player, card)
	
	if _current_input_player == 1:
		if is_player_2_human:
			await get_tree().create_timer(0.2).timeout # Fix Race Condition
			_prepare_human_turn(2)
		else:
			_run_bot_turn(2)

# --- BOT LOGIC ---

func _run_bot_turn(player_id: int):
	var character = p1_resource if player_id == 1 else p2_resource
	
	if player_id == 2 and p2_debug_force_card != null:
		print(">>> DEBUG FORCE P2: " + p2_debug_force_card.display_name)
		GameManager.player_select_action(2, p2_debug_force_card)
		return

	var locked_card = GameManager.p1_locked_card if player_id == 1 else GameManager.p2_locked_card
	if locked_card:
		print(">>> BOT P" + str(player_id) + " LOCKED into: " + locked_card.display_name)
		_handle_bot_completion(player_id)
		return

	var c = _get_player_constraints(player_id)
	
	# Pass "can_use_super" to Bot Brain
	var card = _get_smart_card_choice(character, c.filter, c.needs_opener, c.max_cost, c.opening_stat, c.can_use_super)
	print(">>> BOT P" + str(player_id) + " COMMITTED: " + card.display_name)
	GameManager.player_select_action(player_id, card)
	
	_handle_bot_completion(player_id)

func _handle_bot_completion(player_id):
	if player_id == 1:
		if is_player_2_human:
			_prepare_human_turn(2)
		else:
			_run_bot_turn(2)

# --- BOT BRAIN ---

func _get_smart_card_choice(character: CharacterData, type_filter, must_be_opener: bool, max_cost: int, my_opening: int, allow_super: bool) -> ActionData:
	var valid_options = []
	var affordable_backups = []
	
	for card in character.deck:
		# Filter Check
		if type_filter != null and card.type != type_filter: continue
		if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
		if card.cost > max_cost: continue
		if card.counter_value > 0 and my_opening < card.counter_value: continue
		
		# NEW: Super Check
		if card.is_super and not allow_super: continue
		
		# Validation Succeeded
		if card.cost <= character.current_sp:
			valid_options.append(card)
		elif card.cost == 0:
			affordable_backups.append(card)
	
	if valid_options.size() > 0: return valid_options.pick_random()
	
	print("[BOT] " + character.character_name + " Fallback! (No valid cards found)")
	if affordable_backups.size() > 0: return affordable_backups[0]
	return character.deck[0]

# --- LOGGING (Unchanged) ---
func _on_game_over(winner_id):
	print("\n*** VICTORY FOR PLAYER " + str(winner_id) + "! ***")
	if stop_on_game_over: _simulation_active = false
func _on_clash_resolved(winner_id, _text): print("\n>>> Clash Winner: P" + str(winner_id))
func _on_log_updated(text): print("   > " + text)
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
