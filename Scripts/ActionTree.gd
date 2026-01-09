extends Control

# --- DATA ---
# (Keep your existing dictionaries here)
var action_tree_key_dict = {
	"Toppling Kick":1, "Pummel":2, "One Two":3, "Evading Dance":4, "Slip Behind":5,
	"Adept Dodge":6, "Adept Light":7, "Hundred Hand Slap":8, "Precise Strike":9, "Breakout":10,
	"Read Offence":11, "Quick Dodge":12, "Master Dodge":13, "Master Light":14, "Flying Kick":15,
	"Vital Strike":16, "Unassailable Stance":17, "Strike Back":18, "Leg Sweep":19, "Catch":20,
	"Drop Prone":21, "Perfect Strike":22, "Step Up":23, "Go with the Flow":24, "Prime":25,
	"Inner Peace":26, "Adept Reversal":27, "Master Reversal":28, "Untouchable Dodge":29,
	"Ultimate Barrage":30, "Advancing Parry":31, "Master Positioning":32, "Adept Positioning":33,
	"Grab":34, "Wind Up":35, "Vital Point Assault":36, "Overwhelming Aura":37, "Parry FollowUp":38,
	"Adjust Stance":39, "Adept Tech":40, "Master Tech":41, "Crushing Block":42, "Final Strike":43,
	"Redirect":44, "Master Parry":45, "Adept Parry":46, "Throw":47, "Resounding Parry":48,
	"Push":49, "Twist Arm":50, "Suplex":51, "Perfect Block":52, "Active Block":53,
	"Retreating Defence":54, "Resounding Counter":55, "Read Defence":56, "Headbutt":57, "Lariat":58,
	"Master Heavy":59, "Master Block":60, "Draining Defence":61, "Slapping Parry":62, "Tiring Parry":63,
	"Roundhouse Kick":64, "Uppercut":65, "Adept Heavy":66, "Adept Block":67, "Push Kick":68,
	"Drop Punch":69, "Knee Crush":70, "Drop Kick":71, "Immovable Stance":72,
	"Quick":73, "Technical":74, "Patient":75, "Heavy":76
}

var action_tree_dict = {
	1:[12,5], 2:[6,7], 3:[8,15], 4:[11,12], 5:[1,6], 6:[2,5,13], 7:[2,14,8], 8:[7,3],
	9:[15,16], 10:[11,19], 11:[4,10,20], 12:[4,1,13,20], 13:[12,6,21], 14:[7,15,21],
	15:[3,14,9,22], 16:[9,22,17], 17:[16,23], 18:[19,25], 19:[10,18,20,28], 20:[19,11,12,29],
	21:[13,14,29,31,30], 22:[15,16,23,31], 23:[22,17,24,32], 24:[23,26], 25:[18,27], 26:[24,33],
	27:[34,28,25], 28:[27,19,35], 29:[20,21,35], 30:[21], 31:[21,22,38], 32:[23,38,33],
	33:[32,26,39], 34:[27,40], 35:[28,41,29,42,36], 36:[35], 37:[38], 38:[31,32,44,45,37],
	39:[33,46], 40:[34,41,47], 41:[40,50,35], 42:[35,51,52], 43:[52], 44:[52,38,53],
	45:[38,46,54], 46:[45,48], 47:[40,49], 48:[46,55], 49:[47,50], 50:[49,41,51,56],
	51:[50,42,58,57], 52:[42,43,44,59,60], 53:[44,54,61,62], 54:[53,45,55,63], 55:[48,54],
	56:[50,57], 57:[56,51,64], 58:[51,64,59,70], 59:[52,66,58], 60:[52,67,61], 61:[53,72,69],
	62:[53,63,69], 63:[54,62], 64:[57,58], 65:[70,66], 66:[59,65,71], 67:[68,60,71],
	68:[67,72], 69:[61,62], 70:[58,65], 71:[66,67], 72:[68,61], 73:[2], 74:[34], 75:[39], 76:[71]
}

