extends Button

# Signals for UI Interaction
signal card_hovered(action)
signal card_selected(action)

var my_action: ActionData

func setup(action: ActionData):
	my_action = action
	text = action.display_name 
	$CostLabel.text = str(action.cost) + " SP"
	
	# Visual Theme
	if action.type == ActionData.Type.OFFENCE:
		add_theme_color_override("font_color", Color("#ff9999")) 
	else:
		add_theme_color_override("font_color", Color("#99ccff")) 

# Handles grey-out/disable logic
func set_available(is_affordable: bool):
	disabled = not is_affordable
	
	if is_affordable:
		modulate = Color(1, 1, 1, 1) # Normal opacity
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.5) # Greyed out
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

func _pressed():
	if not disabled:
		emit_signal("card_selected", my_action)

func _on_mouse_entered():
	emit_signal("card_hovered", my_action)

# Dynamically updates cost text (e.g. for Opportunity discounts)
func update_cost_display(new_cost: int):
	$CostLabel.text = str(new_cost) + " SP"
	
	if new_cost < my_action.cost:
		$CostLabel.modulate = Color(0.5, 1.0, 0.5) # Green text for discount
	else:
		$CostLabel.modulate = Color(1, 1, 1)
