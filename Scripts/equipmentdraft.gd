extends Control

@onready var item_grid = $ColorRect/ItemGrid

func _ready():
	# 1. Get all available equipment
	var all_items = RunManager.get_all_equipment()
	all_items.shuffle() # Randomize the list
	
	# 2. Pick the top 3 (or fewer if you haven't made 3 items yet)
	var options = []
	for i in range(min(3, all_items.size())):
		options.append(all_items[i])
		
	# 3. Create Buttons
	for item in options:
		var btn = _create_item_button(item)
		item_grid.add_child(btn)

func _create_item_button(item: EquipmentData) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(250, 350)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)
	
	# Content Container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	btn.add_child(vbox)
	
	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size.y = 100
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = item.icon if item.icon else preload("res://icon.svg")
	vbox.add_child(icon)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = item.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_lbl)
	
	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_lbl)
	
	# Click Logic
	btn.pressed.connect(func(): _on_item_selected(item))
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))
	
	return btn

func _on_item_selected(item: EquipmentData):
	AudioManager.play_sfx("ui_click")
	print("Equipped: " + item.display_name)
	
	# 1. Add to inventory
	RunManager.player_run_data.equipment.append(item)
	
	# 2. Recalculate stats immediately so max HP/SP increases
	ClassFactory._recalculate_stats(RunManager.player_run_data)
	
	# 3. Proceed to the Action Tree for the card reward
	SceneLoader.change_scene("res://Scenes/ActionTree.tscn")
