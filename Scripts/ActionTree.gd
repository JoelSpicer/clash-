extends Control

var action_tree_dict = {}     # Empty placeholder
var id_to_name = {}
var name_to_id = {}

const NODE_QUICK = 73
const NODE_TECHNICAL = 74
const NODE_PATIENT = 75
const NODE_HEAVY = 76

# --- SCENE REFS ---
@onready var nodes_layer = %NodesLayer
@onready var lines_layer = %LinesLayer

# --- STATE ---
var unlocked_ids: Array[int] = []
var owned_ids: Array[int] = []
var selected_class_id: int = 0
var is_class_locked: bool = false
var pending_unlock_id: int = 0 # Track the ONE card the player wants to pick
# --- NEW: STATS TRACKING ---
var current_max_hp: int = 10
var current_max_sp: int = 3
var stats_label: Label 

# --- NEW: POPUP REFERENCES ---
var card_scene = preload("res://Scenes/CardDisplay.tscn")
var popup_card: Control

func _ready():
	action_tree_dict = ClassFactory.TREE_CONNECTIONS
	id_to_name = ClassFactory.ID_TO_NAME_MAP
	
	# Build a reverse lookup (Name -> ID) for Presets to use
	name_to_id.clear()
	for id in id_to_name:
		name_to_id[id_to_name[id]] = id
	
	# 2. Setup Nodes
	for child in nodes_layer.get_children():
		if child.has_method("setup"):
			var id = int(str(child.name)) 
			var a_name = id_to_name.get(id, "Unknown")
			child.setup(id, a_name)
			child.action_clicked.connect(_on_node_clicked)
			child.hovered.connect(_on_node_hovered) # <--- ADD THIS
			child.exited.connect(_on_node_exited)
	# 3. Create Stats Label UI
	stats_label = Label.new()
	stats_label.text = "HP: 10 | SP: 3"
	stats_label.add_theme_font_size_override("font_size", 32)
	stats_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stats_label.position.y += 20 # Offset from top
	add_child(stats_label)
	
	if RunManager.is_arcade_mode:
		print("ActionTree: Loading Arcade Run Data...")
		
		# A. Load state from RunManager instead of GameManager temp vars
		# We clone the list so we don't accidentally modify the 'real' list until confirmed
		owned_ids = RunManager.player_owned_tree_ids.duplicate()
		
		# The first node in the list is always the Class Node (73-76)
		if owned_ids.size() > 0:
			selected_class_id = owned_ids[0] 
		
		# B. Lock the UI 'Back' button so they can't leave without picking
		var btn_back = $TreeContainer/BackButton
		if btn_back: btn_back.visible = false 
		
		# C. Change the Confirm button text
		var btn_confirm = $TreeContainer/ConfirmButton 
		if btn_confirm:
			if RunManager.free_unlocks_remaining > 0:
				btn_confirm.text = "PICK (" + str(RunManager.free_unlocks_remaining) + " LEFT)"
			else:
				btn_confirm.text = "UNLOCK & FIGHT"
		
		# D. Calculate unlocks based on what we already own
		_unlock_neighbors(selected_class_id)
		for oid in owned_ids: 
			_unlock_neighbors(oid)
	else:
		_setup_for_current_player()
		var btn_back = $TreeContainer/BackButton
		if btn_back:
			btn_back.pressed.connect(_on_back_button_pressed)
		
	
	
	# 4. --- NEW: CREATE POPUP CARD ---
	var canvas = CanvasLayer.new() # Use CanvasLayer to float above everything
	canvas.layer = 100
	add_child(canvas)
	
	popup_card = card_scene.instantiate()
	popup_card.visible = false
	# --- FIX START: FORCE SIZE AND SHAPE ---
	# 1. Stop it from stretching to fill the screen (Reset Anchors)
	popup_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	
	# 2. Force it to the correct standard card size
	# (Matching custom_minimum_size from CardDisplay.tscn)
	popup_card.size = Vector2(250, 350) 
	
	# 3. Set Scale (1.0 is standard size, adjust if you want it smaller/larger)
	popup_card.scale = Vector2(0.6, 0.6) 
	# ---------------------------------------rger
	popup_card.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block mouse
	canvas.add_child(popup_card)

	
	_update_tree_visuals()
	_recalculate_stats() # Initial calc
	lines_layer.queue_redraw()

