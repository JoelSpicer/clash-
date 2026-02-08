extends Control

# --- UI REFERENCES ---
@onready var class_grid = $MarginContainer/VBoxContainer/HBoxContainer/ClassScroll/ClassList
@onready var info_label = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/InfoLabel
@onready var portrait_rect = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/P1_Portrait

# Settings
@onready var difficulty_option = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DifficultyOption
@onready var maintain_hp_toggle = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/MaintainHPToggle
@onready var start_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/StartButton
@onready var delete_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DeleteButton
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
	#name_input.text = "Fighter No. " + str(randi() % 1000)
	
	_select_class(0)
	
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_pressed)
		delete_btn.hide() # Ensure hidden at start
	
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

# --- UPDATED INTERACTION LOGIC ---

func _on_item_selected(index: int, text: String, is_save: bool):
	AudioManager.play_sfx("ui_click")
	
	# 1. Visual Highlight (Reset others, highlight this)
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == index:
			btn.modulate = Color(1.2, 1.2, 1.2)
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.modulate = Color(1, 1, 1)
			btn.remove_theme_color_override("font_color")

	if is_save:
		# --- SAVE FILE SELECTED ---
		selected_save_file = text + ".save"
		start_btn.text = "LOAD RUN"
		name_input.editable = false
		name_input.text = text
		
		# A. LOAD DATA FOR PREVIEW
		var data = RunManager.peek_save_file(selected_save_file)
		
		if data.is_empty():
			info_label.text = "[color=red]Error: Could not read save file.[/color]"
			return

		# B. LOCK DIFFICULTY (Enforce saved difficulty)
		var saved_diff = int(data.difficulty)
		difficulty_option.selected = saved_diff
		difficulty_option.disabled = true # <--- GRAY OUT
		
		# Force the toggle to match the save file, then disable interaction
		maintain_hp_toggle.button_pressed = data.get("maintain_hp", false)
		maintain_hp_toggle.disabled = true
		
		# C. BUILD STATS STRING
		var p_data = data.player_data
		var identity = p_data.identity
		var stats = p_data.stats
		
		# Header
		var txt = "[center][b][font_size=24]" + data.run_name + "[/font_size][/b][/center]\n"
		txt += "[center][color=gray]Level " + str(data.level) + " - " + _get_difficulty_name(saved_diff) + "[/color][/center]\n\n"
		
		# Core Stats
		txt += "[b]Class:[/b] " + _get_class_name(int(identity.type)) + "\n"
		txt += "[b]HP:[/b] " + str(stats.current_hp) + "/" + str(stats.max_hp) + "   "
		txt += "[b]SP:[/b] " + str(stats.current_sp) + "/" + str(stats.max_sp) + "\n"
		txt += "[b]Opponents Defeated:[/b] " + str(int(data.level) - 1) + "\n"
		
		# Equipment List
		txt += "\n[b]Equipment:[/b]\n"
		if p_data.equipment.size() > 0:
			for item_name in p_data.equipment:
				txt += "• " + item_name + "\n"
		else:
			txt += "[i]None[/i]\n"

		info_label.text = txt
		
		# Portrait (Try to load if path exists, otherwise generic)
		if identity.portrait_path != "":
			portrait_rect.texture = load(identity.portrait_path)
		else:
			portrait_rect.texture = null
		delete_btn.show()

	else:
		# --- NEW RUN SELECTED ---
		selected_save_file = "" 
		selected_index = index
		start_btn.text = "START RUN"
		name_input.editable = true
		
		# UNLOCK DIFFICULTY (Allow player to choose)
		difficulty_option.disabled = false 
		maintain_hp_toggle.disabled = false
		# Show standard Class Preview
		_update_preview_panel(index)
		delete_btn.hide()

# --- HELPER: Reset UI when picking a Base Class ---
func _select_class(index: int):
	# ... (Existing audio/highlight logic) ...
	AudioManager.play_sfx("ui_click")
	selected_index = index
	selected_save_file = "" # Clear save selection
	
	# Reset UI for New Run
	name_input.editable = true
	start_btn.text = "START RUN"
	difficulty_option.disabled = false # <--- RE-ENABLE
	maintain_hp_toggle.disabled = false # <--- RE-ENABLE
	# Highlight buttons...
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == index:
			btn.modulate = Color(1.2, 1.2, 1.2)
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.modulate = Color(1, 1, 1)
			btn.remove_theme_color_override("font_color")
			
	_update_preview_panel(index)

# --- STRING HELPERS ---
func _get_difficulty_name(value: int) -> String:
	match value:
		0: return "Very Easy"
		1: return "Easy"
		2: return "Medium"
		3: return "Hard"
	return "Unknown"

func _get_class_name(type_enum: int) -> String:
	# Matches your ClassType Enum in CharacterData
	match type_enum:
		0: return "Heavy"
		1: return "Patient"
		2: return "Quick"
		3: return "Technical"
		4: return "Mage" # If you added this
	return "Unknown Class"

func _on_delete_pressed():
	if selected_save_file == "": return
	
	AudioManager.play_sfx("ui_click")
	
	# 1. Delete the file
	RunManager.delete_save_file(selected_save_file)
	
	# 2. Refresh the UI
	selected_save_file = ""
	delete_btn.hide()
	
	# Regenerate grid to remove the old button
	_generate_grid()
	
	# Reset to the first class so we aren't selecting nothing
	_select_class(0)
