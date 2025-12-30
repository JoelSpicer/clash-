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
	battle_ui.combat_log.clear_log()
	# Connect Signals
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.combat_log_updated.connect(_on_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved)
	GameManager.game_over.connect(_on_game_over)
	
	battle_ui.human_selected_card.connect(_on_human_input_received)
	
	# NEW: Connect Toggles
	battle_ui.p1_mode_toggled.connect(_on_p1_mode_toggled)
	battle_ui.p2_mode_toggled.connect(_on_p2_mode_toggled)
	
	battle_ui.load_deck(p1_resource.deck)
	
	print("--- INITIALIZING MATCH ---")
	GameManager.start_combat(p1_resource, p2_resource)
	
	# Setup Visuals & Toggles
	battle_ui.initialize_hud(p1_resource, p2_resource)
	battle_ui.setup_toggles(is_player_1_human, is_player_2_human)

func _update_visuals():
	battle_ui.update_all_visuals(p1_resource, p2_resource, GameManager.momentum)

# --- TOGGLE LOGIC ---

func _on_p1_mode_toggled(is_human: bool):
	is_player_1_human = is_human
	print("[DEBUG] P1 Human Mode: " + str(is_human))
	_check_mid_turn_state_change(1, is_human)

func _on_p2_mode_toggled(is_human: bool):
	is_player_2_human = is_human
	print("[DEBUG] P2 Human Mode: " + str(is_human))
	_check_mid_turn_state_change(2, is_human)

# Handles the case where we toggle Bot mode ON while waiting for that player
func _check_mid_turn_state_change(player_id: int, is_human: bool):
	# Only intervene if we are currently waiting for input from THIS player
	if _current_input_player != player_id: return
	
	# Check valid states for input
	if GameManager.current_state != GameManager.State.SELECTION and GameManager.current_state != GameManager.State.FEINT_CHECK:
		return

	# If switched TO BOT, force the bot to run immediately
	if not is_human:
		print(">>> TAKEOVER: Bot taking control of P" + str(player_id))
		battle_ui.lock_ui() # Hide the human UI
		_run_bot_turn(player_id)
	
	# If switched TO HUMAN, unlock the UI
	elif is_human:
		print(">>> TAKEOVER: Human taking control of P" + str(player_id))
		_prepare_human_turn(player_id)

# --- GAME LOOP ---

func _on_state_changed(new_state):
	if not _simulation_active: return

	match new_state:
		GameManager.State.SELECTION:
			await get_tree().create_timer(0.5).timeout
			_start_turn_sequence()
			
		GameManager.State.FEINT_CHECK:
			await get_tree().create_timer(0.3).timeout
			print("| --- FEINT PHASE --- |")
			_start_feint_input()

		GameManager.State.POST_CLASH:
			_print_status_report()

func _start_turn_sequence():
	if is_player_1_human: _prepare_human_turn(1)
	else:
		print("\n| --- NEW TURN: AI P1 --- |")
		_run_bot_turn(1)

func _start_feint_input():
	if GameManager.p1_pending_feint:
		print("| --- WAITING FOR P1 FEINT SELECTION --- |")
		if is_player_1_human: _prepare_human_turn(1)
		else: _run_bot_turn(1)
	elif GameManager.p2_pending_feint:
		print("| --- WAITING FOR P2 FEINT SELECTION --- |")
		if is_player_2_human: _prepare_human_turn(2)
		else: _run_bot_turn(2)

func _get_player_constraints(player_id: int) -> Dictionary:
	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.current_combo_attacker != 0)
	var mom = GameManager.momentum
	
	var c = {
		"filter": null, "required_tab": null, "needs_opener": false,
		"max_cost": 99, "opening_stat": 0, "can_use_super": false, "opportunity_stat": 0 
	}
	
	if player_id == 1:
		c.max_cost = GameManager.p1_cost_limit
		c.opening_stat = GameManager.p1_opening_stat
		c.opportunity_stat = GameManager.p1_opportunity_stat 
		if mom == 1 and not p1_resource.has_used_super: c.can_use_super = true
		if GameManager.p1_must_opener: c.needs_opener = true
	else:
		c.max_cost = GameManager.p2_cost_limit
		c.opening_stat = GameManager.p2_opening_stat
		c.opportunity_stat = GameManager.p2_opportunity_stat 
		if mom == 8 and not p2_resource.has_used_super: c.can_use_super = true
		if GameManager.p2_must_opener: c.needs_opener = true

	if attacker_id != 0:
		if attacker_id == player_id:
			c.filter = ActionData.Type.OFFENCE
			c.required_tab = ActionData.Type.OFFENCE
		else:
			c.filter = ActionData.Type.DEFENCE
			c.required_tab = ActionData.Type.DEFENCE
			
	if mom == 0: c.needs_opener = true
	elif attacker_id == player_id and not is_combo: c.needs_opener = true
		
	return c