func _on_node_hovered(id, a_name):
	
	# --- NEW: DETECT CLASS NODES (73-76) ---
	if id >= 73 and id <= 76:
		var class_info = _get_class_display_data(id)
		popup_card.set_card_data(class_info)
		
		# Optional: Hide the "0 SP" cost label if you want (requires CardDisplay tweaks), 
		# but for now we just show the info.
		
		popup_card.visible = true
		_update_popup_position()
		return
	# ---------------------------------------

	# Standard Action Node Logic (Existing Code)
	# 1. Try to load the real file
	var res = ClassFactory.find_action_resource(a_name)
	
	# 2. If missing, create a "Dummy" card so the UI still works
	if res == null:
		print("Debug: File missing for '" + a_name + "'") # Console check
		res = ActionData.new()
		res.display_name = a_name
		res.description = "(File not created yet)"
		res.type = ActionData.Type.OFFENCE # Default color
		res.cost = 0
	
	
# --- CHANGE 2: USE THE CORRECT METHOD FOR THE FULL CARD ---
	# In BattleUI, you use 'set_card_data(card, cost)' for the preview card.
	# We replicate that here.
	if popup_card.has_method("set_card_data"):
		popup_card.set_card_data(res, res.cost)
	elif popup_card.has_method("setup"):
		# Fallback in case your card script uses 'setup' instead
		popup_card.setup(res)
		
	popup_card.visible = true
	_update_popup_position()

# ActionTree.gd

func _setup_for_current_player():
	# 1. Determine which class/preset to load
	var target_selection = 0
	var player_name = ""
	var target_preset = null # <--- New variable
	
	if GameManager.editing_player_index == 1:
		target_selection = GameManager.get("temp_p1_class_selection")
		target_preset = GameManager.get("temp_p1_preset") # Get P1 Preset
		player_name = "PLAYER 1"
	else:
		target_selection = GameManager.get("temp_p2_class_selection")
		target_preset = GameManager.get("temp_p2_preset") # Get P2 Preset
		player_name = "PLAYER 2"
		
	print("Building Loadout for: " + player_name) 
	
	# 3. Reset Tree State
	owned_ids.clear()
	unlocked_ids.clear()
	is_class_locked = false
	
	# 4. Select the Class Node (Resets the tree to base class state)
	if target_selection != null:
		var node_id = 0
		match target_selection:
			0: node_id = 76 # Heavy
			1: node_id = 75 # Patient
			2: node_id = 73 # Quick
			3: node_id = 74 # Technical
			
		if node_id != 0:
			_select_class(node_id)
			is_class_locked = true 
	
	# --- NEW: PRE-FILL PRESET MOVES ---
	if target_preset != null:
		print("Applying Preset Skills: ", target_preset.extra_skills)
		
		for skill_name in target_preset.extra_skills:
			# FIX: Use 'name_to_id' instead of the deleted 'action_tree_key_dict'
			if skill_name in name_to_id:
				var id = name_to_id[skill_name]
				
				# Add to owned if not already there
				if id not in owned_ids:
					owned_ids.append(id)
			else:
				printerr("Warning: Preset skill '" + skill_name + "' not found.")
		
		# IMPORTANT: Now that we forced nodes into 'owned_ids', 
		# we must re-run the unlock logic so their neighbors turn yellow.
		for owner_id in owned_ids:
			_unlock_neighbors(owner_id)
	# ----------------------------------
			
	# 5. Refresh Visuals
	_update_tree_visuals()
	_recalculate_stats()
	lines_layer.queue_redraw()

func _on_node_exited():
	popup_card.visible = false

func _process(_delta):
	if popup_card.visible:
		_update_popup_position()

func _update_popup_position():
	var m_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	
	# Calculate actual size including scale (just in case you scale it later)
	var card_size = popup_card.size * popup_card.scale
	var offset = Vector2(30, 30)
	
	# 1. Default Position: Bottom-Right of mouse
	var final_pos = m_pos + offset
	
	# 2. Check Horizontal Bounds (Right Edge)
	if final_pos.x + card_size.x > screen_size.x:
		# If it goes off right, flip to the LEFT of the mouse
		final_pos.x = m_pos.x - card_size.x - offset.x
	
	# 3. Check Vertical Bounds (Bottom Edge)
	if final_pos.y + card_size.y > screen_size.y:
		# If it goes off bottom, flip to ABOVE the mouse
		final_pos.y = m_pos.y - card_size.y - offset.y
	
	popup_card.position = final_pos

