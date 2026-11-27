extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var container: HBoxContainer = $ScrollContainer/HBoxContainer

const NODE_SCENE: PackedScene = preload("res://Scenes/UI/MapNode.tscn")


var _node_committed: bool = false
var _map_nodes: Array[Control] = []
var _active_node_btn: Button = null
var _scroll_tween: Tween = null


func _ready() -> void:
	_add_nav_hint()
	_generate_map_visuals()


func _add_nav_hint() -> void:
	var hint: Label = Label.new()
	hint.name = "MapNavHint"
	hint.text = "◀ / ▶ Scroll Bracket   ·   Enter / Space: Enter Current Node"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -30.0
	hint.offset_bottom = -8.0
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0, 0.78))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)


func _generate_map_visuals() -> void:
	for child: Node in container.get_children():
		child.queue_free()
	_map_nodes.clear()
	_active_node_btn = null

	var target_node_control: Control = null
	var focusable_buttons: Array[Button] = []

	for i: int in range(RunManager.tournament_map.size()):
		var data: MapNodeData = RunManager.tournament_map[i]
		var node_instance: Control = NODE_SCENE.instantiate() as Control
		container.add_child(node_instance)
		_map_nodes.append(node_instance)

		node_instance.call("setup", data, i)
		node_instance.connect("node_clicked", _on_node_clicked)
		if node_instance.has_signal("node_focused"):
			node_instance.connect("node_focused", _on_node_focused)

		var btn: Button = node_instance.call("get_focus_button") as Button if node_instance.has_method("get_focus_button") else null
		if btn != null and not btn.disabled:
			focusable_buttons.append(btn)
			if i == RunManager.current_map_index:
				_active_node_btn = btn

		if i == RunManager.current_map_index:
			target_node_control = node_instance

	for j: int in range(focusable_buttons.size()):
		var b: Button = focusable_buttons[j]
		if j > 0:
			b.focus_neighbor_left = b.get_path_to(focusable_buttons[j - 1])
		if j + 1 < focusable_buttons.size():
			b.focus_neighbor_right = b.get_path_to(focusable_buttons[j + 1])

	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return

	_draw_connections()

	if target_node_control:
		_scroll_to_node(target_node_control)
	if is_instance_valid(_active_node_btn):
		_active_node_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _node_committed or Pausemenu.visible:
		return
	if event.is_action_pressed("ui_left"):
		scroll_container.scroll_horizontal = maxi(0, scroll_container.scroll_horizontal - 220)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		scroll_container.scroll_horizontal += 220
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null and is_instance_valid(_active_node_btn):
			_active_node_btn.grab_focus()
			_on_node_clicked(RunManager.current_map_index)
			get_viewport().set_input_as_handled()


func _on_node_focused(node_control: Control) -> void:
	if is_instance_valid(node_control):
		_scroll_to_node(node_control, 0.3)


func _scroll_to_node(target: Control, duration: float = 0.8) -> void:
	var node_center_x: float = target.position.x + (target.size.x / 2.0)
	var screen_center_x: float = scroll_container.size.x / 2.0
	var final_scroll_x: float = maxf(0.0, node_center_x - screen_center_x)

	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_property(scroll_container, "scroll_horizontal", int(final_scroll_x), duration)


func _draw_connections() -> void:
	var line: Line2D = Line2D.new()
	line.width = 6.0
	line.default_color = Color(0.6, 0.6, 0.6)

	container.add_child(line)
	container.move_child(line, 0)

	for child_node: Node in container.get_children():
		if child_node is Control and child_node != line:
			var ctrl: Control = child_node as Control
			var center: Vector2 = ctrl.position + (ctrl.size / 2.0)
			line.add_point(center)


func _on_node_clicked(index: int) -> void:
	if _node_committed or index < 0 or index >= RunManager.tournament_map.size():
		return
	var data: MapNodeData = RunManager.tournament_map[index]
	if data.is_locked or data.is_completed:
		return
	_node_committed = true
	match data.type:
		MapNodeData.Type.FIGHT, MapNodeData.Type.BOSS:
			_start_fight(data)
		MapNodeData.Type.GYM:
			_enter_gym(data)
		MapNodeData.Type.EVENT:
			_enter_event(data)


func _start_fight(data: MapNodeData) -> void:
	RunManager.start_map_fight(data)


func _enter_gym(_data: MapNodeData) -> void:
	print("Entering Gym...")
	SceneLoader.change_scene("res://Scenes/Gym.tscn")


func _enter_event(_data: MapNodeData) -> void:
	print("Entering Event Room...")
	SceneLoader.change_scene("res://Scenes/EventRoom.tscn")
