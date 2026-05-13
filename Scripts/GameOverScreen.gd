extends Control

@onready var title_label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var winner_label = $Panel/MarginContainer/VBoxContainer/WinnerLabel
@onready var main_btn = $Panel/MarginContainer/VBoxContainer/RematchButton
@onready var menu_btn = $Panel/MarginContainer/VBoxContainer/MenuButton
@onready var panel = $Panel
@onready var view_btn = $Panel/MarginContainer/VBoxContainer/ViewBtn

var winner_data: CharacterData = null
var match_log_text: String = ""

# -- Code-generated Log Window --
var log_popup: Panel = null
var log_label: RichTextLabel = null

func _ready():
	# Default connections
	if not main_btn.pressed.is_connected(_on_main_action):
		main_btn.pressed.connect(_on_main_action)
	
	if not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.pressed.connect(_on_menu_pressed)
	
	# --- VIEW BUTTON CONNECTION ---
	if view_btn:
		view_btn.text = "VIEW LOG" 
		if not view_btn.pressed.is_connected(_on_view_pressed): 
			view_btn.pressed.connect(_on_view_pressed)
	
	# Build the popup immediately
	_build_log_window()

func setup(data: CharacterData, log_text: String = ""):
	winner_data = data
	match_log_text = log_text
	
	if log_text == "":
		print("GameOverScreen: WARNING - log_text is empty!")
		match_log_text = "[center]No log data recorded.[/center]"
	else:
		print("GameOverScreen: Log text received. Length: " + str(log_text.length()))

	if log_label:
		log_label.text = match_log_text
		
	winner_label.text = "Winner: " + data.character_name
	
	# Mode Check
	if RunManager.player_run_data != null:
		_setup_arcade_mode()
	else:
		_setup_quick_match_mode()

func _setup_quick_match_mode():
	# --- NEW: Multiplayer check ---
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		main_btn.text = "REMATCH (SYNC)"
		menu_btn.text = "DISCONNECT"
	else:
		main_btn.text = "REMATCH"

func _setup_arcade_mode():
	var player_won = (winner_data.character_name == RunManager.player_run_data.character_name)
	menu_btn.visible = false
	if player_won:
		title_label.text = "VICTORY!"
		title_label.modulate = Color.GREEN
		main_btn.text = "CONTINUE"
	else:
		title_label.text = "RUN ENDED"
		title_label.modulate = Color.RED
		main_btn.text = "FINISH RUN" 
		menu_btn.visible = false

func _on_main_action():
	AudioManager.play_sfx("ui_confirm")
	
	# 1. ARCADE MODE LOGIC
	if RunManager.player_run_data != null:
		var player_won = (winner_data.character_name == RunManager.player_run_data.character_name)
		
		if player_won:
			RunManager.handle_win()
		else:
			RunManager.handle_loss() 
			get_tree().paused = false 
			SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
			
	# 2. QUICK MATCH LOGIC
	else:
		# --- NEW: Dedicated Server Rematch Trigger ---
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			# For now, return to the lobby to guarantee a clean slate on the server
			NetworkManager.rpc_id(1, "request_server_reset")
		else:
			AudioManager.reset_audio_state()
			get_tree().paused = false
			SceneLoader.reload_current_scene()

func _on_menu_pressed():
	AudioManager.play_sfx("ui_back")
	AudioManager.reset_audio_state()
	
	if RunManager.player_run_data:
		RunManager.player_run_data = null 
	
	# --- NEW: Dedicated Server Quit Trigger ---
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		# Ask the server to wipe its memory and send everyone back to the lobby
		NetworkManager.rpc_id(1, "request_server_reset")
	else:
		get_tree().paused = false
		SceneLoader.change_scene("res://Scenes/MainMenu.tscn")


func _on_view_pressed():
	AudioManager.play_sfx("ui_click")
	log_popup.visible = not log_popup.visible

func _build_log_window():
	log_popup = Panel.new()
	log_popup.visible = false
	log_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	
	log_popup.custom_minimum_size = Vector2(600, 400)
	log_popup.size = Vector2(600, 400)
	log_popup.position = (get_viewport_rect().size / 2) - (Vector2(600, 400) / 2)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.set_corner_radius_all(8)
	log_popup.add_theme_stylebox_override("panel", style)
	
	add_child(log_popup)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(560, 10)
	close_btn.size = Vector2(30, 30)
	close_btn.pressed.connect(_on_view_pressed)
	log_popup.add_child(close_btn)
	
	var scroll = ScrollContainer.new()
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