func _on_node_clicked(id: int, _name: String):
	if RunManager.is_arcade_mode:
		# Rule 1: You can't un-learn skills you already have
		if id in owned_ids: 
			return 
			
		# Rule 2: You can only pick yellow (unlocked) nodes
		if id not in unlocked_ids: 
			return 
		
		# Rule 3: Set this as the "Pending Reward"
		pending_unlock_id = id
		print("Selected reward candidate: " + str(id))
		
		# Visual Feedback: Show what stats this NEW card would give
		# We create a fake deck consisting of (Current Deck + New Card)
		var temp_deck = RunManager.player_run_data.deck.duplicate()
		var card_name = id_to_name.get(id)
		var new_card = ClassFactory.find_action_resource(card_name)
		
		if new_card:
			temp_deck.append(new_card)
			# Ask Factory to calculate stats for this potential future
			var result = ClassFactory.calculate_stats_for_deck(RunManager.player_run_data.class_type, temp_deck)
			
			stats_label.text = "NEXT FIGHT STATS: HP " + str(result["hp"]) + " | SP " + str(result["sp"])
			stats_label.modulate = Color.GREEN # Make it look like a preview
			
			# Update visuals to show the glow on the new selection
		_update_tree_visuals()
		
		# --- CRITICAL FIX: STOP HERE! ---
		return
	
	if id >= 73 and id <= 76:
		if is_class_locked: return
		_select_class(id)
		return
		
	if id in owned_ids:
		# If we click an OWNED node, try to refund it
		_try_deselect_action(id)
	elif id in unlocked_ids:
		owned_ids.append(id)
		_unlock_neighbors(id)
		_update_tree_visuals()
		_recalculate_stats() # <--- Update stats when buying
	else:
		print("Locked!")

func _select_class(class_id: int):
	selected_class_id = class_id
	owned_ids.clear()
	unlocked_ids.clear()
	owned_ids.append(class_id)
	_unlock_neighbors(class_id)
	_update_tree_visuals()
	_recalculate_stats() # <--- Update stats when resetting

# --- NEW: STATS CALCULATION LOGIC ---
func _recalculate_stats():
	# Default display if nothing selected
	if selected_class_id == 0:
		stats_label.text = "HP: 10 | SP: 3"
		return

	# 1. Convert the Tree's "Node ID" (73-76) into a proper "Class Enum"
	var class_enum = CharacterData.ClassType.HEAVY # Default
	match selected_class_id:
		73: class_enum = CharacterData.ClassType.QUICK
		74: class_enum = CharacterData.ClassType.TECHNICAL
		75: class_enum = CharacterData.ClassType.PATIENT
		76: class_enum = CharacterData.ClassType.HEAVY

	# 2. Build a temporary deck from the nodes we own
	var temp_deck: Array[ActionData] = []
	
	# Add the base starter cards for this class (so the calculator knows to ignore them properly)
	# Note: ClassFactory.get_starting_deck returns resources, which is what we need.
	temp_deck.append_array(ClassFactory.get_starting_deck(class_enum))
	
	# Add the extra cards we bought in the tree
	for id in owned_ids:
		if id >= 73: continue # Skip class nodes
		
		var a_name = id_to_name.get(id)
		var card = ClassFactory.find_action_resource(a_name)
		if card:
			temp_deck.append(card)
	
	# 3. ASK THE FACTORY: "If I had this deck, what would my stats be?"
	var result = ClassFactory.calculate_stats_for_deck(class_enum, temp_deck)
	
	# 4. Update UI
	current_max_hp = result["hp"]
	current_max_sp = result["sp"]
	stats_label.text = "HP: " + str(current_max_hp) + " | SP: " + str(current_max_sp)

func _unlock_neighbors(node_id: int):
	if node_id in action_tree_dict:
		for neighbor_id in action_tree_dict[node_id]:
			if neighbor_id not in unlocked_ids and neighbor_id not in owned_ids:
				unlocked_ids.append(neighbor_id)

func _update_tree_visuals():
	for child in nodes_layer.get_children():
		var id = int(str(child.name))
		
		if id in owned_ids:
			child.set_status(2) 
		elif id in unlocked_ids:
			child.set_status(1) 
		else:
			child.set_status(0) 
			
		# NEW: Highlight the pending selection
		if RunManager.is_arcade_mode and id == pending_unlock_id:
			child.modulate = Color(1.5, 1.5, 1.5) # Make it glow bright
		else:
			child.modulate = Color.WHITE # Reset
			
		if id >= 73 and id <= 76:
			child.set_status(1)
			if id == selected_class_id: child.set_status(2)

