class_name SoundButton
extends Button


func _ready() -> void:
	mouse_entered.connect(_on_hover)
	pressed.connect(_on_pressed)
	focus_entered.connect(_on_hover)


func _on_hover() -> void:
	if not disabled:
		AudioManager.play_sfx("ui_hover", 0.2)


func _on_pressed() -> void:
	AudioManager.play_sfx("ui_click")
