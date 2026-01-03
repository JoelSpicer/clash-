# LinesLayer.gd
extends Control

@export var line_color: Color = Color.WHITE
@export var line_width: float = 2.0

func _draw():
	var tree_root = get_parent()
	var dict = tree_root.action_tree_dict
	var nodes_container = tree_root.nodes_layer
	
	# We need to find where the nodes are
	var node_map = {}
	for child in nodes_container.get_children():
		node_map[int(str(child.name))] = child
		
	# Draw lines
	for start_id in dict:
		if not start_id in node_map: continue
		var start_node = node_map[start_id]
		var start_pos = start_node.position + (start_node.size / 2)
		
		for end_id in dict[start_id]:
			if not end_id in node_map: continue
			var end_node = node_map[end_id]
			var end_pos = end_node.position + (end_node.size / 2)
			
			draw_line(start_pos, end_pos, line_color, line_width)