func _on_confirm_button_pressed():
	# ==========================================================
	# 1. ARCADE / RUN MODE
	# ==========================================================
	if RunManager.is_arcade_mode:
		
		# --- PHASE A: DRAFTING (Shopping Spree) ---
		if RunManager.free_unlocks_remaining > 0:
			if pending_unlock_id == 0:
				print("Please select a free card to unlock!")
				return
				
			print("Drafting Card: " + str(pending_unlock_id))
			
			# 1. Commit the Reward
			RunManager.player_owned_tree_ids.append(pending_unlock_id)
			owned_ids.append(pending_unlock_id)
			
			# 2. Add to Deck
			var card_name = id_to_name.get(pending_unlock_id)
			var new_card = ClassFactory.find_action_resource(card_name)
			if new_card:
				RunManager.player_run_data.deck.append(new_card)
				
			# 3. Update Stats & Tree
			ClassFactory._recalculate_stats(RunManager.player_run_data)
			_unlock_neighbors(pending_unlock_id)
			
			# 4. Decrement Counter
			RunManager.free_unlocks_remaining -= 1
			pending_unlock_id = 0 
			
			# --- THE FIX: START IMMEDIATELY ON FINISH ---
			if RunManager.free_unlocks_remaining <= 0:
				print("Draft Complete! Launching Fight...")
				RunManager.start_next_fight()
				return
			# --------------------------------------------
			
			# 5. If we still have picks left, refresh the screen
			_update_tree_visuals()
			_recalculate_stats()
			lines_layer.queue_redraw()
			
			var btn_confirm = $TreeContainer/ConfirmButton
			btn_confirm.text = "PICK (" + str(RunManager.free_unlocks_remaining) + " LEFT)"
				
			return 
			
		# --- PHASE B: NORMAL LEVEL REWARD (Level 2+) ---
		if pending_unlock_id != 0:
			print("Committing Level Reward: " + str(pending_unlock_id))
			RunManager.player_owned_tree_ids.append(pending_unlock_id)
			
			var card_name = id_to_name.get(pending_unlock_id)
			var new_card = ClassFactory.find_action_resource(card_name)
			if new_card:
				RunManager.player_run_data.deck.append(new_card)
			
			ClassFactory._recalculate_stats(RunManager.player_run_data)
			
			# Full Heal on Level Up
			RunManager.player_run_data.current_hp = RunManager.player_run_data.max_hp
			RunManager.player_run_data.current_sp = RunManager.player_run_data.max_sp
			
			RunManager.start_next_fight()
			return
		else:
			print("Please select a new skill first!")
			return

	# ==========================================================
	# 2. CUSTOM DECK CREATOR (Main Menu Mode)
	# ==========================================================
	if selected_class_id == 0:
		print("Please select a Class first!")
		return

	var final_character = CharacterData.new()
	match selected_class_id:
		73: final_character.class_type = CharacterData.ClassType.QUICK
		74: final_character.class_type = CharacterData.ClassType.TECHNICAL
		75: final_character.class_type = CharacterData.ClassType.PATIENT
		76: final_character.class_type = CharacterData.ClassType.HEAVY

	var base_deck = ClassFactory.get_starting_deck(final_character.class_type)
	var final_deck: Array[ActionData] = []
	final_deck.append_array(base_deck)
	
	for id in owned_ids:
		if id >= 73: continue 
		var a_name = id_to_name.get(id)
		var card_resource = ClassFactory.find_action_resource(a_name)
		if card_resource:
			final_deck.append(card_resource)
			
	final_character.deck = final_deck
	final_character.max_hp = current_max_hp
	final_character.max_sp = current_max_sp
	final_character.reset_stats()
	
	if GameManager.editing_player_index == 1:
		var p1_name = GameManager.get("temp_p1_name")
		final_character.character_name = p1_name if p1_name != "" else "Player 1"
		GameManager.next_match_p1_data = final_character
		
		if GameManager.p2_is_custom:
			GameManager.editing_player_index = 2
			_setup_for_current_player()
			return 
	else:
		var p2_name = GameManager.get("temp_p2_name")
		final_character.character_name = p2_name if p2_name != "" else "Player 2"
		GameManager.next_match_p2_data = final_character

	if GameManager.next_match_p2_data == null:
		GameManager.next_match_p2_data = ClassFactory.create_character(CharacterData.ClassType.HEAVY, "Bot")
		
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func _try_deselect_action(id_to_remove: int):
	# 1. Create a hypothetical list of what ownership looks like AFTER removal
	var remaining_ids = owned_ids.duplicate()
	remaining_ids.erase(id_to_remove)
	
	# 2. FLOOD FILL: Check if we can reach every remaining node starting from the Class Node
	var reachable_count = 0
	var queue: Array[int] = [selected_class_id]
	var visited = {selected_class_id: true}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		# If this node is in our remaining list, we count it as "Safe and Connected"
		if current in remaining_ids:
			reachable_count += 1
		
		# Add neighbors to queue
		if current in action_tree_dict:
			for neighbor in action_tree_dict[current]:
				# Only traverse to nodes we actually OWN (in the remaining list)
				# and haven't visited yet
				if neighbor in remaining_ids and not neighbor in visited:
					visited[neighbor] = true
					queue.append(neighbor)
	
	# 3. VERDICT: Did we find everyone?
	# If the BFS found fewer nodes than we own, it means some nodes got cut off.
	if reachable_count < remaining_ids.size():
		print("Cannot deselect: This action connects to others you own!")
		return

	# 4. SUCCESS: Commit the removal
	owned_ids.erase(id_to_remove)
	
	# 5. Rebuild "Available" (Yellow) list from scratch
	unlocked_ids.clear()
	for owner_id in owned_ids:
		_unlock_neighbors(owner_id)
		
	# 6. Update Visuals & Stats
	_update_tree_visuals()
	_recalculate_stats()

