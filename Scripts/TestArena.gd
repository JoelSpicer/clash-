extends Node2D

@export_group("Setup")
@export var p1_resource: CharacterData
@export var p2_resource: CharacterData
@export var stop_on_game_over: bool = true 

@export_group("Debug Controls")
@export var is_player_1_human: bool = true 
@export var is_player_2_human: bool = false 
@export var p2_debug_force_card: ActionData 

# NEW: Preload the Game Over Screen
var game_over_scene = preload("res://Scenes/GameOverScreen.tscn")
var game_over_screen
var local_player_id: int = 1 # Defaults to 1, but changes based on network

# NEW: Server Memory for incoming card selections
var server_received_inputs: Dictionary = {}

@onready var battle_ui = $BattleUI
var _simulation_active: bool = true
var _current_input_player: int = 1 
@onready var tutorial_layer = $"../TutorialLayer" # Grabs it from the MainScene

func _ready() -> void:
	# 1. Await a frame so BattleUI can finish its internal _ready
	await get_tree().process_frame

	if battle_ui.combat_log and battle_ui.combat_log.has_method("clear_log"):
		battle_ui.combat_log.clear_log()

	# 2. Load Player Resources
	if GameManager.next_match_p1_data != null:
		p1_resource = GameManager.next_match_p1_data
	if GameManager.next_match_p2_data != null:
		p2_resource = GameManager.next_match_p2_data
		
	# 3. Determine Human/AI & Network Status
	is_player_1_human = true 
	is_player_2_human = false
	local_player_id = 1 

	var my_id: int = 1 
	if multiplayer.has_multiplayer_peer():
		my_id = multiplayer.get_unique_id()

	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		is_player_2_human = true 
		if my_id == GameManager.p1_network_id:
			local_player_id = 1
		elif my_id == GameManager.p2_network_id:
			local_player_id = 2
		else:
			local_player_id = 0 # The dedicated server Referee
			
	elif not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		is_player_2_human = true

	# 4. Connect Core Signals
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
		GameManager.combat_log_updated.connect(_on_log_updated)
		GameManager.clash_resolved.connect(_on_clash_resolved)
		# GameManager.game_over is now cleanly handled by BattleUI!
		GameManager.request_clash_animation.connect(battle_ui.play_clash_animation)

	if not battle_ui.human_selected_card.is_connected(_on_human_input_received):
		battle_ui.human_selected_card.connect(_on_human_input_received)
	if not battle_ui.p1_mode_toggled.is_connected(_on_p1_mode_toggled):
		battle_ui.p1_mode_toggled.connect(_on_p1_mode_toggled)
		battle_ui.p2_mode_toggled.connect(_on_p2_mode_toggled)

	# 5. INITIALIZE UI (The Decoupled Way)
	battle_ui.setup_match_ui(p1_resource, p2_resource, local_player_id)
	battle_ui.setup_toggles(is_player_1_human, is_player_2_human)
	
	print("--- INITIALIZING MATCH ---")
	
	# We prepare the stats, but we DO NOT let start_combat() change the state yet!
	GameManager.p1_data = p1_resource
	GameManager.p2_data = p2_resource
	GameManager.reset_combat() 
	
	# 6. SETUP VISUALS
	battle_ui.initialize_hud(p1_resource, p2_resource)
	
	# 7. THE SYNC FIX!
	# Tell the server we are done building our UI and are ready to play
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		if not multiplayer.is_server():
			print("Waiting for opponent to load the arena...")
			NetworkManager.rpc_id(1, "client_finished_loading")
	else:
		# If we are offline/local, just start immediately
		GameManager.change_state(GameManager.State.SELECTION)
	
	# 8. UPDATE NAME TAGS BASED ON DIFFICULTY
	var diff_suffix = ""
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: diff_suffix = " (V)"
		GameManager.Difficulty.EASY: diff_suffix = " (E)"
		GameManager.Difficulty.MEDIUM: diff_suffix = " (M)"
		GameManager.Difficulty.HARD: diff_suffix = " (H)"
	
	if not is_player_1_human:
		if battle_ui.p1_hud and battle_ui.p1_hud.name_label:
			battle_ui.p1_hud.name_label.text += diff_suffix
			
	if not is_player_2_human:
		if battle_ui.p2_hud and battle_ui.p2_hud.name_label:
			battle_ui.p2_hud.name_label.text += diff_suffix

