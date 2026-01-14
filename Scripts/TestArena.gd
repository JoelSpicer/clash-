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

@onready var battle_ui = $BattleUI
var _simulation_active: bool = true
var _current_input_player: int = 1 

func _ready():
	# 1. UI SETUP
	# Since BattleUI is already in the scene tree, we just wait for it to be ready.
	# We DO NOT instantiate() it or add_child() it again.
	
	# Wait one frame to ensure the UI's own _ready() has finished setting up nodes
	await get_tree().process_frame
	
	# Clear the log to start fresh
	if battle_ui.has_method("combat_log") and battle_ui.combat_log:
		battle_ui.combat_log.clear_log()
	elif battle_ui.get("combat_log"): # Fallback access
		battle_ui.combat_log.clear_log()
	
	# 2. LOAD PLAYER RESOURCES
	if GameManager.next_match_p1_data != null:
		p1_resource = GameManager.next_match_p1_data
		
	if GameManager.next_match_p2_data != null:
		p2_resource = GameManager.next_match_p2_data
	
	# 3. DETERMINE HUMAN/AI STATUS
	is_player_1_human = true # P1 is always human
	
	# Logic: If Arcade Mode -> AI. If Custom Mode & P2 Toggle was Human -> Human.
	if not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		is_player_2_human = true
		print("TestArena: P2 set to HUMAN")
	else:
		is_player_2_human = false
		print("TestArena: P2 set to AI")

	# 4. CONNECT SIGNALS
	# Note: We check if connections exist to avoid errors if _ready runs twice (rare but safe)
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
		GameManager.combat_log_updated.connect(_on_log_updated)
		GameManager.clash_resolved.connect(_on_clash_resolved)
		GameManager.game_over.connect(_on_game_over)
		GameManager.request_clash_animation.connect(battle_ui.play_clash_animation)
	
	if not battle_ui.human_selected_card.is_connected(_on_human_input_received):
		battle_ui.human_selected_card.connect(_on_human_input_received)
	
	# Connect Debug Toggles
	if not battle_ui.p1_mode_toggled.is_connected(_on_p1_mode_toggled):
		battle_ui.p1_mode_toggled.connect(_on_p1_mode_toggled)
		battle_ui.p2_mode_toggled.connect(_on_p2_mode_toggled)
	
	# 5. INITIALIZE UI ELEMENTS
	battle_ui.load_deck(p1_resource.deck)
	
	print("--- INITIALIZING MATCH ---")
	GameManager.start_combat(p1_resource, p2_resource)
	
	# 6. SETUP VISUALS & TOGGLES
	battle_ui.initialize_hud(p1_resource, p2_resource)
	
	# Pass the calculated booleans so the checkboxes match the game state
	battle_ui.setup_toggles(is_player_1_human, is_player_2_human)
	
	# 7. UPDATE NAME TAGS BASED ON DIFFICULTY
	var diff_suffix = ""
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: diff_suffix = " (Very Easy)"
		GameManager.Difficulty.EASY: diff_suffix = " (Easy)"
		GameManager.Difficulty.MEDIUM: diff_suffix = " (Medium)"
		GameManager.Difficulty.HARD: diff_suffix = " (Hard)"
	
	if not is_player_1_human:
		if battle_ui.p1_hud and battle_ui.p1_hud.name_label:
			battle_ui.p1_hud.name_label.text += diff_suffix
			
	if not is_player_2_human:
		if battle_ui.p2_hud and battle_ui.p2_hud.name_label:
			battle_ui.p2_hud.name_label.text += diff_suffix
	
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
	
	# --- NEW: SETUP UI TOGGLES ---
	battle_ui.setup_passive_toggles(character.class_type)
	# -----------------------------
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
		c.required_tab, character.current_sp, character.current_hp, c.needs_opener, c.max_cost, c.opening_stat,
		c.can_use_super, c.opportunity_stat, is_feinting
	)

func _on_human_input_received(card: ActionData, extra_data: Dictionary = {}): # Updated Signature
	print(">>> P" + str(_current_input_player) + " COMMITTED: " + card.display_name)
	
	var action_to_submit = card
	if card.display_name == "SKIP FEINT": action_to_submit = null
	
	# Pass the extra data (toggles) to GameManager
	GameManager.player_select_action(_current_input_player, action_to_submit, extra_data)
	
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

# TestArena.gd

# TestArena.gd

