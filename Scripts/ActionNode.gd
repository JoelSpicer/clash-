extends TextureButton

signal action_clicked(node_id, node_name)
signal hovered(node_id, node_name)
signal exited()

# Define status constants for readability
const STATUS_LOCKED = 0
const STATUS_AVAILABLE = 1
const STATUS_OWNED = 2

var id: int = 0
var action_name: String = ""
var status: int = STATUS_LOCKED

# Variables to hold the visual parts
var label: Label
var background: Panel

func _ready():
	# 1. VISUAL REPAIR
	if get_child_count() == 0:
		_build_ui()
	else:
		label = get_node_or_null("Label")
		background = get_node_or_null("Panel")
	
	# --- FIX 1: FORCE MOUSE IGNORE ON CHILDREN ---
	# This ensures the label/panel never block the hover signal
	if label: label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if background: background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ---------------------------------------------
	
	# 2. SIZE REPAIR
	if size.x < 40 or size.y < 40:
		custom_minimum_size = Vector2(50, 50)
		size = Vector2(50, 50)
		
	mouse_entered.connect(func(): 
		hovered.emit(id, action_name)
		AudioManager.play_sfx("ui_hover", 0.2) # <--- NEW
	)
	mouse_exited.connect(func(): exited.emit())	

func _build_ui():
	background = Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	label = Label.new()
	label.text = name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)

func setup(new_id: int, new_name: String):
	id = new_id
	action_name = new_name
	if label: label.text = str(id)
	tooltip_text = ""

func set_status(new_status: int):
	status = new_status
	disabled = false # Always enabled to allow tooltips
	
	if background:
		match status:
			STATUS_LOCKED:
				background.modulate = Color(0.2, 0.2, 0.2) 
			STATUS_AVAILABLE:
				background.modulate = Color(1, 1, 0) 
			STATUS_OWNED:
				background.modulate = Color(0, 1, 0)

func _pressed():
	action_clicked.emit(id, action_name)