func _update_visuals():
	battle_ui.update_all_visuals(p1_resource, p2_resource, GameManager.state.momentum)

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
			
			# THE FIX: Only check the funnel AFTER the turn sequence has fully started!
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				_check_server_funnel()
				
		GameManager.State.FEINT_CHECK:
			await get_tree().create_timer(0.3).timeout
			print("| --- FEINT PHASE --- |")
			_start_feint_input()
			
			# THE FIX: Only check the funnel AFTER the feint sequence has fully started!
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				_check_server_funnel()

		GameManager.State.POST_CLASH:
			if TutorialManager.is_tutorial_active:
				TutorialManager.advance_step()
			_print_status_report()

func _start_turn_sequence():
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		# ONLINE: Both players take their turns at the exact same time!
		if local_player_id == 1 or local_player_id == 2:
			_prepare_human_turn(local_player_id)
	else:
		# OFFLINE: Sequential turns (P1 goes, then P2)
		if is_player_1_human: _prepare_human_turn(1)
		else:
			print("\n| --- NEW TURN: AI P1 --- |")
			_run_bot_turn(1)

func _start_feint_input():
	if GameManager.state.p1_pending_feint:
		print("| --- WAITING FOR P1 FEINT SELECTION --- |")
		if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			if local_player_id == 1: _prepare_human_turn(1)
		else:
			if is_player_1_human: _prepare_human_turn(1)
			else: _run_bot_turn(1)
	elif GameManager.state.p2_pending_feint:
		print("| --- WAITING FOR P2 FEINT SELECTION --- |")
		if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			if local_player_id == 2: _prepare_human_turn(2)
		else:
			if is_player_2_human: _prepare_human_turn(2)
			else: _run_bot_turn(2)

func _get_player_constraints(player_id: int) -> Dictionary:
	# This function asks GameManager who is attacking. 
	# Now that we fixed 'get_attacker', this will return the correct ID!
	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.state.current_combo_attacker != 0)
	var mom = GameManager.state.momentum
	
	var c = {
		"filter": null, "required_tab": null, "needs_opener": false,
		"max_cost": 99, "opening_stat": 0, "can_use_super": false, "opportunity_stat": 0 
	}
	
	# 1. Setup Limits & Stats
	if player_id == 1:
		c.max_cost = GameManager.state.p1_cost_limit
		c.opening_stat = GameManager.state.p1_opening_stat
		c.opportunity_stat = GameManager.state.p1_opportunity_stat 
		
		# SUPER CHECK (Updated for Dynamic Momentum)
		# Checks if momentum is at P1's Wall (e.g. 1)
		if mom == GameManager.get_wall_momentum(1) and not p1_resource.has_used_super:
			c.can_use_super = true
			
		if GameManager.state.p1_must_opener: c.needs_opener = true
	else:
		c.max_cost = GameManager.state.p2_cost_limit
		c.opening_stat = GameManager.state.p2_opening_stat
		c.opportunity_stat = GameManager.state.p2_opportunity_stat 
		
		# SUPER CHECK (Updated for Dynamic Momentum)
		# Checks if momentum is at P2's Wall (e.g. 8 or 12)
		if mom == GameManager.get_wall_momentum(2) and not p2_resource.has_used_super:
			c.can_use_super = true
			
		if GameManager.state.p2_must_opener: c.needs_opener = true

	# 2. Determine Required Tab (Offence vs Defence)
	if attacker_id != 0:
		if attacker_id == player_id:
			c.filter = ActionData.Type.OFFENCE
			c.required_tab = ActionData.Type.OFFENCE
		else:
			c.filter = ActionData.Type.DEFENCE
			c.required_tab = ActionData.Type.DEFENCE
			
	# 3. Neutral / Opener Logic
	if mom == 0: 
		c.needs_opener = true
	elif attacker_id == player_id and not is_combo: 
		# If I am attacking and NOT in a combo, I must use an opener to start one
		c.needs_opener = true
		
	return c

