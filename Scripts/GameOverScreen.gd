extends Control

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var winner_label = $Panel/VBoxContainer/WinnerLabel
@onready var main_btn = $Panel/VBoxContainer/RematchButton # Check if this matches your scene (RematchBtn vs RematchButton)
@onready var menu_btn = $Panel/VBoxContainer/MenuButton
@onready var panel = $Panel
@onready var view_btn = $Panel/VBoxContainer/ViewBtn

var winner_data: CharacterData = null
var match_log_text: String = ""

# -- NEW: Code-generated Log Window --
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
	
	# DEBUG: Check if text is actually arriving
	if log_text == "":
		print("GameOverScreen: WARNING - log_text is empty!")
		match_log_text = "[center]No log data recorded.[/center]"
	else:
		print("GameOverScreen: Log text received. Length: " + str(log_text.length()))

	# Populate the log label
	if log_label:
		log_label.text = match_log_text
		
	winner_label.text = "Winner: " + data.character_name
	
	# Mode Check
	if RunManager.player_run_data != null:
		_setup_arcade_mode()
	else:
		_setup_quick_match_mode()

func _setup_quick_match_mode():
	main_btn.text = "REMATCH"

func _setup_arcade_mode():
	var player_won = (winner_data.character_name == RunManager.player_run_data.character_name)
	
	if player_won:
		title_label.text = "VICTORY!"
		title_label.modulate = Color.GREEN
		main_btn.text = "CONTINUE"
	else:
		title_label.text = "GAME OVER"
		title_label.modulate = Color.RED
		main_btn.text = "TRY AGAIN" 

func _on_main_action():
	AudioManager.play_sfx("ui_confirm")
	
	# 1. ARCADE MODE LOGIC
	if RunManager.player_run_data != null:
		var player_won = (winner_data.character_name == RunManager.player_run_data.character_name)
		
		if player_won:
			RunManager.handle_win()
		else:
			get_tree().paused = false 
			SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
			
	# 2. QUICK MATCH LOGIC
	else:
		get_tree().paused = false
		SceneLoader.reload_current_scene()

func _on_menu_pressed():
	AudioManager.play_sfx("ui_back")
	if RunManager.player_run_data:
		RunManager.player_run_data = null 
	
	get_tree().paused = false
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")

func _on_view_pressed():
	AudioManager.play_sfx("ui_click")
	log_popup.visible = not log_popup.visible

func _build_log_window():
	# 1. Create the Popup Panel
	log_popup = Panel.new()
	log_popup.visible = false
	log_popup.mouse_filter = Control.MOUSE_FILTER_STOP # Blocks clicks
	
	# Size and Position (Centered)
	log_popup.custom_minimum_size = Vector2(600, 400)
	log_popup.size = Vector2(600, 400)
	# Center it on screen
	log_popup.position = (get_viewport_rect().size / 2) - (Vector2(600, 400) / 2)
	
	# Style: Dark Overlay with Border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.set_corner_radius_all(8)
	log_popup.add_theme_stylebox_override("panel", style)
	
	add_child(log_popup)
	
	# 2. FIX: Add an "X" Close Button inside the popup
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(560, 10) # Top right corner
	close_btn.size = Vector2(30, 30)
	close_btn.pressed.connect(_on_view_pressed) # Re-use the toggle function
	log_popup.add_child(close_btn)
	
	# 3. Create Scroll Container
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 50) # Below the close button
	scroll.size = Vector2(560, 330) # Fill remaining space
	log_popup.add_child(scroll)
	
	# 4. Create Text Label
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	# FIX: These flags ensure the label expands to hold the text
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.fit_content = true # CRITICAL: Allows scrolling to work
	log_label.text = "Loading log..."
	
	scroll.add_child(log_label)
