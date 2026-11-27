extends Control

@onready var host_button: Button = $HostButton
@onready var room_code_label: Label = $RoomCodeLabel
@onready var join_code_input: LineEdit = $JoinCodeInput
@onready var join_button: Button = $JoinButton
@onready var character_dropdown: OptionButton = $CharacterDropdown

var status_label: Label
var local_server_toggle: CheckButton
var character_roster: Array[String] = []


func _ready() -> void:
	host_button.hide()
	join_code_input.hide()
	room_code_label.hide()

	join_button.text = "Find Match"
	join_button.pressed.connect(_on_join_pressed)

	_create_lobby_status_ui()

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	_load_presets_from_folder()

	if OS.get_cmdline_args().has("--server"):
		hide_lobby_ui()
	else:
		_set_status("Ready (" + NetworkManager.get_server_url() + ")", Color.LIGHT_GRAY)


func _create_lobby_status_ui() -> void:
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(338.0, 445.0)
	status_label.size = Vector2(520.0, 32.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(status_label)

	local_server_toggle = CheckButton.new()
	local_server_toggle.name = "LocalServerToggle"
	local_server_toggle.text = "Use Local Server (ws://localhost:8080)"
	local_server_toggle.position = Vector2(338.0, 485.0)
	local_server_toggle.button_pressed = NetworkManager.use_local_server
	local_server_toggle.toggled.connect(_on_local_server_toggled)
	add_child(local_server_toggle)


func _set_status(message: String, color: Color = Color.WHITE) -> void:
	if status_label:
		status_label.text = message
		status_label.modulate = color


func _set_controls_enabled(enabled: bool) -> void:
	join_button.disabled = not enabled
	character_dropdown.disabled = not enabled
	if local_server_toggle:
		local_server_toggle.disabled = not enabled


func _on_local_server_toggled(toggled_on: bool) -> void:
	NetworkManager.use_local_server = toggled_on
	_set_status("Ready (" + NetworkManager.get_server_url() + ")", Color.LIGHT_GRAY)


func _load_presets_from_folder() -> void:
	if not character_dropdown:
		return
	character_dropdown.clear()
	character_roster.clear()

	var paths: Array[String] = ResourceCatalog.list_paths("res://Data/Presets")
	if paths.is_empty():
		printerr("ERROR: Could not find character presets in res://Data/Presets")
		_set_status("Error: Could not load character presets.", Color.SALMON)
		return

	for full_path: String in paths:
		var preset: PresetCharacter = load(full_path) as PresetCharacter
		if preset:
			character_roster.append(full_path)
			var drop_text: String = preset.character_name + " (Lv." + str(preset.level) + ")"
			character_dropdown.add_item(drop_text)


func _on_join_pressed() -> void:
	if character_roster.is_empty():
		_set_status("No playable character presets found.", Color.SALMON)
		return

	print("Attempting to connect to the server...")
	_set_controls_enabled(false)
	_set_status("Connecting to " + NetworkManager.get_server_url() + "...", Color.KHAKI)

	var err: Error = NetworkManager.join_server()
	if err != OK:
		_set_controls_enabled(true)
		_set_status("Failed to start connection (Error " + str(err) + ").", Color.SALMON)


func hide_lobby_ui() -> void:
	join_button.hide()
	character_dropdown.hide()
	if local_server_toggle:
		local_server_toggle.hide()


func show_lobby_ui() -> void:
	join_button.show()
	character_dropdown.show()
	if local_server_toggle:
		local_server_toggle.show()
	_set_controls_enabled(true)


# ==========================================
# --- NATIVE MULTIPLAYER SIGNALS ---
# ==========================================

func _on_connected_to_server() -> void:
	print("Boom! We successfully joined the server!")
	hide_lobby_ui()
	_set_status("Connected! Waiting for an opponent...", Color.LIGHT_GREEN)

	var idx: int = clampi(character_dropdown.selected, 0, character_roster.size() - 1)
	var my_char_path: String = character_roster[idx]

	# Ask our immortal NetworkManager to send the RPC to the Server
	NetworkManager.rpc_id(1, "register_player_character", my_char_path)


func _on_connection_failed() -> void:
	print("ERROR: Could not reach the server. Is it running?")
	NetworkManager.cancel_connection()
	show_lobby_ui()
	_set_status("Connection failed: could not reach " + NetworkManager.get_server_url(), Color.SALMON)


func _on_server_disconnected() -> void:
	print("ERROR: The server closed the connection.")
	show_lobby_ui()
	_set_status("Disconnected from server. Click Find Match to retry.", Color.ORANGE)
