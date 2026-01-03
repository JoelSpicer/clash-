# ActionTree.gd
extends Control

# --- DATA ---
# (Pasting your provided dicts here)
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

# Invert key dict for ID -> Name lookup
var id_to_name = {}

# --- SCENE REFS ---
@onready var nodes_layer = $NodesLayer
@onready var lines_layer = $LinesLayer

# --- STATE ---
var unlocked_ids: Array[int] = []
var owned_ids: Array[int] = []
var selected_class_id: int = 0

func _ready():
	# 1. Build ID to Name Lookup
	for key in action_tree_key_dict:
		id_to_name[action_tree_key_dict[key]] = key
	
	# 2. Setup Nodes (Assume nodes are placed manually in editor as children of NodesLayer)
	for child in nodes_layer.get_children():
		if child.has_method("setup"):
			var id = int(str(child.name)) # Assuming node name is "1", "2", etc.
			var a_name = id_to_name.get(id, "Unknown")
			child.setup(id, a_name)
			child.action_clicked.connect(_on_node_clicked)
			
	# 3. Initial Visual Update
	_update_tree_visuals()
	
	# 4. Trigger Line Drawing
	lines_layer.queue_redraw()

func _on_node_clicked(id: int, _name: String):
	# Is this a Class Selection Node? (73, 74, 75, 76)
	if id >= 73 and id <= 76:
		_select_class(id)
		return
		
	# Logic for normal nodes
	if id in owned_ids:
		# Already owned
		print("Already owned: " + _name)
	elif id in unlocked_ids:
		# Buy it!
		owned_ids.append(id)
		_unlock_neighbors(id)
		_update_tree_visuals()
	else:
		print("Locked!")

func _select_class(class_id: int):
	print("Selected Class: " + id_to_name[class_id])
	selected_class_id = class_id
	
	# Reset Tree
	owned_ids.clear()
	unlocked_ids.clear()
	
	# Add Class Node as owned
	owned_ids.append(class_id)
	
	# Unlock the class's starting connections
	_unlock_neighbors(class_id)
	
	_update_tree_visuals()

func _unlock_neighbors(node_id: int):
	if node_id in action_tree_dict:
		for neighbor_id in action_tree_dict[node_id]:
			if neighbor_id not in unlocked_ids and neighbor_id not in owned_ids:
				unlocked_ids.append(neighbor_id)

func _update_tree_visuals():
	for child in nodes_layer.get_children():
		var id = int(str(child.name))
		
		if id in owned_ids:
			child.set_status(2) # OWNED
		elif id in unlocked_ids:
			child.set_status(1) # AVAILABLE
		else:
			child.set_status(0) # LOCKED
			
		# Special Case: Classes are always visible/clickable to restart?
		if id >= 73 and id <= 76:
			child.set_status(1)
			if id == selected_class_id: child.set_status(2)
			
# Helper to find a file even if it's in a subfolder like "Class/Heavy/"
func _find_action_resource(action_name: String) -> ActionData:
	# 1. Convert "Toppling Kick" -> "toppling_kick"
	var clean_name = action_name.to_lower().replace(" ", "_")
	var filename = clean_name + ".tres"
	
	# 2. Check the main folder first (Common Actions)
	var common_path = "res://Data/Actions/" + filename
	if ResourceLoader.exists(common_path):
		return load(common_path)
		
	# 3. Check Class Subfolders (If your structure matches ClassFactory paths)
	var class_folders = ["Heavy", "Patient", "Quick", "Technical"]
	for folder in class_folders:
		var class_path = "res://Data/Actions/Class/" + folder + "/" + filename
		if ResourceLoader.exists(class_path):
			return load(class_path)
			
	# 4. Debug if not found
	printerr("CRITICAL: Could not find action file for: " + action_name + " | Looking for: " + filename)
	return null
	
# --- DRAWING LINES AUTOMATICALLY ---
func _draw_lines():
	# This function runs inside LinesLayer script (see below)
	pass

func _on_confirm_button_pressed():
	# 1. Create a new Character Data to hold this loadout
	# We can base it on the selected class (73-76)
	var final_character = CharacterData.new()
	
	# Set Class Identity based on the node selected
	match selected_class_id:
		73: final_character.class_type = CharacterData.ClassType.QUICK
		74: final_character.class_type = CharacterData.ClassType.TECHNICAL
		75: final_character.class_type = CharacterData.ClassType.PATIENT
		76: final_character.class_type = CharacterData.ClassType.HEAVY
		_: 
			print("Please select a Class (Nodes 73-76) first!")
			return

	# 2. Build the Deck
	var new_deck: Array[ActionData] = []
	
	for id in owned_ids:
		# Skip the class selection nodes themselves
		if id >= 73: continue 
		
		# Get the name from your dictionary
		var a_name = id_to_name.get(id)
		
		# Load the actual file
		var card_resource = _find_action_resource(a_name)
		if card_resource:
			new_deck.append(card_resource)
	
	# 3. Validate Deck Size (Optional)
	if new_deck.size() < 5:
		print("Deck too small! Select more actions.")
		return
		
	# 4. Assign to Character and Start Game
	final_character.deck = new_deck
	final_character.character_name = "Custom Player"
	# Copy standard stats from ClassFactory if needed, or set defaults here
	final_character.max_hp = 10 
	final_character.max_sp = 3
	final_character.reset_stats()
	
	# Send to GameManager
	GameManager.next_match_p1_data = final_character
	# For testing, we might generate a dummy P2
	GameManager.next_match_p2_data = ClassFactory.create_character(CharacterData.ClassType.HEAVY, "Bot")
	
	# Load the Arena
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