func _prepare_human_turn(player_id: int):
	_current_input_player = player_id
	var character = p1_resource if player_id == 1 else p2_resource
	
	# 1. BUILD THE UI FIRST (So the spotlight has something to look at!)
	battle_ui.setup_passive_toggles(character)
	battle_ui.load_deck(character.deck)
	
	var locked_card = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
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
	
	# 2. MAKE THE GRID VISIBLE (But only if it's MY turn!)
	if player_id == local_player_id:
		battle_ui.unlock_for_input(
			c.required_tab, character.current_sp, character.current_hp, c.needs_opener, c.max_cost, c.opening_stat,
			c.can_use_super, c.opportunity_stat, is_feinting
		)
		
		# --- THE FIX: WAIT FOR THE UI TO DRAW ---
		# We wait two frames so Godot can calculate the exact pixel sizes 
		# and positions of the cards before the spotlight tries to find them!
		await get_tree().process_frame
		await get_tree().process_frame
		# ----------------------------------------
		
		# --- 3. TUTORIAL PAUSE & POPUP ---
		if TutorialManager.is_tutorial_active and player_id == 1:
			battle_ui.is_locked = true # Prevent clicking while reading!
			
			# THE FIX: If this is the very first message, wait 1 second for 
			# the SceneLoader to finish fading the screen in before we pause!
			if TutorialManager.current_step == 0:
				await get_tree().create_timer(1.0).timeout
				# We also need these two frames again just in case
				await get_tree().process_frame
				await get_tree().process_frame
			
			var tut_data = TutorialManager.get_current_data()
			if tut_data.has("sensei_text"):
				var highlight_str = tut_data.get("highlight", "")
				var highlight_node: Control = null
				
				# Map the string to the ACTUAL node here in the Arena!
				# --- UPGRADED TRANSLATOR ---
				if highlight_str == "hand": 
					highlight_node = battle_ui.button_grid
				elif highlight_str == "momentum" or highlight_str == "wall": 
					highlight_node = battle_ui.momentum_slider
				
				# NEW: Support "card:Name"
				elif highlight_str.begins_with("card:"):
					var target_card_name = highlight_str.replace("card:", "")
					highlight_node = _get_button_for_card(target_card_name)
				# ---------------------------
				
				tutorial_layer.show_message(tut_data["sensei_text"], highlight_node)
				# PAUSE EXECUTION UNTIL THE PLAYER CLICKS CONTINUE
				await tutorial_layer.tutorial_message_closed
				
			battle_ui.is_locked = false # Re-enable clicking so they can play the card
		# -----------------------------------
	else:
		# It is the opponent's turn. Lock our screen.
		battle_ui.lock_ui()
		print("Waiting for Opponent to choose...")

func _on_human_input_received(card: ActionData, extra_data: Dictionary = {}) -> void:
	var card_name: String = ""
	if card != null: 
		card_name = card.display_name

	# GDScript 2.0: Use Callable.rpc_id() instead of rpc_id(1, "...")
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_receive_input.rpc_id(1, _current_input_player, card_name, extra_data)
	else:
		# Offline fallback
		server_receive_input(_current_input_player, card_name, extra_data)

@rpc("any_peer", "call_local", "reliable")
func server_receive_input(player_id: int, card_name: String, extra_data: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): 
		return

	var str_id: String = str(player_id)
	server_received_inputs[str_id] = { "card": card_name, "extra": extra_data }
	print("📥 [SERVER FUNNEL] Received P", player_id)

	# Ask the funnel if we have what we need to advance the turn
	_check_server_funnel()

	# OFFLINE FALLBACK (Sequential Turn Hand-off)
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().size() == 0:
		if player_id == 1:
			if is_player_2_human:
				# Wait slightly so the UI doesn't instantly flip jarringly
				await get_tree().create_timer(0.2).timeout
				_prepare_human_turn(2)
			else:
				_run_bot_turn(2)

