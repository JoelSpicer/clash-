extends Control

# --- TESTING TOGGLE ---
# Check this box in the Inspector to instantly skip the splash screen!
@export var skip_splash: bool = false
@export var next_scene: String = "res://Scenes/MainMenu.tscn"

@onready var logo = $Logo

func _ready():
	# 1. THE BYPASS
	# If we are testing, or if the skip toggle is on, go straight to menu.
	if skip_splash:
		SceneLoader.change_scene(next_scene)
		return
		
	# 2. INITIAL SETUP
	logo.modulate.a = 0.0 # Start completely transparent
	
	# Optional: Play a subtle sound effect for your studio logo
	# AudioManager.play_sfx("ui_hover") 
	
	# 3. THE ANIMATION SEQUENCE
	var tween = create_tween()
	
	# Fade In (Takes 1.5 seconds)
	tween.tween_property(logo, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	
	# Hold on screen (Wait 2 seconds)
	tween.tween_interval(1.0)
	
	# Fade Out (Takes 1.5 seconds)
	tween.tween_property(logo, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	
	# When the animation finishes, change the scene!
	tween.tween_callback(_go_to_menu)

func _go_to_menu():
	SceneLoader.change_scene(next_scene)

# Allow the player to skip it manually by pressing any key/clicking
func _input(event):
	if skip_splash: return # Don't do anything if we already skipped
	
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			# Instantly jump to menu if they click
			_go_to_menu()