func _get_smart_card_choice(character: CharacterData, type_filter, must_be_opener: bool, max_cost: int, my_opening: int, allow_super: bool, my_opportunity: int) -> ActionData:
	var valid_options = []
	var affordable_backups = [] 
	
	# A. FILTER (Same as before)
	for card in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
		if card.cost > max_cost: continue
		if card.counter_value > 0 and my_opening < card.counter_value: continue
		if card.is_super and not allow_super: continue
		
		var effective_cost = max(0, card.cost - my_opportunity)
		var can_pay = (effective_cost <= character.current_sp)
		
		if character.class_type == CharacterData.ClassType.HEAVY:
			if (character.current_sp + character.current_hp) > effective_cost:
				can_pay = true
				
		if can_pay:
			valid_options.append(card)
		elif effective_cost == 0:
			affordable_backups.append(card)
	
	if valid_options.is_empty():
		if affordable_backups.size() > 0: return affordable_backups.pick_random()
		return character.deck[0] 

	# B. STRATEGY
	var best_card = valid_options[0]
	
	# --- NEW LOGIC START ---
	var is_very_easy = (GameManager.ai_difficulty == GameManager.Difficulty.VERY_EASY)
	
	# If Very Easy: We want the LOWEST score, so start High.
	# If Normal: We want the HIGHEST score, so start Low.
	var best_score = 99999.0 if is_very_easy else -99999.0
	
	var my_id = 1 if character == p1_resource else 2
	var opponent = p2_resource if my_id == 1 else p1_resource
	
	# Noise Setup
	var noise_range = 0.0
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: noise_range = 0.0 # No noise, just pure bad decisions
		GameManager.Difficulty.EASY: noise_range = 100.0
		GameManager.Difficulty.MEDIUM: noise_range = 25.0
		GameManager.Difficulty.HARD: noise_range = 2.0
	
	for card in valid_options:
		var score = _score_card_utility(card, character, opponent, my_id)
		score += randf_range(-noise_range, noise_range)
		
		if is_very_easy:
			# INVERTED LOGIC: Pick the WORST score
			if score < best_score:
				best_score = score
				best_card = card
		else:
			# STANDARD LOGIC: Pick the BEST score
			if score > best_score:
				best_score = score
				best_card = card
	
	return best_card

# 2. THE BRAIN (Assigns value to actions)
func _score_card_utility(card: ActionData, me: CharacterData, opp: CharacterData, my_id: int) -> float:
	var score = 0.0
	
	# --- 1. KILL INSTINCT ---
	# If this card kills the opponent, prioritize it above all else!
	if card.damage >= opp.current_hp:
		score += 1000.0
		
	# --- 2. SURVIVAL INSTINCT ---
	# If I am dying (HP < 4), prioritize staying alive
	if me.current_hp < 4:
		score += card.block_value * 10
		score += card.heal_value * 15
		score += card.dodge_value * 10
		if card.type == ActionData.Type.DEFENCE: score += 20
		
	# --- 3. MOMENTUM STRATEGY ---
	var mom = GameManager.momentum
	# Helper: "My Side" is 1-4 for P1, 5-8 for P2.
	var winning_momentum = (my_id == 1 and mom <= 3) or (my_id == 2 and mom >= 6)
	var losing_momentum = (my_id == 1 and mom >= 5) or (my_id == 2 and mom <= 4)
	
	if winning_momentum:
		# PRESS THE ADVANTAGE: Value Damage and Momentum Gain
		score += card.damage * 10
		score += card.momentum_gain * 5
		if card.type == ActionData.Type.OFFENCE: score += 10
	
	elif losing_momentum:
		# TURN THE TIDE: Value Reversals, Parries, and Pushback
		if card.reversal: score += 50
		if card.is_parry: score += 40
		score += card.fall_back_value * 8
		score += card.block_value * 5 # Play safe
		
	# --- 4. TACTICAL COMBOS ---
	# If I have a combo opening (e.g., Opponent is off-balance), use Counters!
	var my_opening = GameManager.p1_opening_stat if my_id == 1 else GameManager.p2_opening_stat
	if my_opening > 0:
		# If this card takes advantage of the opening, boost it
		if card.counter_value > 0 and card.counter_value <= my_opening:
			score += 40
			
	# --- 5. CLASS SPECIFIC BIAS ---
	match me.class_type:
		CharacterData.ClassType.HEAVY:
			score += card.damage * 5 # Loves damage
			score += card.block_value * 5 # Loves blocking
		CharacterData.ClassType.PATIENT:
			score += card.recover_value * 5 # Loves recovery
			if card.is_parry: score += 10 # love parry
		CharacterData.ClassType.QUICK:
			if card.cost <= 1: score += 10 # Loves cheap cards
			score += card.dodge_value * 5 #love dodge
		CharacterData.ClassType.TECHNICAL:
			if card.reversal: score += 10 #loves reversal
			score += card.tiring * 5
			if card.create_opening: score += 10
			
	# --- 6. COST EFFICIENCY ---
	# Don't spend all SP unless necessary
	if card.cost > 0:
		var sp_ratio = float(me.current_sp) / float(me.max_sp)
		if sp_ratio < 0.3: 
			# Low SP? Penalize expensive cards heavily
			score -= card.cost * 15
	
	return score

# --- LOGGING ---
func _on_game_over(winner_id):
	print("\n*** VICTORY FOR PLAYER " + str(winner_id) + "! ***")
	if stop_on_game_over: _simulation_active = false
	
	# 1. Wait a moment for the final hit impact to register visually
	await get_tree().create_timer(1.5).timeout
	
	# 2. Lock UI so no more cards can be clicked
	if battle_ui:
		battle_ui.lock_ui()
	
	# 3. Spawn Game Over Screen
	var screen = game_over_scene.instantiate()
	# Add to CanvasLayer (BattleUI) so it draws on top of everything, 
	# or add to self if you want it part of the world. 
	# Adding to BattleUI is usually safer for Z-index.
	battle_ui.add_child(screen) 
	screen.setup(winner_id)
	
	
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