func _check_server_funnel() -> void:
	var inputs_ready: bool = false
	var match_state = GameManager.state
	
	if GameManager.current_state == GameManager.State.SELECTION:
		# THE FIX: A player is ready if they sent an input OR they are locked into a card
		var p1_ready: bool = server_received_inputs.has("1") or match_state.p1_locked_card != null
		var p2_ready: bool = server_received_inputs.has("2") or match_state.p2_locked_card != null
		
		if p1_ready and p2_ready: 
			inputs_ready = true
			
	elif GameManager.current_state == GameManager.State.FEINT_CHECK:
		var p1_ready: bool = (not match_state.p1_pending_feint) or server_received_inputs.has("1")
		var p2_ready: bool = (not match_state.p2_pending_feint) or server_received_inputs.has("2")
		
		if p1_ready and p2_ready:
			inputs_ready = true
		
	if inputs_ready:
		print("🚀 [SERVER FUNNEL] Ready! Blasting to clients...")
		
		# INJECTION: Add locked cards into the payload so clients deterministically execute them
		if match_state.p1_locked_card != null and not server_received_inputs.has("1"):
			server_received_inputs["1"] = { "card": match_state.p1_locked_card.display_name, "extra": {} }
			
		if match_state.p2_locked_card != null and not server_received_inputs.has("2"):
			server_received_inputs["2"] = { "card": match_state.p2_locked_card.display_name, "extra": {} }

		# GDScript 2.0: Use Callable.rpc() instead of rpc("...")
		client_execute_turn.rpc(server_received_inputs.duplicate())
		server_received_inputs.clear()

@rpc("authority", "call_local", "reliable")
func client_execute_turn(inputs: Dictionary) -> void:
	print(">>> NETWORK SYNC: Executing Turn Data Deterministically!")

	# 1. STRICT ORDER: Always process Player 1, then Player 2. 
	# Do not trust the Dictionary keys() order!
	for p_id in [1, 2]:
		var str_id: String = str(p_id)
		
		if inputs.has(str_id):
			var data: Dictionary = inputs[str_id]
			var card_name: String = data.get("card", "")
			var extra: Dictionary = data.get("extra", {})
			
			var action: ActionData = _get_action_to_submit(p_id, card_name)
			GameManager.player_select_action(p_id, action, extra)

func _get_action_to_submit(player_id: int, card_name: String) -> ActionData:
	if card_name == "SKIP FEINT" or card_name == "": return null
	var character = p1_resource if player_id == 1 else p2_resource
	if card_name == "Struggle":
		var is_offence = (GameManager.get_attacker() == player_id)
		var type = ActionData.Type.OFFENCE if is_offence else ActionData.Type.DEFENCE
		return GameManager.get_struggle_action(type)
	return _find_card_by_name(character, card_name)

func _run_bot_turn(player_id: int):
	_current_input_player = player_id 
	var character = p1_resource if player_id == 1 else p2_resource
	
	# ... (Keep your debug force and locked card checks here) ...

	var c = _get_player_constraints(player_id)
	var card: ActionData
	
	# --- NEW: TUTORIAL BOT HIJACK ---
	if TutorialManager.is_tutorial_active and player_id == 2:
		var target_card_name = TutorialManager.get_current_data().get("bot_card", "")
		card = _find_card_by_name(character, target_card_name)
		
		# Fallback just in case the Sensei doesn't have the card
		if card == null: 
			printerr("TUTORIAL ERROR: Bot missing card " + target_card_name)
			card = GameManager.get_struggle_action(ActionData.Type.OFFENCE)
	else:
		# NORMAL AI BEHAVIOR
		card = _get_smart_card_choice(character, c.filter, c.needs_opener, c.max_cost, c.opening_stat, c.can_use_super, c.opportunity_stat)
	# --------------------------------

	print(">>> BOT P" + str(player_id) + " COMMITTED: " + card.display_name)
	server_receive_input(player_id, card.display_name, {})
	


# TestArena.gd

# TestArena.gd

