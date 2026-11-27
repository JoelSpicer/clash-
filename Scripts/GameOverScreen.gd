extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var winner_label: Label = $Panel/MarginContainer/VBoxContainer/WinnerLabel
@onready var main_btn: Button = $Panel/MarginContainer/VBoxContainer/RematchButton
@onready var menu_btn: Button = $Panel/MarginContainer/VBoxContainer/MenuButton
@onready var view_btn: Button = $Panel/MarginContainer/VBoxContainer/ViewBtn

var winner_data: CharacterData = null
var match_log_text: String = ""
var _action_committed: bool = false

var log_popup: Panel = null
var log_label: RichTextLabel = null


func _ready() -> void:
	if not main_btn.pressed.is_connected(_on_main_action):
		main_btn.pressed.connect(_on_main_action)

	if not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.pressed.connect(_on_menu_pressed)

	if view_btn:
		view_btn.text = "VIEW LOG"
		if not view_btn.pressed.is_connected(_on_view_pressed):
			view_btn.pressed.connect(_on_view_pressed)

	_build_log_window()


func setup(data: CharacterData, log_text: String = "") -> void:
	_action_committed = false
	main_btn.disabled = false
	menu_btn.disabled = false
	menu_btn.visible = true

	winner_data = data
	match_log_text = log_text

	if log_text == "":
		print("GameOverScreen: WARNING - log_text is empty!")
		match_log_text = "[center]No log data recorded.[/center]"
	else:
		print("GameOverScreen: Log text received. Length: " + str(log_text.length()))

	if log_label:
		log_label.text = match_log_text

	winner_label.text = "Winner: " + (data.character_name if data != null else "Unknown")

	if RunManager.is_arcade_mode and RunManager.player_run_data != null:
		_setup_arcade_mode()
	else:
		_setup_quick_match_mode()


func _setup_quick_match_mode() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		main_btn.text = "RETURN TO LOBBY"
		menu_btn.text = "MAIN MENU"
	else:
		main_btn.text = "REMATCH"
		menu_btn.text = "MAIN MENU"


func _is_arcade_player_winner() -> bool:
	if winner_data == null or RunManager.player_run_data == null:
		return false
	if winner_data == GameManager.p1_data:
		return true
	return winner_data.character_name == RunManager.player_run_data.character_name


func _setup_arcade_mode() -> void:
	var player_won: bool = _is_arcade_player_winner()
	menu_btn.visible = false
	if player_won:
		title_label.text = "VICTORY!"
		title_label.modulate = Color.GREEN
		main_btn.text = "CONTINUE"
	else:
		title_label.text = "RUN ENDED"
		title_label.modulate = Color.RED
		main_btn.text = "FINISH RUN"


func _on_main_action() -> void:
	if _action_committed:
		return
	_action_committed = true
	main_btn.disabled = true
	menu_btn.disabled = true
	AudioManager.play_sfx("ui_confirm")

	if RunManager.is_arcade_mode and RunManager.player_run_data != null:
		var player_won: bool = _is_arcade_player_winner()

		if player_won:
			RunManager.handle_win()
		else:
			RunManager.handle_loss()
			get_tree().paused = false
			SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
	else:
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			NetworkManager.rpc_id(1, "request_server_reset")
		else:
			AudioManager.reset_audio_state()
			AudioManager.play_location_music(GameManager.current_environment_name)
			get_tree().paused = false
			SceneLoader.change_scene("res://Scenes/CombatArena.tscn")


func _on_menu_pressed() -> void:
	if _action_committed:
		return
	_action_committed = true
	main_btn.disabled = true
	menu_btn.disabled = true
	AudioManager.play_sfx("ui_back")
	AudioManager.reset_audio_state()

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		NetworkManager.cancel_connection()
		get_tree().paused = false
		SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
	else:
		RunManager.clear_active_run_state()
		get_tree().paused = false
		SceneLoader.change_scene("res://Scenes/MainMenu.tscn")


func _on_view_pressed() -> void:
	log_popup.visible = not log_popup.visible


func _build_log_window() -> void:
	log_popup = Panel.new()
	log_popup.visible = false
	log_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	log_popup.set_anchors_preset(Control.PRESET_CENTER)
	log_popup.offset_left = -300.0
	log_popup.offset_top = -200.0
	log_popup.offset_right = 300.0
	log_popup.offset_bottom = 200.0

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.set_corner_radius_all(8)
	log_popup.add_theme_stylebox_override("panel", style)

	add_child(log_popup)

	var close_btn: Button = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(560, 10)
	close_btn.size = Vector2(30, 30)
	close_btn.pressed.connect(_on_view_pressed)
	log_popup.add_child(close_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(20, 50)
	scroll.size = Vector2(560, 330)
	log_popup.add_child(scroll)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.fit_content = true
	log_label.text = "Loading log..."

	scroll.add_child(log_label)
