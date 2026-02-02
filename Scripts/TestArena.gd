extends Node2D

@export_group("Setup")
@export var p1_resource: CharacterData
@export var p2_resource: CharacterData
@export var stop_on_game_over: bool = true 

@export_group("Debug Controls")
@export var is_player_1_human: bool = true 
@export var is_player_2_human: bool = false 
@export var p2_debug_force_card: ActionData 

# AI Memory System
var p2_last_action_name: String = "" 
var p1_last_action_type = null # Store ActionData.Type (0 or 1)
var p1_last_cost: int = 0      # Track if player is tired

# NEW: Preload the Game Over Screen
var game_over_scene = preload("res://Scenes/GameOverScreen.tscn")
var game_over_screen

@onready var battle_ui = $BattleUI
var _simulation_active: bool = true
var _current_input_player: int = 1 

func _ready():
# --- FIX: SPAWN GAME OVER SCREEN ON A TOP LAYER ---
	var go_layer = CanvasLayer.new()
	go_layer.layer = 100 # Put it above everything else
	add_child(go_layer)
	
	game_over_screen = game_over_scene.instantiate()
	game_over_screen.visible = false
	game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS # Keep buttons active
	go_layer.add_child(game_over_screen)
	# ------------------------------------------------------
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
	# This function asks GameManager who is attacking. 
	# Now that we fixed 'get_attacker', this will return the correct ID!
	var attacker_id = GameManager.get_attacker()
	var is_combo = (GameManager.current_combo_attacker != 0)
	var mom = GameManager.momentum
	
	var c = {
		"filter": null, "required_tab": null, "needs_opener": false,
		"max_cost": 99, "opening_stat": 0, "can_use_super": false, "opportunity_stat": 0 
	}
	
	# 1. Setup Limits & Stats
	if player_id == 1:
		c.max_cost = GameManager.p1_cost_limit
		c.opening_stat = GameManager.p1_opening_stat
		c.opportunity_stat = GameManager.p1_opportunity_stat 
		
		# SUPER CHECK (Updated for Dynamic Momentum)
		# Checks if momentum is at P1's Wall (e.g. 1)
		if mom == GameManager.get_wall_momentum(1) and not p1_resource.has_used_super:
			c.can_use_super = true
			
		if GameManager.p1_must_opener: c.needs_opener = true
	else:
		c.max_cost = GameManager.p2_cost_limit
		c.opening_stat = GameManager.p2_opening_stat
		c.opportunity_stat = GameManager.p2_opportunity_stat 
		
		# SUPER CHECK (Updated for Dynamic Momentum)
		# Checks if momentum is at P2's Wall (e.g. 8 or 12)
		if mom == GameManager.get_wall_momentum(2) and not p2_resource.has_used_super:
			c.can_use_super = true
			
		if GameManager.p2_must_opener: c.needs_opener = true

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
	
	# --- FIX: ADD STRUGGLE OPTION ---
	# If the bot is filtering for a specific type (e.g. Defence), give it the Struggle option for that type.
	var required_type = type_filter if type_filter != null else ActionData.Type.OFFENCE
	var struggle = GameManager.get_struggle_action(required_type)
	
	# If we have NO valid deck options, or if we just want to consider saving SP, add Struggle.
	# Adding it to 'valid_options' lets the Scoring System decide if it's a good idea.
	valid_options.append(struggle)
	# --------------------------------
	
	if valid_options.is_empty():
		return struggle 

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
		GameManager.Difficulty.VERY_EASY: noise_range = 0 # No noise, just pure bad decisions
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
	var log_parts = [] # Stores reasons like "+10 Dmg" or "-100 Repetition"
	
	# Weights
	var w_dmg = 1.0; var w_def = 1.0; var w_tech = 1.0; var w_cost = 1.0
	
	match me.ai_archetype:
		CharacterData.AIArchetype.AGGRESSIVE:
			w_dmg = 1.5; w_def = 0.5; w_cost = 0.5
		CharacterData.AIArchetype.DEFENSIVE:
			w_dmg = 0.7; w_def = 1.5; w_cost = 1.2
		CharacterData.AIArchetype.TRICKSTER:
			w_dmg = 0.8; w_def = 0.8; w_tech = 1.5
	
	# --- 1. STRICT ANTI-REPETITION ---
	if card.display_name == p2_last_action_name:
		if GameManager.ai_difficulty == GameManager.Difficulty.VERY_EASY:
			# [cite_start]FIX: For Very Easy, we pick the LOWEST score[cite: 220].
			# To discourage repetition, we must ADD to the score so it isn't the lowest.
			score += 100.0
			log_parts.append("+100 (Repetition Avoidance)")
		else:
			# Normal Logic: We pick the HIGHEST score.
			# Subtracting makes the AI avoid it.
			score -= 100.0
			log_parts.append("-100 (Repetition)")

	# --- 2. TACTICAL RESPONSE ---
	if card.type == ActionData.Type.OFFENCE:
		# Counter Opportunities
		var opp_opening = GameManager.p1_opening_stat if my_id == 2 else GameManager.p2_opening_stat
		if opp_opening > 0 and card.counter_value > 0 and card.counter_value <= opp_opening:
			var val = 50.0 * w_tech
			score += val
			log_parts.append("+" + str(val) + " (Counter Opportunity)")
		
		# Punish Tired
		if p1_last_cost >= 2 or (float(opp.current_sp)/max(1, opp.max_sp) < 0.3):
			var val = card.damage * 5 * w_dmg
			score += val
			log_parts.append("+" + str(val) + " (Punish Tired)")
		
		# Break Turtles
		if p1_last_action_type == ActionData.Type.DEFENCE:
			if card.guard_break: 
				score += 30 * w_tech
				log_parts.append("+30 (Guard Break)")
			if card.feint: 
				score += 20 * w_tech
				log_parts.append("+20 (Feint vs Block)")
			
	elif card.type == ActionData.Type.DEFENCE:
		# Heavy Incoming
		if p1_last_cost >= 2:
			if card.dodge_value > 0: 
				score += 20 * w_def
				log_parts.append("+20 (Dodge Heavy)")
			if card.block_value >= 4: 
				score += 15 * w_def
				log_parts.append("+15 (Block Heavy)")
			
		# Light Incoming
		elif p1_last_cost <= 1:
			if card.cost >= 2: 
				var pen = 15.0 * w_cost
				score -= pen
				log_parts.append("-" + str(pen) + " (Overkill Def)")
			if card.block_value > 0 and card.cost <= 1: 
				score += 10 * w_def
				log_parts.append("+10 (Efficient Block)")

		# Fishing for Reversals
		if opp.current_hp <= 5 and card.reversal:
			score += 15 * w_tech
			log_parts.append("+15 (Execute Reversal)")

	# --- 3. UTILITY SCORING ---
	
	# Kill Instinct
	if card.damage >= opp.current_hp: 
		score += 1000.0
		log_parts.append("+1000 (KILL SHOT)")
	
	# Survival Instinct
	var panic = 5 if me.ai_archetype == CharacterData.AIArchetype.DEFENSIVE else 3
	if me.current_hp < panic:
		var s_val = (card.block_value * 10 * w_def) + (card.heal_value * 15 * w_def)
		if card.type == ActionData.Type.DEFENCE: s_val += 20 * w_def
		score += s_val
		if s_val > 0: log_parts.append("+" + str(s_val) + " (Panic Mode)")
	
	# Logic for Struggle (display_name check)
	if card.display_name == "Struggle":
		# If we are low on SP, Struggle is very valuable
		if me.current_sp <= 1:
			score += 50.0
			log_parts.append("+50 (Need SP)")
		# If we are full on SP, Struggle is bad
		elif me.current_sp >= me.max_sp:
			score -= 50.0
			log_parts.append("-50 (SP Full)")
	
	# Momentum Logic
	var mom = GameManager.momentum
	var winning = (my_id == 1 and mom <= 3) or (my_id == 2 and mom >= 6)
	var losing = (my_id == 1 and mom >= 5) or (my_id == 2 and mom <= 4)
	
	if winning:
		var m_val = (card.damage * 10 * w_dmg)
		if card.type == ActionData.Type.OFFENCE: m_val += 10
		score += m_val
		if m_val > 0: log_parts.append("+" + str(m_val) + " (Winning Mom)")
	elif losing:
		var m_val = (card.fall_back_value * 10 * w_def) + (card.block_value * 5 * w_def)
		if card.reversal: m_val += 20 * w_tech
		score += m_val
		if m_val > 0: log_parts.append("+" + str(m_val) + " (Losing Mom)")

	# Base Stats
	var stat_score = (card.damage * 5 * w_dmg) + (card.block_value * 5 * w_def) + (card.heal_value * 5 * w_def)
	
	if card.tiring > 0: stat_score += card.tiring * 5 * w_tech
	if card.create_opening > 0: stat_score += card.create_opening * 5 * w_tech
	if card.feint: stat_score += 10 * w_tech
	
	score += stat_score
	log_parts.append("+" + str(stat_score) + " (Stats)")
	
	# Cost Efficiency
	if card.cost > 0:
		var sp_ratio = float(me.current_sp) / float(max(1, me.max_sp))
		var scarcity = 1.0 if sp_ratio > 0.5 else 2.5
		var c_pen = card.cost * (10 * w_cost * scarcity)
		score -= c_pen
		log_parts.append("-" + str(c_pen) + " (Cost)")

	# --- PRINT LOG ---
	# Format: [AI] CardName: 45.0 | Breakdown: +20 (Stats), -5 (Cost), +30 (Counter)
	print("[AI] %s: %s | %s" % [card.display_name, str(snapped(score, 0.1)), ", ".join(log_parts)])

	return score

