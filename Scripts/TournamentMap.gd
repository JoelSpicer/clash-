extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var container: HBoxContainer = $ScrollContainer/HBoxContainer

const NODE_SCENE: PackedScene = preload("res://Scenes/UI/MapNode.tscn")


func _ready() -> void:
	_generate_map_visuals()


func _generate_map_visuals() -> void:
	for child: Node in container.get_children():
		child.queue_free()

	var target_node_control: Control = null

	for i: int in range(RunManager.tournament_map.size()):
		var data: MapNodeData = RunManager.tournament_map[i]
		var node_instance: Control = NODE_SCENE.instantiate() as Control
		container.add_child(node_instance)

		node_instance.call("setup", data, i)
		node_instance.connect("node_clicked", _on_node_clicked)

		if i == RunManager.current_map_index:
			target_node_control = node_instance

	await get_tree().process_frame
	await get_tree().process_frame

	_draw_connections()

	if target_node_control:
		_scroll_to_node(target_node_control)


func _scroll_to_node(target: Control) -> void:
	var node_center_x: float = target.position.x + (target.size.x / 2.0)
	var screen_center_x: float = scroll_container.size.x / 2.0
	var final_scroll_x: float = node_center_x - screen_center_x

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_container, "scroll_horizontal", int(final_scroll_x), 0.8)


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
	var data: MapNodeData = RunManager.tournament_map[index]
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
