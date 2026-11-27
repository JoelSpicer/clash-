extends SoundButton

signal card_hovered(action: ActionData)
signal card_exited()
signal card_selected(action: ActionData)

# --- NODES ---
@onready var title_label: Label = $InnerMargin/VBox/TitleLabel
@onready var cost_label: Label = $InnerMargin/VBox/CostPanel/CostLabel
@onready var type_icon: Label = $InnerMargin/VBox/IconContainer/TypeIcon
@onready var card_border: Panel = $CardBorder
@onready var card_background: Control = $CardBackground

var my_action: ActionData
var current_ghost: Control = null
var _hotkey_label: Label = null

# --- STYLING CONSTANTS ---
const COL_OFFENCE: Color = Color("#ff6666")
const COL_DEFENCE: Color = Color("#66a3ff")


func _ready() -> void:
	super._ready()
	pivot_offset = size / 2.0
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)


func _exit_tree() -> void:
	if is_instance_valid(current_ghost):
		current_ghost.queue_free()
		current_ghost = null


func setup(action: ActionData) -> void:
	my_action = action
	title_label.text = action.display_name
	update_cost_display(action.cost)

	var style: StyleBoxFlat = card_border.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if action.type == ActionData.Type.OFFENCE:
		style.border_color = COL_OFFENCE
		type_icon.text = "⚔️"
		if action.damage > 3:
			type_icon.text = "💥"
	elif action.type == ActionData.Type.DEFENCE:
		style.border_color = COL_DEFENCE
		type_icon.text = "🛡️"
		if action.dodge_value > 0:
			type_icon.text = "💨"

	if action.heal_value > 0:
		type_icon.text = "❤️"
	if action.statuses_to_apply.size() > 0:
		type_icon.text = "☠️"

	card_border.add_theme_stylebox_override("panel", style)

	var cost_style: StyleBoxFlat = StyleBoxFlat.new()
	cost_style.bg_color = Color(0, 0, 0, 0.5)
	cost_style.set_corner_radius_all(4)
	$InnerMargin/VBox/CostPanel.add_theme_stylebox_override("panel", cost_style)


func set_hotkey_hint(key_num: int) -> void:
	if key_num < 1 or key_num > 9:
		if _hotkey_label != null:
			_hotkey_label.visible = false
		return

	if _hotkey_label == null:
		_hotkey_label = Label.new()
		_hotkey_label.name = "HotkeyHint"
		_hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotkey_label.position = Vector2(6.0, 4.0)
		_hotkey_label.add_theme_font_size_override("font_size", 11)
		_hotkey_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.78))
		_hotkey_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_hotkey_label.add_theme_constant_override("outline_size", 3)
		add_child(_hotkey_label)

	_hotkey_label.text = "[" + str(key_num) + "]"
	_hotkey_label.visible = true


func set_available(is_affordable: bool) -> void:
	disabled = not is_affordable
	if is_affordable:
		modulate = Color(1, 1, 1, 1)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card_background.self_modulate = Color(1, 1, 1)
	else:
		modulate = Color(0.7, 0.7, 0.7, 0.8)
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		card_background.self_modulate = Color(0.3, 0.3, 0.3)


func update_cost_display(new_cost: int) -> void:
	if not cost_label:
		return
	cost_label.text = str(new_cost) + " SP"
	if new_cost == 0 or (my_action != null and new_cost < my_action.cost):
		cost_label.modulate = Color(0.5, 1.0, 0.5)
	else:
		cost_label.modulate = Color.WHITE


# --- GHOST LOGIC ---

func _on_mouse_entered() -> void:
	if disabled:
		return
	card_hovered.emit(my_action)
	if not is_instance_valid(current_ghost):
		_create_ghost()


func _on_mouse_exited() -> void:
	if has_focus():
		return
	_clear_hover_state()


func _on_focus_entered() -> void:
	if disabled:
		return
	card_hovered.emit(my_action)
	if not is_instance_valid(current_ghost):
		_create_ghost()


func _on_focus_exited() -> void:
	_clear_hover_state()


func _clear_hover_state() -> void:
	card_exited.emit()

	if is_instance_valid(current_ghost):
		current_ghost.queue_free()
		current_ghost = null

	self.modulate.a = 1.0


func _pressed() -> void:
	if not disabled:
		AudioManager.play_sfx("ui_click")
		if current_ghost:
			var tween: Tween = create_tween()
			tween.tween_property(current_ghost, "scale", Vector2(0.95, 0.95), 0.05)
			tween.tween_property(current_ghost, "scale", Vector2(1.1, 1.1), 0.05)

		card_selected.emit(my_action)


func _create_ghost() -> void:
	var ui_layer: Node = _get_ui_layer()
	if not ui_layer:
		return

	current_ghost = self.duplicate(0) as Control
	_make_ghost_ignore_mouse(current_ghost)
	ui_layer.add_child(current_ghost)

	current_ghost.global_position = self.global_position
	current_ghost.size = self.size
	current_ghost.pivot_offset = self.pivot_offset
	current_ghost.z_index = 100

	self.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(current_ghost, "scale", Vector2(1.15, 1.15), 0.15)
	tween.tween_property(current_ghost, "rotation_degrees", randf_range(-3.0, 3.0), 0.15)

	var ghost_border: CanvasItem = current_ghost.get_node_or_null("CardBorder") as CanvasItem
	if ghost_border:
		ghost_border.modulate = Color(1.3, 1.3, 1.3)


func _make_ghost_ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in node.get_children():
		_make_ghost_ignore_mouse(child)


func _get_ui_layer() -> Node:
	var parent: Node = get_parent()
	while parent:
		if parent is CanvasLayer:
			return parent
		parent = parent.get_parent()
	return get_tree().current_scene
