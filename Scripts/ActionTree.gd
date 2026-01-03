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
			
	# 3. Create Stats Label UI
	stats_label = Label.new()
	stats_label.text = "HP: 10 | SP: 3"
	stats_label.add_theme_font_size_override("font_size", 32)
	stats_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stats_label.position.y += 20 # Offset from top
	add_child(stats_label)

	# 4. Check for Pre-Selection
	if GameManager.get("temp_p1_class_selection") != null:
		var prev_selection = GameManager.temp_p1_class_selection
		var node_id = 0
		match prev_selection:
			0: node_id = 76 # Heavy
			1: node_id = 75 # Patient
			2: node_id = 73 # Quick
			3: node_id = 74 # Technical
			
		if node_id != 0:
			_select_class(node_id)
			is_class_locked = true 
	
	_update_tree_visuals()
	_recalculate_stats() # Initial calc
	lines_layer.queue_redraw()

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
	# Reset to Base
	current_max_hp = 10
	current_max_sp = 3
	
	# If no class selected, just show base
	if selected_class_id == 0:
		stats_label.text = "HP: 10 | SP: 3"
		return

	# Calculate bonuses from owned cards
	for id in owned_ids:
		if id >= 73: continue # Skip the class node itself
		
		var a_name = id_to_name.get(id)
		var card = _find_action_resource(a_name)
		
		if card:
			# Apply Rules based on Class + Card Type
			# ActionData.Type: OFFENCE = 0, DEFENCE = 1
			
			match selected_class_id:
				73: # QUICK
					if card.type == ActionData.Type.OFFENCE: current_max_hp += 1
					elif card.type == ActionData.Type.DEFENCE: current_max_sp += 2
					
				74: # TECHNICAL
					if card.type == ActionData.Type.OFFENCE: 
						current_max_hp += 1
						current_max_sp += 1
					elif card.type == ActionData.Type.DEFENCE:
						current_max_sp += 1
						
				75: # PATIENT
					if card.type == ActionData.Type.OFFENCE: current_max_hp += 1
					elif card.type == ActionData.Type.DEFENCE:
						current_max_hp += 1
						current_max_sp += 1
						
				76: # HEAVY
					if card.type == ActionData.Type.OFFENCE: current_max_sp += 1
					elif card.type == ActionData.Type.DEFENCE: current_max_hp += 2
	
	# Update UI
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
	final_character.character_name = "Custom Player"
	
	# --- USE CALCULATED STATS HERE ---
	final_character.max_hp = current_max_hp
	final_character.max_sp = current_max_sp
	# ---------------------------------
	
	final_character.reset_stats()
	
	GameManager.next_match_p1_data = final_character
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