func _prepare_human_turn(player_id: int):
	_current_input_player = player_id
	var character = p1_resource if player_id == 1 else p2_resource
	battle_ui.load_deck(character.deck)
	
	var locked_card = GameManager.p1_locked_card if player_id == 1 else GameManager.p2_locked_card
	if locked_card and GameManager.current_state == GameManager.State.SELECTION:
		print(">>> P" + str(player_id) + " LOCKED into: " + locked_card.display_name)
		_on_human_input_received(locked_card)
		return

	var c = _get_player_constraints(player_id)
	var is_feinting = (GameManager.current_state == GameManager.State.FEINT_CHECK)
	
	if is_feinting:
		print("[GUIDE P" + str(player_id) + "] Feint! Choose a card to combine, or 'SKIP FEINT'.")
	else:
		if c.required_tab == ActionData.Type.OFFENCE: print("[GUIDE P" + str(player_id) + "] Attack!")
		elif c.required_tab == ActionData.Type.DEFENCE: print("[GUIDE P" + str(player_id) + "] Defend!")
		else: print("[GUIDE P" + str(player_id) + "] Neutral.")
	
	_update_visuals() 
	print("| --- WAITING FOR P" + str(player_id) + " INPUT --- |")
	
	battle_ui.unlock_for_input(
		c.required_tab, character.current_sp, c.needs_opener, c.max_cost, c.opening_stat,
		c.can_use_super, c.opportunity_stat, is_feinting
	)

func _on_human_input_received(card: ActionData):
	print(">>> P" + str(_current_input_player) + " COMMITTED: " + card.display_name)
	
	var action_to_submit = card
	if card.display_name == "SKIP FEINT": action_to_submit = null
	
	GameManager.player_select_action(_current_input_player, action_to_submit)
	
	if GameManager.current_state == GameManager.State.SELECTION:
		if _current_input_player == 1:
			if is_player_2_human:
				await get_tree().create_timer(0.2).timeout
				_prepare_human_turn(2)
			else: _run_bot_turn(2)
				
	elif GameManager.current_state == GameManager.State.FEINT_CHECK:
		await get_tree().create_timer(0.2).timeout
		_start_feint_input() 

func _run_bot_turn(player_id: int):
	_current_input_player = player_id # Ensure tracker is correct for mid-turn switches
	var character = p1_resource if player_id == 1 else p2_resource
	
	if player_id == 2 and p2_debug_force_card != null and GameManager.current_state == GameManager.State.SELECTION:
		print(">>> DEBUG FORCE P2: " + p2_debug_force_card.display_name)
		GameManager.player_select_action(2, p2_debug_force_card)
		return

	var locked_card = GameManager.p1_locked_card if player_id == 1 else GameManager.p2_locked_card
	if locked_card and GameManager.current_state == GameManager.State.SELECTION:
		print(">>> BOT P" + str(player_id) + " LOCKED into: " + locked_card.display_name)
		_handle_bot_completion(player_id)
		return

	var c = _get_player_constraints(player_id)
	
	var card = _get_smart_card_choice(character, c.filter, c.needs_opener, c.max_cost, c.opening_stat, c.can_use_super, c.opportunity_stat)
	print(">>> BOT P" + str(player_id) + " COMMITTED: " + card.display_name)
	GameManager.player_select_action(player_id, card)
	
	if GameManager.current_state == GameManager.State.SELECTION: _handle_bot_completion(player_id)
	elif GameManager.current_state == GameManager.State.FEINT_CHECK:
		await get_tree().create_timer(0.2).timeout
		_start_feint_input()

func _handle_bot_completion(player_id):
	if player_id == 1:
		if is_player_2_human: _prepare_human_turn(2)
		else: _run_bot_turn(2)

func _get_smart_card_choice(character: CharacterData, type_filter, must_be_opener: bool, max_cost: int, my_opening: int, allow_super: bool, my_opportunity: int) -> ActionData:
	var valid_options = []
	var affordable_backups = []
	
	for card in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
		if card.cost > max_cost: continue
		if card.counter_value > 0 and my_opening < card.counter_value: continue
		if card.is_super and not allow_super: continue
		
		var effective_cost = max(0, card.cost - my_opportunity)
		if effective_cost <= character.current_sp: valid_options.append(card)
		elif effective_cost == 0: affordable_backups.append(card)
	
	if valid_options.size() > 0: return valid_options.pick_random()
	if affordable_backups.size() > 0: return affordable_backups[0]
	return character.deck[0]

# --- LOGGING ---
func _on_game_over(winner_id):
	print("\n*** VICTORY FOR PLAYER " + str(winner_id) + "! ***")
	if stop_on_game_over: _simulation_active = false
func _on_clash_resolved(winner_id, _text): 
	print("\n>>> Clash Winner: P" + str(winner_id))
	_update_visuals()
func _on_log_updated(text): print("   > " + text)
func _print_status_report():
	var p1 = p1_resource; var p2 = p2_resource
	var visual = "[ "; for i in range(1, 5): visual += ("P1 " if GameManager.momentum == i else str(i) + " ")
	visual += "| "; for i in range(5, 9): visual += ("P2 " if GameManager.momentum == i else str(i) + " ")
	visual += "]"
	print("\n[STATUS] P1: " + str(p1.current_hp) + "HP/" + str(p1.current_sp) + "SP  vs  P2: " + str(p2.current_hp) + "HP/" + str(p2.current_sp) + "SP")
	print("[MOMENTUM] " + visual)
