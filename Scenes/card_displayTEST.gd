extends "C:/Users/joely/Desktop/Godot_v4.5.1-stable_win64.exe/clash/Scenes/card_display.gd"

# Drag one of your Action Resources here in the Inspector
@export var test_action: ActionData 

func _ready():
	if test_action:
		set_card_data(test_action)
