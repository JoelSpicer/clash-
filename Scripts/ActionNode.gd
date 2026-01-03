extends TextureButton

signal action_clicked(node_id, node_name)

var id: int = 0
var action_name: String = ""
var status: int = 0 

# Variables to hold the visual parts
var label: Label
var background: Panel

func _ready():
	# 1. VISUAL REPAIR: If the button is empty, build the UI automatically
	if get_child_count() == 0:
		_build_ui()
	else:
		# If children exist (e.g. you added them manually), grab refs
		label = get_node_or_null("Label")
		background = get_node_or_null("Panel")
	
	# 2. SIZE REPAIR: Ensure it's not invisible (0x0)
	if size.x < 40 or size.y < 40:
		custom_minimum_size = Vector2(50, 50)
		size = Vector2(50, 50) # Force immediate update

func _build_ui():
	# Create Background Panel
	background = Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through to button
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Create Label
	label = Label.new()
	label.text = name # Temporary text (Node Name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)

func setup(new_id: int, new_name: String):
	id = new_id
	action_name = new_name
	
	# Update Label
	if label: label.text = str(id)
	
	# Update Tooltip
	tooltip_text = action_name

func set_status(new_status: int):
	status = new_status
	
	# We tint the BACKGROUND panel, not the whole button
	# This keeps the text white and readable
	if background:
		match status:
			0: # LOCKED
				background.modulate = Color(0.2, 0.2, 0.2) # Dark Grey
				disabled = true
			1: # AVAILABLE
				background.modulate = Color(1, 1, 0) # Yellow
				disabled = false
			2: # OWNED
				background.modulate = Color(0, 1, 0) # Green
				disabled = false

func _pressed():
	action_clicked.emit(id, action_name)
