extends Control

# --- UI REFERENCES ---
@onready var class_grid = $MarginContainer/VBoxContainer/HBoxContainer/ClassScroll/ClassList
@onready var info_label = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/InfoLabel
@onready var portrait_rect = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/P1_Portrait

# Settings
@onready var difficulty_option = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DifficultyOption
@onready var maintain_hp_toggle = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/MaintainHPToggle
@onready var start_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/StartButton

@onready var name_input = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/NameInput # <--- New Ref

# --- DATA ---
@export var base_classes: Array[ClassDefinition]

# --- STATE ---
var selected_index: int = 0
var buttons: Array[Button] = []
var selected_save_file: String = "" # Empty means "New Run Mode"


func _ready():
	_setup_difficulty()
	_generate_grid() # Renamed from _generate_class_grid for clarity
	
	start_btn.pressed.connect(_on_start_pressed)
	
	# Default Name
	name_input.text = "Hero-" + str(randi() % 1000)
	
	_select_class(0)
	
# --- NEW: GRID GENERATION ---
func _generate_grid():
	# Clear children...
	for child in class_grid.get_children(): child.queue_free()
	buttons.clear()
	
	# 1. NEW RUN BUTTONS (Base Classes)
	for i in range(base_classes.size()):
		var def = base_classes[i]
		_create_grid_button(i, def.class_named, def.portrait, false)

	# 2. LOAD RUN BUTTONS (Save Files)
	var saves = RunManager.get_save_files()
	if saves.size() > 0:
		# Divider
		# (Optional: Add a label or separator here if using a VBox, but GridContainer handles flow)
		pass
		
	for i in range(saves.size()):
		var filename = saves[i]
		# Pass a generic "Floppy Disk" icon or reuse a portrait if you want
		# Using a higher index range to distinguish saves
		var save_index = 100 + i 
		_create_grid_button(save_index, filename.replace(".save", ""), null, true)

func _create_grid_button(index: int, text: String, icon: Texture2D, is_save: bool):
	var btn = Button.new()
	btn.text = text
	btn.icon = icon
	if is_save:
		# Use a default icon or color for saves
		btn.modulate = Color(0.6, 0.8, 1.0) # Blue tint
	else:
		btn.expand_icon = true
	
	# ... (Standard Layout Code) ...
	btn.custom_minimum_size = Vector2(140, 160)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_text = true
	
	btn.pressed.connect(func(): _on_item_selected(index, text, is_save))
	class_grid.add_child(btn)
	buttons.append(btn)

# --- INTERACTION ---
func _on_class_hover(index: int):
	AudioManager.play_sfx("ui_hover", 0.1)
	_update_preview_panel(index)

func _select_class(index: int):
	AudioManager.play_sfx("ui_click")
	selected_index = index
	
	# Visual Feedback: Highlight the border/text of the selected character
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == index:
			# Selected Style: Green Text, maybe Modulate slightly?
			btn.add_theme_color_override("font_color", Color.GREEN)
			btn.modulate = Color(1.2, 1.2, 1.2) # Brighten
		else:
			# Normal Style
			btn.remove_theme_color_override("font_color")
			btn.modulate = Color.WHITE
			
	_update_preview_panel(index)

func _update_preview_panel(index: int):
	if index >= base_classes.size(): return
	var data = base_classes[index]
	
	# --- MIDDLE COLUMN: DESCRIPTION ONLY ---
	# (As requested, this focuses on the description/stats)
	
	var txt = "[center][b][font_size=28]" + data.class_named + "[/font_size][/b][/center]\n"
	
	# Playstyle Summary
	if data.playstyle_summary != "":
		txt += "[center][i][color=light_gray]" + data.playstyle_summary + "[/color][/i][/center]\n\n"
	
	# Stats Block
	txt += "[b]HP:[/b] " + str(data.base_hp) + "   [b]SP:[/b] " + str(data.base_sp) + "\n"
	txt += "[b]Speed:[/b] " + str(data.base_speed) + "\n"
	txt += "----------------\n"
	
	# Passive
	txt += "[color=yellow]" + data.passive_description + "[/color]"
	
	info_label.text = txt
	
	# Big Portrait (Optional: You can hide this if you ONLY want text in the middle)
	if portrait_rect:
		portrait_rect.texture = data.portrait

# --- START RUN ---
func _on_start_pressed():
	AudioManager.play_sfx("ui_confirm")
	RunManager.maintain_hp_enabled = maintain_hp_toggle.button_pressed
	
	if selected_save_file != "":
		# LOAD MODE
		RunManager.load_run(selected_save_file)
	else:
		# NEW RUN MODE
		if selected_index < base_classes.size():
			var run_name = name_input.text
			if run_name.strip_edges() == "": run_name = "Unnamed"
			
			RunManager.start_new_run(base_classes[selected_index], run_name)

# --- SETTINGS HELPERS ---
func _setup_difficulty():
	difficulty_option.clear()
	difficulty_option.add_item("Very Easy")
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium")
	difficulty_option.add_item("Hard")
	difficulty_option.selected = 2 # Medium
	
	if not difficulty_option.item_selected.is_connected(_on_difficulty_changed):
		difficulty_option.item_selected.connect(_on_difficulty_changed)

func _on_difficulty_changed(index: int):
	GameManager.ai_difficulty = index as GameManager.Difficulty

func _on_item_selected(index: int, text: String, is_save: bool):
	AudioManager.play_sfx("ui_click")
	
	# Visual Feedback (Reuse your highlight loop)
	for btn in buttons:
		btn.modulate = Color(1,1,1) if btn != buttons.back() else Color(0.6, 0.8, 1.0) # Reset
		# (Add your green highlight logic here)

	if is_save:
		selected_save_file = text + ".save"
		start_btn.text = "LOAD RUN"
		name_input.editable = false
		name_input.text = text # Show name of save
		
		# Show simple info
		info_label.text = "[center][b]SAVED RUN[/b][/center]\n\n" + text
		portrait_rect.texture = null 
		
	else:
		selected_save_file = "" # Reset to New Run mode
		selected_index = index # Store class index
		start_btn.text = "START RUN"
		name_input.editable = true
		
		# Update Preview normally
		_update_preview_panel(index)
