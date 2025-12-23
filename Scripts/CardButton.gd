extends Button

# Signal to tell the UI "I was clicked" or "I am being hovered"
signal card_hovered(action)
signal card_selected(action)

var my_action: ActionData

func setup(action: ActionData):
	my_action = action
	text = action.display_name # The main button text
	$CostLabel.text = str(action.cost) + " SP"
	
	# Color coding text based on type
	if action.type == ActionData.Type.OFFENCE:
		add_theme_color_override("font_color", Color("#ff9999")) # Light Red
	else:
		add_theme_color_override("font_color", Color("#99ccff")) # Light Blue

func _pressed():
	emit_signal("card_selected", my_action)

func _on_mouse_entered() -> void:
	emit_signal("card_hovered", my_action)
