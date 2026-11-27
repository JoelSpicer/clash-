# Scripts/UI/MapNode.gd
extends PanelContainer

signal node_clicked(index: int)
signal node_focused(node_control: Control)

@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var label: Label = $VBoxContainer/Label
@onready var enemy_name_label: Label = $VBoxContainer/EnemyNameLabel
@onready var status: Label = $VBoxContainer/Status
@onready var button: Button = $Button

var my_index: int = -1
var data: MapNodeData


func setup(node_data: MapNodeData, index: int) -> void:
	my_index = index
	data = node_data
	
	# 1. Set Node Title (e.g., "Round 1", "FINALS")
	label.text = node_data.title
	
	# 2. POPULATE ENEMY DATA OR FALLBACKS
	if node_data.enemy_data != null:
		# It's a Fight or Boss!
		enemy_name_label.show()
		var epithets: Array[String] = []
		var trait_tips: Array[String] = []
		for eq: EquipmentData in node_data.enemy_data.equipment:
			if eq == null:
				continue
			var ep: Variant = eq.get("boss_epithet")
			if ep != null and str(ep) != "":
				epithets.append(str(ep))
			if eq.description != "":
				trait_tips.append("%s: %s" % [eq.item_name, eq.description])
			else:
				trait_tips.append(eq.item_name)

		if not epithets.is_empty():
			enemy_name_label.text = "%s\n(%s)" % [node_data.enemy_data.character_name, " / ".join(epithets)]
		else:
			enemy_name_label.text = node_data.enemy_data.character_name

		var class_str: String = ClassFactory.class_enum_to_string(node_data.enemy_data.class_type)
		var scout_tip: String = "%s [%s]\nHP: %d  |  SP: %d" % [
			node_data.enemy_data.character_name,
			class_str,
			node_data.enemy_data.max_hp,
			node_data.enemy_data.max_sp
		]
		if not trait_tips.is_empty():
			scout_tip += "\n" + "\n".join(trait_tips)
		if not node_data.is_locked:
			tooltip_text = scout_tip
			button.tooltip_text = scout_tip
		else:
			tooltip_text = "Locked — defeat earlier rounds to scout this opponent."
			button.tooltip_text = tooltip_text

		if node_data.enemy_data.portrait:
			icon.texture = node_data.enemy_data.portrait
		else:
			icon.texture = preload("res://Art/Icons/icon_Opportunity.png")

		if node_data.type == MapNodeData.Type.BOSS:
			modulate = Color(1.5, 1.0, 1.0)
		else:
			modulate = Color(1.0, 1.0, 1.0)
			
	else:
		# It's a Gym, Shop, or Event (No enemy)
		enemy_name_label.hide() # Hide the name label completely
		
		if node_data.type == MapNodeData.Type.GYM:
			icon.texture = preload("res://Art/Icons/icon_Bide.png")
			modulate = Color(1.0, 1.0, 1.5) # Blue tint
		elif node_data.type == MapNodeData.Type.EVENT:
			icon.texture = preload("res://Art/Icons/icon_Opportunity.png")
			modulate = Color(1.4, 1.25, 0.7) # Warm gold tint
	
	# 3. Handle Status (Locked/Completed/Ready)
	if node_data.is_completed:
		status.text = "VICTORY"
		status.modulate = Color.GREEN
		modulate.a = 0.5 # Dim it
		button.disabled = true
	elif node_data.is_locked:
		status.text = "LOCKED"
		status.modulate = Color.GRAY
		button.disabled = true
		
		# Optional juice: Hide the enemy portrait if locked to keep it a "mystery"
		icon.modulate = Color(0, 0, 0) # Silhouette
		enemy_name_label.text = "???"
	else:
		status.text = "READY"
		status.modulate = Color.YELLOW
		button.disabled = false
		
		# --- NEW: RIVALRY DETECTOR ---
		if RunManager.active_sponsor and data.enemy_data:
			if data.enemy_data.character_name == RunManager.active_sponsor.rival_character_name:
				label.text = "GRUDGE MATCH"
				label.modulate = Color(1.0, 0.2, 0.2) # Bright Red Text
				status.text = "! WARNING !"
				status.modulate = Color.RED
				modulate = Color(1.5, 0.8, 0.8) # Tint the whole panel red
		# ------------------------------
		
		# Juice: Make the current node pulse!
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.5)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

	# Clear focus outline so keyboard/gamepad users can browse the bracket cleanly
	var focus_style: StyleBoxFlat = StyleBoxFlat.new()
	focus_style.bg_color = Color(1.0, 0.88, 0.25, 0.14)
	focus_style.border_color = Color(1.0, 0.9, 0.3)
	focus_style.set_border_width_all(3)
	focus_style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus_style)


func get_focus_button() -> Button:
	return button


func _on_button_pressed() -> void:
	node_clicked.emit(my_index)


func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	button.focus_entered.connect(func() -> void: node_focused.emit(self))
	pivot_offset = size / 2.0
