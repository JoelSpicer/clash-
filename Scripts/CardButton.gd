extends Button

# Signal to tell the UI "I was clicked" or "I am being hovered"
signal card_hovered(action)
signal card_selected(action)

var my_action: ActionData

func setup(action: ActionData):
	my_action = action
	text = action.display_name 
	$CostLabel.text = str(action.cost) + " SP"
	
	if action.type == ActionData.Type.OFFENCE:
		add_theme_color_override("font_color", Color("#ff9999")) 
	else:
		add_theme_color_override("font_color", Color("#99ccff")) 

# NEW: Toggle availability visual state
func set_available(is_affordable: bool):
	disabled = not is_affordable
	
	if is_affordable:
		modulate = Color(1, 1, 1, 1) # Normal
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.5) # Greyed out and transparent
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

func _pressed():
	if not disabled:
		emit_signal("card_selected", my_action)

func _on_mouse_entered():
	emit_signal("card_hovered", my_action)