# --- LOGGING ---
func _on_game_over(winner_id: int):
	# 1. Force one final visual update so the HP bar shows 0
	_update_visuals()
	
	# 2. Wait 1 second so the player can see the final hit land
	await get_tree().create_timer(1.0).timeout
	
	# 3. Determine which DATA OBJECT belongs to the winner
	var winner_data: CharacterData
	if winner_id == 1:
		winner_data = p1_resource
	else:
		winner_data = p2_resource
	
	# 4. Now we pause and show the screen, passing the OBJECT, not the ID
	get_tree().paused = true 
	game_over_screen.setup(winner_data) # <--- This was the fix
	game_over_screen.visible = true
	
	
func _on_clash_resolved(winner_id, p1_card, p2_card, _results): 
	print("\n>>> Clash Winner: P" + str(winner_id))
	_update_visuals()
	# --- UPDATE AI MEMORY ---
	if not is_player_2_human:
		# 1. Remember what the Bot did (for anti-repetition)
		if p2_card != null:
			p2_last_action_name = p2_card.display_name
			
		# 2. Remember what the Human did (for counter-play)
		if p1_card != null:
			p1_last_action_type = p1_card.type
			p1_last_cost = p1_card.cost
			
			# Reset if Human did nothing (stunned/empty)
		else:
			p1_last_action_type = null
			p1_last_cost = 0
		
func _on_log_updated(text): print("   > " + text)
func _print_status_report():
	var p1 = p1_resource; var p2 = p2_resource
	var visual = "[ "; for i in range(1, 5): visual += ("P1 " if GameManager.momentum == i else str(i) + " ")
	visual += "| "; for i in range(5, 9): visual += ("P2 " if GameManager.momentum == i else str(i) + " ")
	visual += "]"
	print("\n[STATUS] P1: " + str(p1.current_hp) + "HP/" + str(p1.current_sp) + "SP  vs  P2: " + str(p2.current_hp) + "HP/" + str(p2.current_sp) + "SP")
	print("[MOMENTUM] " + visual)
