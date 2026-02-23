class_name SoundButton
extends Button

func _ready():
	# Connect the standard mouse interactions
	mouse_entered.connect(_on_hover)
	pressed.connect(_on_pressed)
	
	# Connect focus for controller/keyboard menu navigation!
	focus_entered.connect(_on_hover)

func _on_hover():
	# Don't play hover sound if the button is disabled
	if not disabled:
		AudioManager.play_sfx("ui_hover", 0.2)

func _on_pressed():
	AudioManager.play_sfx("ui_click")