func _on_reset_button_pressed():
	if selected_class_id == 0: return
	
	# 1. Clear everything
	owned_ids.clear()
	unlocked_ids.clear()
	
	# 2. Re-add the Class Node
	owned_ids.append(selected_class_id)
	
	# 3. Recalculate unlocks from the root
	_unlock_neighbors(selected_class_id)
	
	# 4. Update UI
	_update_tree_visuals()
	_recalculate_stats()

func _get_class_display_data(id: int) -> ActionData:
	var data = ActionData.new()
	data.cost = 0 # Classes don't have a cost
	
	match id:
		76: # HEAVY
			data.display_name = "CLASS: HEAVY"
			data.type = ActionData.Type.OFFENCE # Red Theme
			data.description = "[b]Action: Haymaker[/b]\nOpener, Cost 3, Dmg 2, Mom 3\n" + \
			"[b]Action: Elbow Block[/b]\nBlock 1, Cost 2, Dmg 1\n" + \
			"[b]Passive: Rage[/b]\nPay HP instead of SP when low.\n" + \
			"[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 SP, [color=#99ccff]Defence:[/color] +2 HP\n" + \
			"[b]Speed:[/b] 1"

		75: # PATIENT
			data.display_name = "CLASS: PATIENT"
			data.type = ActionData.Type.DEFENCE # Blue Theme
			data.description = "[b]Action: Preparation[/b]\nFall Back 2, Opp 1, Reco 1\n" + \
			"[b]Action: Counter Strike[/b]\nDmg 2, Fall Back 2, Parry\n" + \
			"[b]Passive: Keep-up[/b]\nSpend SP to prevent Fall Back.\n" + \
			"[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 HP, [color=#99ccff]Defence:[/color] +1 HP/SP\n" + \
			"[b]Speed:[/b] 2"

		73: # QUICK
			data.display_name = "CLASS: QUICK"
			data.type = ActionData.Type.OFFENCE
			data.description = "[b]Action: Roll Punch[/b]\nDmg 1, Cost 1, Mom 1, Rep 3\n" + \
			"[b]Action: Weave[/b]\nDodge 1, Fall Back 1\n" + \
			"[b]Passive: Relentless[/b]\nEvery 3rd combo hit gains Reco 1.\n" + \
			"[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 HP, [color=#99ccff]Defence:[/color] +2 SP\n" + \
			"[b]Speed:[/b] 4"

		74: # TECHNICAL
			data.display_name = "CLASS: TECHNICAL"
			data.type = ActionData.Type.DEFENCE
			data.description = "[b]Action: Discombobulate[/b]\nCost 1, Dmg 1, Tiring 1\n" + \
			"[b]Action: Hand Catch[/b]\nBlock 1, Cost 1, Reversal\n" + \
			"[b]Passive: Technique[/b]\nSpend 1 SP to add Opener, Tiring, or Momentum to action.\n" + \
			"[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 SP/HP, [color=#99ccff]Defence:[/color] +1 SP\n" + \
			"[b]Speed:[/b] 3"
			
	return data

func _on_back_button_pressed():
	print("Canceling customization...")
	
	# 1. CLEANUP: Wipe temporary data in GameManager
	# This ensures the next time you click "Quick Fight" or "Build Deck",
	# it starts fresh instead of remembering half-finished data.
	GameManager.next_match_p1_data = null
	GameManager.next_match_p2_data = null
	GameManager.editing_player_index = 1
	GameManager.p2_is_custom = false
	GameManager.temp_p1_preset = null
	GameManager.temp_p2_preset = null
	
	# Optional: Clear temp names if you want total reset
	GameManager.temp_p1_name = ""
	GameManager.temp_p2_name = ""
	
	# 2. CHANGE SCENE
	# You can send them to "res://Scenes/CharacterSelect.tscn" if you prefer
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
