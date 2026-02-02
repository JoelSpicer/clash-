extends Control

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var winner_label = $Panel/VBoxContainer/WinnerLabel
@onready var main_btn = $Panel/VBoxContainer/RematchButton # Use your actual button name
@onready var menu_btn = $Panel/VBoxContainer/MenuButton

var winner_data: CharacterData = null

func _ready():
	# Default connections
	if not main_btn.pressed.is_connected(_on_main_action):
		main_btn.pressed.connect(_on_main_action)
	
	if not menu_btn.pressed.is_connected(_on_menu_pressed):
		menu_btn.pressed.connect(_on_menu_pressed)

func setup(data: CharacterData):
	winner_data = data
	winner_label.text = "Winner: " + data.character_name
	
	# --- MODE CHECK ---
	if RunManager.player_run_data != null:
		_setup_arcade_mode()
	else:
		_setup_quick_match_mode()

func _setup_quick_match_mode():
	# Standard Fighting Game behavior
	main_btn.text = "REMATCH"
	# Logic stays as default (reload scene)

func _setup_arcade_mode():
	# Check if the PLAYER won (Arcade P1 is always the player)
	var player_won = (winner_data.character_name == RunManager.player_run_data.character_name)
	
	if player_won:
		title_label.text = "VICTORY!"
		title_label.modulate = Color.GREEN
		
		main_btn.text = "CONTINUE"
		# The _on_main_action function will handle the routing
	else:
		title_label.text = "GAME OVER"
		title_label.modulate = Color.RED
		
		# In a roguelike, losing usually means the run ends
		main_btn.text = "TRY AGAIN" 
		# You could also hide this button if you want strict permadeath
		# main_btn.visible = false 

func _on_main_action():
	AudioManager.play_sfx("ui_confirm")
	print("GameOverScreen: Main Button Pressed") # DEBUG
	
	# 1. ARCADE MODE LOGIC
	if RunManager.player_run_data != null:
		var player_won = (winner_data.character_name == RunManager.player_run_data.character_name)
		print("GameOverScreen: Arcade Mode. Player Won? " + str(player_won)) # DEBUG
		
		if player_won:
			print("GameOverScreen: Calling handle_win()...") # DEBUG
			RunManager.handle_win()
		else:
			print("GameOverScreen: Reloading Scene (Retry)...") # DEBUG
			get_tree().paused = false # Safety unpause for retry too!
			SceneLoader.reload_current_scene()
			
	# 2. QUICK MATCH LOGIC
	else:
		print("GameOverScreen: Quick Match Rematch...") # DEBUG
		get_tree().paused = false # Safety unpause
		SceneLoader.reload_current_scene()

func _on_menu_pressed():
	AudioManager.play_sfx("ui_back")
	# If in arcade, maybe clear the run data?
	if RunManager.player_run_data:
		RunManager.player_run_data = null # End the run
		
	SceneLoader.change_scene("res://Scenes/MenuArcade.tscn")