func _get_smart_card_choice(character: CharacterData, type_filter: Variant, must_be_opener: bool, max_cost: int, my_opening: int, allow_super: bool, my_opportunity: int) -> ActionData:
	var valid_options: Array[ActionData] = []
	var affordable_backups: Array[ActionData] = []

	# A. FILTER VALID CARDS
	for card in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
		if card.cost > max_cost: continue
		if card.counter_value > 0 and my_opening < card.counter_value: continue
		if card.is_super and not allow_super: continue
		
		var effective_single_cost: int = max(0, card.cost - my_opportunity)
		var total_reps: int = max(1, card.repeat_count)
		var total_effective_cost: int = effective_single_cost * total_reps
		
		var can_pay: bool = (total_effective_cost <= character.current_sp)
		
		if character.can_pay_with_hp:
			if (character.current_sp + character.current_hp) > total_effective_cost:
				can_pay = true
				
		if can_pay:
			valid_options.append(card)
		elif total_effective_cost == 0:
			affordable_backups.append(card)

	# Guarantee at least one valid move (Struggle)
	var required_type: int = type_filter if type_filter != null else ActionData.Type.OFFENCE
	var struggle: ActionData = GameManager.get_struggle_action(required_type)
	valid_options.append(struggle)

	# B. DELEGATE TO MODULAR AI RESOURCE
	var best_card: ActionData = valid_options[0]
	var is_very_easy: bool = (GameManager.ai_difficulty == GameManager.Difficulty.VERY_EASY)
	var best_score: float = 99999.0 if is_very_easy else -99999.0

	var my_id: int = 1 if character == p1_resource else 2
	var opponent: CharacterData = p2_resource if my_id == 1 else p1_resource

	# Use the assigned AI profile, or assign a random preset for this match if missing
	var brain: AIBehavior = character.ai_profile
	if brain == null:
		brain = ClassFactory.pick_random_ai_profile()
		if brain == null:
			brain = preload("res://Scripts/Resources/AIBalanced.gd").new()
		character.ai_profile = brain

	# Noise Setup
	var noise_range: float = 0.0
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: noise_range = 0.0 
		GameManager.Difficulty.EASY: noise_range = 100.0
		GameManager.Difficulty.MEDIUM: noise_range = 25.0
		GameManager.Difficulty.HARD: noise_range = 2.0

	for card in valid_options:
		# --- THE DECOUPLING MAGIC ---
		var score: float = brain.score_action(card, character, opponent, my_id)
		
		score += randf_range(-noise_range, noise_range)
		
		if is_very_easy:
			if score < best_score:
				best_score = score
				best_card = card
		else:
			if score > best_score:
				best_score = score
				best_card = card

	return best_card

# 2. THE BRAIN (Assigns value to actions)


# --- LOGGING ---
func _on_game_over(winner_id: int):
	_update_visuals()
	await get_tree().create_timer(1.0).timeout
	
	var winner_data = p1_resource if winner_id == 1 else p2_resource
	
	# --- FIX: ROBUST TEXT EXTRACTION ---
	var final_log_text = "Log not found."
	
	# 1. Try to get the object
	var log_node = battle_ui.get("combat_log")
	
	if log_node:
		# 2. Try our new function (Best Case)
		if log_node.has_method("get_log_text"):
			final_log_text = log_node.get_log_text()
			
		# 3. Fallback: Check if it's a raw RichTextLabel
		elif log_node is RichTextLabel:
			final_log_text = log_node.get_parsed_text()
			
		# 4. Fallback: Check standard text property
		elif "text" in log_node:
			final_log_text = log_node.text
			
	print("TestArena: Log Text Length: " + str(final_log_text.length()))
	# -----------------------------------

	get_tree().paused = true 
	game_over_screen.setup(winner_data, final_log_text) 
	game_over_screen.visible = true
	
	
func _on_clash_resolved(winner_id: int, _p1_card: ActionData, _p2_card: ActionData, _results: Dictionary) -> void:
	print("\n>>> Clash Winner: P" + str(winner_id))
	_update_visuals()
		
func _on_log_updated(text): print("   > " + text)
func _print_status_report():
	var p1 = p1_resource; var p2 = p2_resource
	var visual = "[ "; for i in range(1, 5): visual += ("P1 " if GameManager.state.momentum == i else str(i) + " ")
	visual += "| "; for i in range(5, 9): visual += ("P2 " if GameManager.state.momentum == i else str(i) + " ")
	visual += "]"
	print("\n[STATUS] P1: " + str(p1.current_hp) + "HP/" + str(p1.current_sp) + "SP  vs  P2: " + str(p2.current_hp) + "HP/" + str(p2.current_sp) + "SP")
	print("[MOMENTUM] " + visual)

func _find_card_by_name(character: CharacterData, card_name: String) -> ActionData:
	for card in character.deck:
		if card.display_name == card_name:
			return card
	return null

func _get_button_for_card(card_name: String) -> Control:
	# Look through all buttons currently in the hand
	for btn in battle_ui.button_grid.get_children():
		# Your CardButton.gd has a 'my_action' variable or you can check btn.text
		if btn.get("my_action") and btn.my_action.display_name == card_name:
			return btn
	return null
