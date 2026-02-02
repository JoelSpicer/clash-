extends "res://Scripts/CardDisplay.gd"

# Drag one of your Action Resources here in the Inspector
@export var test_action: ActionData 

func _ready():
	if test_action:
		set_card_data(test_action)