var id_to_name = {}

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

# --- NEW: STATS TRACKING ---
var current_max_hp: int = 10
var current_max_sp: int = 3
var stats_label: Label 

# --- NEW: POPUP REFERENCES ---
var card_scene = preload("res://Scenes/CardDisplay.tscn")
var popup_card: Control

func _ready():
	# 1. Build ID lookup
	for key in action_tree_key_dict:
		id_to_name[action_tree_key_dict[key]] = key
	
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

	# 4. Check for Pre-Selection
	_setup_for_current_player()
	
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
	var res = _find_action_resource(a_name)
	
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
			# Look up the ID using your existing Name->ID dictionary
			if skill_name in action_tree_key_dict:
				var id = action_tree_key_dict[skill_name]
				
				# Add to owned if not already there
				if id not in owned_ids:
					owned_ids.append(id)
			else:
				printerr("Warning: Preset skill '" + skill_name + "' not found in ActionTree dict.")
		
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
		var card = _find_action_resource(a_name)
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
			
		if id >= 73 and id <= 76:
			child.set_status(1)
			if id == selected_class_id: child.set_status(2)

func _find_action_resource(action_name: String) -> ActionData:
	var clean_name = action_name.to_lower().replace(" ", "_")
	var filename = clean_name + ".tres"
	
	var common_path = "res://Data/Actions/" + filename
	if ResourceLoader.exists(common_path): return load(common_path)
		
	var class_folders = ["Heavy", "Patient", "Quick", "Technical"]
	for folder in class_folders:
		var class_path = "res://Data/Actions/Class/" + folder + "/" + filename
		if ResourceLoader.exists(class_path): return load(class_path)
			
	return null

func _on_confirm_button_pressed():
	if selected_class_id == 0:
		print("Please select a Class first!")
		return

	var final_character = CharacterData.new()
	
	# 1. Set Class Type
	match selected_class_id:
		73: final_character.class_type = CharacterData.ClassType.QUICK
		74: final_character.class_type = CharacterData.ClassType.TECHNICAL
		75: final_character.class_type = CharacterData.ClassType.PATIENT
		76: final_character.class_type = CharacterData.ClassType.HEAVY

	# 2. Add Base Deck (Starters + Basic)
	var base_deck = ClassFactory.get_starting_deck(final_character.class_type)
	var final_deck: Array[ActionData] = []
	final_deck.append_array(base_deck)
	
	# 3. Add Unlocked Tree Cards
	for id in owned_ids:
		if id >= 73: continue 
		var a_name = id_to_name.get(id)
		var card_resource = _find_action_resource(a_name)
		if card_resource:
			final_deck.append(card_resource)
			
	# 4. Finalize Character with CALCULATED STATS
	final_character.deck = final_deck
	
	# --- USE CALCULATED STATS HERE ---
	final_character.max_hp = current_max_hp
	final_character.max_sp = current_max_sp
	# ---------------------------------
	
	final_character.reset_stats()
	
	# 2. Save to the correct slot
	if GameManager.editing_player_index == 1:
		# Use stored name if exists, else "Player 1"
		var p1_name = GameManager.get("temp_p1_name")
		final_character.character_name = p1_name if p1_name != "" else "Player 1"
		
		GameManager.next_match_p1_data = final_character
		print("P1 Saved as: " + final_character.character_name)
		
		if GameManager.p2_is_custom:
			print("Moving to Player 2 Setup...")
			GameManager.editing_player_index = 2
			_setup_for_current_player()
			return 
			
	else:
		# We are editing Player 2
		var p2_name = GameManager.get("temp_p2_name")
		final_character.character_name = p2_name if p2_name != "" else "Player 2"
		
		# DELETE THIS LINE:
		# final_character.character_name = "Player 2" <-- DELETE THIS TOO
		
		GameManager.next_match_p2_data = final_character
		print("P2 Saved as: " + final_character.character_name)

	# 3. Launch Fight
	# (Safety fallback if P2 data is somehow missing, create bot)
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
