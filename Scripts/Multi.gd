extends Control

@onready var tube_client = $TubeClient
@onready var host_button = $HostButton
@onready var room_code_label = $RoomCodeLabel
@onready var join_code_input = $JoinCodeInput
@onready var join_button = $JoinButton

# --- NEW: Dropdown Node ---
@onready var character_dropdown = $CharacterDropdown 

# Leave this empty, we will fill it automatically now!
var character_roster: Array[String] = []

func _ready():
	# Connect our UI buttons
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	# Connect Tube's built-in signals
	tube_client.session_created.connect(_on_session_created)
	tube_client.session_joined.connect(_on_session_joined)
	tube_client.peer_connected.connect(_on_peer_connected)
	tube_client.error_raised.connect(_on_error_raised)
	
	# Dynamically populate the roster!
	_load_presets_from_folder()

func _load_presets_from_folder():
	if not character_dropdown: return
	
	character_dropdown.clear()
	character_roster.clear()
	
	var path = "res://Data/Presets"
	var dir = DirAccess.open(path)
	
	if dir:
		var files = dir.get_files()
		for file in files:
			# CRITICAL FOR WEB EXPORTS: Godot appends '.remap' to exported resources.
			# We must strip it out so the load() function can find the file.
			var clean_file = file.replace(".remap", "")
			
			if clean_file.ends_with(".tres") or clean_file.ends_with(".res"):
				var full_path = path + "/" + clean_file
				var preset = load(full_path) as PresetCharacter
				
				# If it successfully loaded as a PresetCharacter, add it!
				if preset:
					character_roster.append(full_path)
					
					# Bonus: Show the character's level in the dropdown
					var drop_text = preset.character_name + " (Lv." + str(preset.level) + ")"
					character_dropdown.add_item(drop_text)
					print("Loaded Preset: " + preset.character_name)
	else:
		printerr("ERROR: Could not open directory: " + path)
		character_dropdown.add_item("Kaiji Akagi")
		character_dropdown.add_item("Crash Johnson")

func _on_host_pressed():
	print("Attempting to host...")
	tube_client.create_session()

func _on_join_pressed():
	var friend_code = join_code_input.text.strip_edges()
	if friend_code == "":
		print("Please enter a code first!")
		return
		
	print("Attempting to join code: ", friend_code)
	tube_client.join_session(friend_code)

func hide_lobby_ui():
	host_button.hide()
	join_button.hide()
	join_code_input.hide()
	room_code_label.hide()
	character_dropdown.hide()

# --- TUBE SIGNAL RESPONSES ---

func _on_session_created():
	var my_code = tube_client.session_id 
	room_code_label.text = "Your Room Code: " + my_code
	print("Hosting! Send this code to your friend: ", my_code)

func _on_session_joined():
	# Triggered for the CLIENT when they successfully connect
	print("Boom! We successfully joined the session!")
	hide_lobby_ui()
	
	# Send an invisible message to the Host telling them which character index we selected
	# "rpc_id(1, ...)" means send this specifically to Peer 1 (The Host)
	rpc_id(1, "receive_client_character", character_dropdown.selected)

func _on_peer_connected(peer_id):
	# Triggered for the HOST when a friend successfully connects
	print("A friend joined our game! Their peer ID is: ", peer_id)
	hide_lobby_ui()
	# Note: We don't start the game here anymore! We wait for the Client to tell us who they are playing as.

func _on_error_raised(code, message):
	print("Tube Error! Code: ", code, " Message: ", message)


# ==========================================
# --- NETWORK HANDSHAKE ---
# ==========================================

# The Client calls this on the Host's machine
@rpc("any_peer", "call_remote", "reliable")
func receive_client_character(client_char_index: int):
	# Only the Server (Host) executes this block
	if multiplayer.is_server():
		print("Host received the Client's character choice!")
		
		# Grab the Host's choice from their local dropdown
		var host_char_index = character_dropdown.selected
		
		# Now that the Host has both choices, tell EVERYONE to start the match!
		rpc("start_match", host_char_index, client_char_index)

# The Host triggers this on both machines simultaneously
@rpc("authority", "call_local", "reliable")
func start_match(p1_index: int, p2_index: int):
	print("Loading presets and starting the match!")
	
	# 1. Grab the correct file paths based on what was selected in the dropdowns
	var p1_preset = load(character_roster[p1_index])
	var p2_preset = load(character_roster[p2_index])
	
	# 2. Build the characters using your factory
	var p1_data = ClassFactory.create_from_preset(p1_preset)
	var p2_data = ClassFactory.create_from_preset(p2_preset)
	
	# 3. Assign them to the GameManager
	GameManager.next_match_p1_data = p1_data
	GameManager.next_match_p2_data = p2_data
	
	# 4. Jump into the arena!
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
