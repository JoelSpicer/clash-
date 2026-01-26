extends CanvasLayer

@onready var background = $ColorRect # Assuming your ColorRect is named "ColorRect"

func _ready():
	# Start hidden and unpaused
	visible = false
	
func _input(event):
	if event.is_action_pressed("ui_cancel"): # Default is 'Escape' key
		_toggle_pause()

func _toggle_pause():
	# Flip the paused state
	var new_state = not get_tree().paused
	get_tree().paused = new_state
	visible = new_state

func _on_resume_pressed():
	_toggle_pause()

func _on_main_menu_pressed():
	# 1. Unpause before changing scenes (otherwise the new scene stays frozen!)
	_toggle_pause()
	
	# 2. CLEANUP: Wipe game state so next match starts fresh
	# (Similar to your ActionTree back button logic) [cite: 121]
	GameManager.next_match_p1_data = null
	GameManager.next_match_p2_data = null
	GameManager.p1_data = null
	GameManager.p2_data = null
	
	GameManager.editing_player_index = 1
	GameManager.p2_is_custom = false
	
	# 3. Go to Menu
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
