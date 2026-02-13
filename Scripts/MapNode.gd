# Scripts/UI/MapNode.gd
extends PanelContainer

signal node_clicked(index: int)

@onready var icon = $VBoxContainer/Icon
@onready var label = $VBoxContainer/Label
@onready var status = $VBoxContainer/Status
@onready var button = $Button

var my_index: int = -1
var data: MapNodeData

func setup(node_data: MapNodeData, index: int):
	my_index = index
	data = node_data
	
	# 1. Set Title
	label.text = node_data.title
	
	# 2. Set Icon based on Type
	match node_data.type:
		MapNodeData.Type.BOSS:
			icon.texture = preload("res://Art/Icons/icon_Opening.png") # Placeholder
			modulate = Color(1.5, 1.0, 1.0) # Red tint for danger
		MapNodeData.Type.GYM:
			icon.texture = preload("res://Art/Icons/icon_Bide.png") # Placeholder
			modulate = Color(1.0, 1.0, 1.5) # Blue tint
		_:
			# Standard Fight
			# If we generated an enemy, try to show their class icon
			icon.texture = preload("res://Art/Icons/icon_Opportunity.png") # Placeholder
	
	# 3. Handle Status (Locked/Completed)
	if node_data.is_completed:
		status.text = "VICTORY"
		status.modulate = Color.GREEN
		modulate.a = 0.5 # Dim it
		button.disabled = true
	elif node_data.is_locked:
		status.text = "LOCKED"
		status.modulate = Color.GRAY
		button.disabled = true
	else:
		status.text = "READY"
		status.modulate = Color.YELLOW
		button.disabled = false
		
		# Juice: Make the current node pulse!
		var tween = create_tween().set_loops()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.5)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

func _on_button_pressed():
	node_clicked.emit(my_index)

func _ready():
	button.pressed.connect(_on_button_pressed)
