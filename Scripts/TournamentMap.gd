extends Control

@onready var scroll_container = $ScrollContainer # We need reference to the ScrollView itself
@onready var container = $ScrollContainer/HBoxContainer

var node_scene = preload("res://Scenes/UI/MapNode.tscn")

func _ready():
	_generate_map_visuals()

func _generate_map_visuals():
	# Clear previous children
	for child in container.get_children():
		child.queue_free()
	
	var target_node_control = null # Variable to hold the node we want to look at
	
	# Loop through the data
	for i in range(RunManager.tournament_map.size()):
		var data = RunManager.tournament_map[i]
		
		var node_instance = node_scene.instantiate()
		container.add_child(node_instance)
		
		node_instance.setup(data, i)
		node_instance.node_clicked.connect(_on_node_clicked)
		
		# --- NEW: Capture the node we are currently on ---
		if i == RunManager.current_map_index:
			target_node_control = node_instance

	# Wait for layout to calculate sizes
	await get_tree().process_frame
	await get_tree().process_frame
	
	_draw_connections()
	
	# --- NEW: SCROLL TO NODE ---
	# We do this AFTER drawing connections so the line is behind the nodes
	if target_node_control:
		_scroll_to_node(target_node_control)

func _scroll_to_node(target: Control):
	# 1. Calculate the center of the target node
	# (Node Position + Half its width)
	var node_center_x = target.position.x + (target.size.x / 2)
	
	# 2. Calculate the center of the screen/scroll view
	var screen_center_x = scroll_container.size.x / 2
	
	# 3. Determine the scroll position
	# We want the Node Center to be at Screen Center.
	# So we subtract the screen half-width from the node's position.
	var final_scroll_x = node_center_x - screen_center_x
	
	# 4. Animate it smoothly (The "Juice")
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_container, "scroll_horizontal", final_scroll_x, 0.8)

# --- VISUAL FLUFF: CONNECTING LINES ---
func _draw_connections():
	var line = Line2D.new()
	line.width = 6 
	line.default_color = Color(0.6, 0.6, 0.6) 
	
	container.add_child(line)
	container.move_child(line, 0) # This puts the line at index 0
	
	for child_node in container.get_children():
		if child_node is Control and child_node != line:
			var center = child_node.position + (child_node.size / 2.0)
			line.add_point(center)

func _on_node_clicked(index: int):
	# ... (Keep existing logic) ...
	var data = RunManager.tournament_map[index]
	match data.type:
		MapNodeData.Type.FIGHT, MapNodeData.Type.BOSS:
			_start_fight(data)
		MapNodeData.Type.GYM:
			_enter_gym(data)

func _start_fight(data: MapNodeData):
	RunManager.start_map_fight(data)

func _enter_gym(_data: MapNodeData):
	print("Entering Gym...")
	SceneLoader.change_scene("res://Scenes/Gym.tscn")
