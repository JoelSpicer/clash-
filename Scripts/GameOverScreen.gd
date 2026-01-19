extends Control

@onready var winner_label = $Panel/VBoxContainer/WinnerLabel

func _ready():
	# 1. Get References
	var btn_rematch = $Panel/VBoxContainer/RematchButton
	var btn_menu = $Panel/VBoxContainer/MenuButton
	
	# 2. Connect Logic (Existing)
	btn_rematch.pressed.connect(_on_rematch_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	
	# 3. Connect Audio (New)
	_attach_sfx(btn_rematch)
	_attach_sfx(btn_menu)

# --- NEW HELPER FUNCTION ---
func _attach_sfx(btn: BaseButton):
	if not btn: return
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))
	btn.pressed.connect(func(): AudioManager.play_sfx("ui_click"))

func setup(winner_id: int):
	if winner_id == 1:
		winner_label.text = "PLAYER 1 WINS!"
		winner_label.modulate = Color("#ff9999") # Red tint
	elif winner_id == 2:
		winner_label.text = "PLAYER 2 WINS!"
		winner_label.modulate = Color("#99ccff") # Blue tint
	else:
		winner_label.text = "DRAW!"
	
	# ARCADE LOGIC
	if RunManager.is_arcade_mode:
		if winner_id == 1:
			# Player Won
			$Panel/VBoxContainer/RematchButton.text = "CLAIM REWARD"
			$Panel/VBoxContainer/RematchButton.pressed.disconnect(_on_rematch_pressed)
			$Panel/VBoxContainer/RematchButton.pressed.connect(func(): RunManager.handle_win())
		else:
			# Player Lost
			$Panel/VBoxContainer/RematchButton.visible = false # No retry in arcade!
			$Panel/VBoxContainer/MenuButton.text = "RUN OVER"

func _on_rematch_pressed():
	# IMPORTANT: Reset logic ensures stats are clean for new round
	GameManager.reset_combat() 
	# Reload the current arena scene
	get_tree().reload_current_scene()

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
