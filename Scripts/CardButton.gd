extends Button

signal card_hovered(action)
signal card_exited()
signal card_selected(action)

# --- NODES ---
@onready var title_label = $InnerMargin/VBox/TitleLabel
@onready var cost_label = $InnerMargin/VBox/CostPanel/CostLabel
@onready var type_icon = $InnerMargin/VBox/IconContainer/TypeIcon
@onready var card_border = $CardBorder
@onready var card_background = $CardBackground

var my_action: ActionData
var current_ghost: Control = null # The floating copy

# --- STYLING CONSTANTS ---
const COL_OFFENCE = Color("#ff6666")
const COL_DEFENCE = Color("#66a3ff")

func _ready():
	pivot_offset = size / 2

func setup(action: ActionData):
	my_action = action
	title_label.text = action.display_name
	update_cost_display(action.cost)
	
	# Apply Styling (Same as before)
	var style = card_border.get_theme_stylebox("panel").duplicate()
	if action.type == ActionData.Type.OFFENCE:
		style.border_color = COL_OFFENCE
		type_icon.text = "⚔️"
		if action.damage > 3: type_icon.text = "💥"
	elif action.type == ActionData.Type.DEFENCE:
		style.border_color = COL_DEFENCE
		type_icon.text = "🛡️"
		if action.dodge_value > 0: type_icon.text = "💨"
		
	if action.heal_value > 0: type_icon.text = "❤️"
	if action.statuses_to_apply.size() > 0: type_icon.text = "☠️"
	
	card_border.add_theme_stylebox_override("panel", style)
	
	var cost_style = StyleBoxFlat.new()
	cost_style.bg_color = Color(0, 0, 0, 0.5)
	cost_style.set_corner_radius_all(4)
	$InnerMargin/VBox/CostPanel.add_theme_stylebox_override("panel", cost_style)

func set_available(is_affordable: bool):
	disabled = not is_affordable
	if is_affordable:
		modulate = Color(1, 1, 1, 1)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card_background.self_modulate = Color(1, 1, 1)
	else:
		modulate = Color(0.7, 0.7, 0.7, 0.8)
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		card_background.self_modulate = Color(0.3, 0.3, 0.3)

func update_cost_display(new_cost: int):
	if not cost_label: return
	cost_label.text = str(new_cost) + " SP"
	if new_cost == 0 or new_cost < my_action.cost:
		cost_label.modulate = Color(0.5, 1.0, 0.5)
	else:
		cost_label.modulate = Color.WHITE

# --- GHOST LOGIC ---

func _on_mouse_entered():
	if disabled: return
	emit_signal("card_hovered", my_action)
	_create_ghost()

func _on_mouse_exited():
	emit_signal("card_exited")
	
	if current_ghost:
		current_ghost.queue_free()
		current_ghost = null
	
	self.modulate.a = 1.0

func _pressed():
	if not disabled:
		if current_ghost:
			var tween = create_tween()
			tween.tween_property(current_ghost, "scale", Vector2(0.95, 0.95), 0.05)
			tween.tween_property(current_ghost, "scale", Vector2(1.1, 1.1), 0.05)
		
		emit_signal("card_selected", my_action)

func _create_ghost():
	var ui_layer = _get_ui_layer()
	if not ui_layer: return
	
	# 1. Duplicate
	current_ghost = self.duplicate(0)
	
	# 2. CRITICAL FIX: Recursively force IGNORE on the ghost AND all its children
	_make_ghost_ignore_mouse(current_ghost)
	
	# 3. Add to UI Layer
	ui_layer.add_child(current_ghost)
	
	# 4. Position & Setup
	current_ghost.global_position = self.global_position
	current_ghost.size = self.size
	current_ghost.pivot_offset = self.pivot_offset
	current_ghost.z_index = 100 
	
	# 5. Hide Real Button
	self.modulate.a = 0.0
	
	# 6. Animate
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(current_ghost, "scale", Vector2(1.15, 1.15), 0.15)
	tween.tween_property(current_ghost, "rotation_degrees", randf_range(-3.0, 3.0), 0.15)
	
	var ghost_border = current_ghost.get_node_or_null("CardBorder")
	if ghost_border:
		ghost_border.modulate = Color(1.3, 1.3, 1.3)

# --- NEW HELPER FUNCTION ---
func _make_ghost_ignore_mouse(node: Node):
	# If this node is a UI Control, tell it to ignore the mouse
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Repeat for every single child, grandchild, etc.
	for child in node.get_children():
		_make_ghost_ignore_mouse(child)

func _get_ui_layer() -> Node:
	var parent = get_parent()
	while parent:
		if parent is CanvasLayer:
			return parent
		parent = parent.get_parent()
	return get_tree().current_scene
