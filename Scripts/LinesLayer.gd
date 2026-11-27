extends Control

@export var line_color: Color = Color.WHITE
@export var line_width: float = 2.0


func _draw() -> void:
	var tree_root: Node = owner
	if not tree_root or not ("action_tree_dict" in tree_root):
		return

	var dict: Dictionary = tree_root.get("action_tree_dict") as Dictionary
	var nodes_container: Node = tree_root.get("nodes_layer") as Node
	if not nodes_container:
		return

	var node_map: Dictionary = {}
	for child: Node in nodes_container.get_children():
		node_map[int(str(child.name))] = child

	for start_id: Variant in dict:
		if not (start_id in node_map):
			continue
		var start_node: Control = node_map[start_id] as Control
		var start_pos: Vector2 = start_node.position + (start_node.size / 2.0)

		for end_id: Variant in dict[start_id]:
			if not (end_id in node_map):
				continue
			var end_node: Control = node_map[end_id] as Control
			var end_pos: Vector2 = end_node.position + (end_node.size / 2.0)
			draw_line(start_pos, end_pos, line_color, line_width)
