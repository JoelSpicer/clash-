extends Control

@onready var host_button = $HostButton
@onready var room_code_label = $RoomCodeLabel
@onready var join_code_input = $JoinCodeInput
@onready var join_button = $JoinButton
@onready var character_dropdown = $CharacterDropdown 

var character_roster: Array[String] = []

func _ready():
	host_button.hide()
	join_code_input.hide()
	room_code_label.hide()
	
	join_button.text = "Find Match"
	join_button.pressed.connect(_on_join_pressed)
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_load_presets_from_folder()
	
	if OS.get_cmdline_args().has("--server"):
		hide_lobby_ui()

func _load_presets_from_folder():
	if not character_dropdown: return
	character_dropdown.clear()
	character_roster.clear()
	
	var path = "res://Data/Presets"
	var dir = DirAccess.open(path)
	
	if dir:
		var files = dir.get_files()
		for file in files:
			var clean_file = file.replace(".remap", "")
			if clean_file.ends_with(".tres") or clean_file.ends_with(".res"):
				var full_path = path + "/" + clean_file
				var preset = load(full_path) as PresetCharacter
				
				if preset:
					character_roster.append(full_path)
					var drop_text = preset.character_name + " (Lv." + str(preset.level) + ")"
					character_dropdown.add_item(drop_text)
	else:
		printerr("ERROR: Could not open directory: " + path)

func _on_join_pressed():
	print("Attempting to connect to the server...")
	NetworkManager.join_server()

func hide_lobby_ui():
	join_button.hide()
	character_dropdown.hide()

# ==========================================
# --- NATIVE MULTIPLAYER SIGNALS ---
# ==========================================

func _on_connected_to_server():
	print("Boom! We successfully joined the server!")
	hide_lobby_ui()
	
	# Grab the exact file path of the chosen character
	var my_char_path = character_roster[character_dropdown.selected]
	
	# Ask our immortal NetworkManager to send the RPC to the Server
	NetworkManager.rpc_id(1, "register_player_character", my_char_path)

func _on_connection_failed():
	print("ERROR: Could not reach the server. Is it running?")

func _on_server_disconnected():
	print("ERROR: The server closed the connection.")
