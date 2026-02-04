extends Control

# --- UI REFERENCES ---
# Updated path to point to your new list container
@onready var class_list_container = $MarginContainer/VBoxContainer/HBoxContainer/ClassScroll/ClassList

# Preview Panel References
@onready var info_label = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/InfoLabel
@onready var portrait_rect = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/P1_Portrait

# Settings References
@onready var difficulty_option = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DifficultyOption
@onready var maintain_hp_toggle = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/MaintainHPToggle
@onready var start_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/StartButton

# --- DATA ---
@export var base_classes: Array[ClassDefinition]
var presets: Array[PresetCharacter] = []

# --- STATE ---
var selected_index: int = 0
var buttons: Array[Button] = []

func _ready():
	_load_presets()
	_setup_difficulty()
	
	# 1. Generate the list of buttons
	_generate_class_buttons()
	
	# 2. Connect the Start Button
	start_btn.pressed.connect(_on_start_pressed)
	
	# 3. Select the first class by default so the screen isn't empty
	_select_class(0)

# --- GENERATION LOGIC ---
func _generate_class_buttons():
	# Clear any dummy buttons from the editor
	for child in class_list_container.get_children():
		child.queue_free()
	buttons.clear()
	
	# A. Add Base Classes (Defined in Inspector)
	for i in range(base_classes.size()):
		var def = base_classes[i]
		_create_button(i, def.class_named, false)

	# B. Add Presets (Loaded from folder)
	if presets.size() > 0:
		# Add a separator line for visual clarity
		var sep = HSeparator.new()
		class_list_container.add_child(sep)
		
		for i in range(presets.size()):
			var p = presets[i]
			# The index continues after the base classes
			var total_idx = base_classes.size() + i
			_create_button(total_idx, p.character_name, true)

func _create_button(index: int, text: String, is_preset: bool):
	var btn = Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 40 # Nice tall button
	
	# Distinct styling for Presets vs Base Classes
	if is_preset:
		btn.modulate = Color(0.7, 0.9, 1.0) # Light Cyan tint
	
	# CONNECT SIGNALS
	# We bind the 'index' so the button knows which class it represents
	btn.mouse_entered.connect(func(): _on_class_hover(index))
	btn.pressed.connect(func(): _select_class(index))
	
	class_list_container.add_child(btn)
	buttons.append(btn)

# --- INTERACTION ---

# When mouse hovers, just show the preview (don't select yet)
func _on_class_hover(index: int):
	AudioManager.play_sfx("ui_hover", 0.1)
	_update_preview_panel(index)

# When clicked, lock it in
func _select_class(index: int):
	AudioManager.play_sfx("ui_click")
	selected_index = index
	
	# Update Button Visuals (Highlight the selected one)
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == index:
			# Selected Style
			btn.add_theme_color_override("font_color", Color.GREEN)
			if not btn.text.begins_with("> "):
				btn.text = "> " + btn.text
		else:
			# Deselected Style
			btn.remove_theme_color_override("font_color")
			btn.text = btn.text.trim_prefix("> ")
			
	# Ensure preview is accurate
	_update_preview_panel(index)

func _update_preview_panel(index: int):
	var data = _get_data_at_index(index)
	
	# 1. HEADER (Name)
	var txt = "[center][b][font_size=24]" + data.name + "[/font_size][/b][/center]\n"
	
	# 2. NEW: PLAYSTYLE SUMMARY (Italicized Grey)
	if data.summary != "":
		txt += "[center][i][color=light_gray]" + data.summary + "[/color][/i][/center]\n"
	
	txt += "\n" # Spacer
	
	# 3. STATS
	txt += "[b]HP:[/b] " + str(data.hp) + "   [b]SP:[/b] " + str(data.sp) + "\n"
	txt += "[b]Speed:[/b] " + str(data.speed) + "\n"
	txt += "----------------\n"
	
	# 4. PASSIVE
	txt += "[color=yellow]" + data.passive + "[/color]"
	
	info_label.text = txt
	
	# Update Portrait
	if portrait_rect.texture != data.portrait:
		portrait_rect.texture = data.portrait
		portrait_rect.modulate = Color(1.5, 1.5, 1.5)
		var tween = create_tween()
		tween.tween_property(portrait_rect, "modulate", Color.WHITE, 0.3)

func _get_data_at_index(index: int) -> Dictionary:
	if index < base_classes.size():
		var c = base_classes[index]
		return {
			"name": c.class_named,
			"hp": c.base_hp,
			"sp": c.base_sp,
			"speed": c.base_speed,
			"passive": c.passive_description,
			"portrait": c.portrait,
			"summary": c.playstyle_summary # <--- NEW FIELD
		}
	else:
		var p_idx = index - base_classes.size()
		if p_idx < presets.size():
			var p = presets[p_idx]
			return {
				"name": p.character_name,
				"hp": "10", 
				"sp": "3",
				"speed": "?",
				"passive": "Custom Preset Deck",
				"portrait": null,
				"summary": p.description # <--- NEW FIELD
			}
	return {"name": "Error", "hp": 0, "sp": 0, "speed": 0, "passive": "", "portrait": null, "summary": ""}

# --- START GAME LOGIC ---
func _on_start_pressed():
	AudioManager.play_sfx("ui_confirm")
	
	# 1. Save Settings
	RunManager.maintain_hp_enabled = maintain_hp_toggle.button_pressed
	
	# 2. Start Run based on selection index
	if selected_index < base_classes.size():
		# Case A: Base Class
		RunManager.start_new_run(base_classes[selected_index])
	else:
		# Case B: Preset
		var preset_idx = selected_index - base_classes.size()
		var preset_resource = presets[preset_idx]
		
		# --- THE FIX ---
		# We must convert the "Preset Resource" into "Character Data" first.
		var character_data = ClassFactory.create_from_preset(preset_resource)
		
		# Now pass the generated data object
		RunManager.start_run_from_preset(character_data)

# --- SETUP HELPERS ---
func _load_presets():
	presets.clear()
	var path = "res://Data/Presets/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				var res = load(path + file_name)
				if res is PresetCharacter: presets.append(res)
			file_name = dir.get_next()

func _setup_difficulty():
	difficulty_option.clear()
	difficulty_option.add_item("Very Easy")
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium")
	difficulty_option.add_item("Hard")
	difficulty_option.selected = 2 # Medium Default
	
	# Use a lambda to connect the signal cleanly
	if not difficulty_option.item_selected.is_connected(_on_difficulty_changed):
		difficulty_option.item_selected.connect(_on_difficulty_changed)

func _on_difficulty_changed(index: int):
	GameManager.ai_difficulty = index as GameManager.Difficulty
