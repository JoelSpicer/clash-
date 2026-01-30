extends Button

# Signals for UI Interaction
signal card_hovered(action)
signal card_exited()
signal card_selected(action)

var my_action: ActionData
var original_z_index: int = 0

func _ready():
	# CRITICAL: Set pivot to center so it scales symmetrically
	pivot_offset = size / 2
	original_z_index = z_index

func setup(action: ActionData):
	my_action = action
	text = action.display_name 
	
	# Ensure the label exists before trying to access it
	if has_node("CostLabel"):
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
		# Small "press" squash animation
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
		
		emit_signal("card_selected", my_action)

func _on_mouse_entered():
	if disabled: return
	
	emit_signal("card_hovered", my_action)
	
	# 1. Bring to front so it overlaps neighbors
	z_index = 10 
	
	# 2. Pop Animation (Scale Up + Slight Tilt)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Scale up to 110%
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
	
	# Random slight tilt (-2 to 2 degrees) for organic feel
	var random_tilt = randf_range(-2.0, 2.0)
	tween.tween_property(self, "rotation_degrees", random_tilt, 0.15)

func _on_mouse_exited():
	emit_signal("card_exited")
	
	# 1. Reset Layer
	z_index = original_z_index
	
	# 2. Reset Animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.1)

# Dynamically updates cost text
func update_cost_display(new_cost: int):
	if not has_node("CostLabel"): return
	
	$CostLabel.text = str(new_cost) + " SP"
	
	if new_cost < my_action.cost:
		$CostLabel.modulate = Color(0.5, 1.0, 0.5) # Green text for discount
	else:
		$CostLabel.modulate = Color(1, 1, 1)
