# ActionNode.gd
extends TextureButton

signal action_clicked(node_id, node_name)

var id: int = 0
var action_name: String = ""
var status: int = 0 # 0: Locked, 1: Available, 2: Owned

@onready var label = $Label
@onready var background = $Panel # Make sure you add a Panel or TextureRect for visuals

func setup(new_id: int, new_name: String):
	id = new_id
	action_name = new_name
	label.text = str(id) # Or use action_name if you have space
	
	# Set tooltip to name so hovering shows what it is
	tooltip_text = action_name

func set_status(new_status: int):
	status = new_status
	match status:
		0: # LOCKED
			modulate = Color(0.3, 0.3, 0.3) # Dark Grey
			disabled = true
		1: # AVAILABLE (Can buy)
			modulate = Color(1, 1, 0) # Yellow
			disabled = false
		2: # OWNED
			modulate = Color(0, 1, 0) # Green
			disabled = false

func _pressed():
	action_clicked.emit(id, action_name)
