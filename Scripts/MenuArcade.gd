extends Control

# --- UI REFERENCES ---
@onready var class_list_root = $MarginContainer/VBoxContainer/HBoxContainer/ClassScroll/ClassList # Changed to VBoxContainer!
@onready var info_label = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/InfoLabel
@onready var portrait_rect = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/P1_Portrait
@onready var tutorial_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/TutorialButton
# Settings
@onready var difficulty_option = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DifficultyOption
@onready var maintain_hp_toggle = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/MaintainHPToggle
@onready var start_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/StartButton
@onready var delete_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DeleteButton
@onready var name_input = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/NameInput

# --- DATA ---
@export var base_classes: Array[ClassDefinition]

# --- STATE ---
var selected_index: int = 0
var buttons: Array[Button] = []
var selected_save_file: String = "" 
var preview_tween: Tween # NEW: Keeps track of our animation

func _ready():
	_setup_difficulty()
	_generate_lists() 
	
	start_btn.pressed.connect(_on_start_pressed)
	
	if tutorial_btn:
		tutorial_btn.pressed.connect(_on_tutorial_pressed)
	
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_pressed)
		delete_btn.hide() 
	
	_select_class(0)

# --- NEW: DYNAMIC SECTION GENERATION ---
func _generate_lists():
	# Clear the root
	for child in class_list_root.get_children(): child.queue_free()
	buttons.clear()
	
	# 1. CREATE NEW GAME GRID
	var class_grid = GridContainer.new()
	class_grid.columns = 2
	class_grid.add_theme_constant_override("h_separation", 10)
	class_grid.add_theme_constant_override("v_separation", 10)
	class_list_root.add_child(class_grid)
	
	for i in range(base_classes.size()):
		var def = base_classes[i]
		_create_button(class_grid, i, def.class_named, def.portrait, false)

	# 2. CREATE SAVE FILES SECTION
	var saves = RunManager.get_save_files()
	if saves.size() > 0:
		# Add a stylised Header
		var header = Label.new()
		header.text = "- SAVED RUNS -"
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_color_override("font_color", Color.YELLOW)
		class_list_root.add_child(header)
		
		# Add a VBox for Save Files (Wide horizontal bars)
		var save_vbox = VBoxContainer.new()
		save_vbox.add_theme_constant_override("separation", 10)
		class_list_root.add_child(save_vbox)
		
		for i in range(saves.size()):
			var filename = saves[i]
			var save_index = 100 + i 
			_create_button(save_vbox, save_index, filename.replace(".tres", ""), null, true)

func _create_button(parent_container: Control, index: int, text: String, icon: Texture2D, is_save: bool):
	var btn = Button.new()
	btn.text = text
	
	if is_save:
		btn.custom_minimum_size = Vector2(290, 60) # Wide Bar for saves
		btn.modulate = Color(0.6, 0.8, 1.0) # Blue tint
	else:
		btn.icon = icon
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(140, 160) # Tall Rectangle for characters
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_text = true
	
	# --- NEW: HOVER CONNECTION ---
	btn.mouse_entered.connect(func(): _on_class_hover(index, is_save, text))
	btn.mouse_exited.connect(_on_class_unhover)
	btn.pressed.connect(func(): _on_item_selected(index, text, is_save))
	
	parent_container.add_child(btn)
	buttons.append(btn)

# --- INTERACTION ---
func _on_class_hover(index: int, is_save: bool, text: String = ""):
	AudioManager.play_sfx("ui_hover", 0.1)
	
	if is_save:
		# If hovering a save, preview the save file!
		_show_save_preview(text + ".tres")
	else:
		# If hovering a base class, preview the base class!
		_update_preview_panel(index)

func _on_class_unhover():
	# Revert the preview panel to whatever is actually locked in
	if selected_save_file != "":
		_show_save_preview(selected_save_file)
	else:
		_update_preview_panel(selected_index)

# --- THE "SLAM" AND "TYPEWRITER" ANIMATION ---
func _update_preview_panel(index: int):
	if index >= base_classes.size(): return
	var data = base_classes[index]
	
	# 1. Kill any currently running animation (so it doesn't glitch if moving mouse fast)
	if preview_tween and preview_tween.is_valid():
		preview_tween.kill()
		
	preview_tween = create_tween().set_parallel(true)
	
	# 2. ANIMATE PORTRAIT (The Slam)
	if portrait_rect:
		portrait_rect.texture = data.portrait
		# Start high, invisible, and slightly scaled up
		portrait_rect.position.y = -50 
		portrait_rect.modulate.a = 0.0
		portrait_rect.scale = Vector2(1.1, 1.1)
		
		# Tween it back to normal with a "Bounce/Back" ease
		preview_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		preview_tween.tween_property(portrait_rect, "position:y", 0.0, 0.3)
		preview_tween.tween_property(portrait_rect, "modulate:a", 1.0, 0.2)
		preview_tween.tween_property(portrait_rect, "scale", Vector2.ONE, 0.3)
	
	# 3. TYPEWRITER EFFECT FOR INFO
	info_label.text = data.arcade_description.c_unescape() if data.arcade_description != "" else "Info missing."
	info_label.visible_ratio = 0.0 # Hide text completely
	
	# Calculate typing time (longer text takes slightly longer, max 0.5s)
	var type_time = min(info_label.text.length() * 0.005, 0.5) 
	preview_tween.tween_property(info_label, "visible_ratio", 1.0, type_time).set_trans(Tween.TRANS_LINEAR)

# --- START RUN ---
func _on_start_pressed():
	AudioManager.play_sfx("ui_confirm")
	RunManager.maintain_hp_enabled = maintain_hp_toggle.button_pressed
	
	if selected_save_file != "":
		RunManager.load_run(selected_save_file)
	else:
		if selected_index < base_classes.size():
			var run_name = name_input.text
			if run_name.strip_edges() == "": run_name = "Unnamed"
			RunManager.start_new_run(base_classes[selected_index], run_name)

# --- SETTINGS HELPERS ---

func _on_difficulty_changed(index: int):
	GameManager.ai_difficulty = index as GameManager.Difficulty

# --- UPDATED INTERACTION LOGIC ---

func _select_class(index: int):
	AudioManager.play_sfx("ui_click")
	selected_index = index
	selected_save_file = "" 
	
	name_input.editable = true
	start_btn.text = "START RUN"
	
	# 1. Re-enable the UI
	difficulty_option.disabled = false 
	maintain_hp_toggle.disabled = false 

	# 2. INSERT THE FIX HERE:
	# This ensures GameManager knows the difficulty immediately upon selection
	GameManager.ai_difficulty = difficulty_option.selected as GameManager.Difficulty
	
	# 3. Handle button highlights
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == index:
			btn.modulate = Color(1.2, 1.2, 1.2)
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			# Reset to white (or blue-ish if it's a save file button)
			btn.modulate = Color(1, 1, 1) if not (btn.custom_minimum_size.x > 200) else Color(0.6, 0.8, 1.0)
			btn.remove_theme_color_override("font_color")
			
	_update_preview_panel(index)

func _get_difficulty_name(value: int) -> String:
	var keys = GameManager.Difficulty.keys()
	if value >= 0 and value < keys.size(): return keys[value].capitalize()
	return "Unknown"

func _on_delete_pressed():
	if selected_save_file == "": return
	AudioManager.play_sfx("ui_click")
	RunManager.delete_save_file(selected_save_file)
	selected_save_file = ""
	delete_btn.hide()
	_generate_lists()
	_select_class(0)

func _show_save_preview(filename: String):
	var data: RunSaveData = RunManager.peek_save_file(filename)
	if data == null:
		info_label.text = "[color=red]Error reading save.[/color]"
		return
		
	# 1. Kill any currently running animation
	if preview_tween and preview_tween.is_valid():
		preview_tween.kill()
		
	preview_tween = create_tween().set_parallel(true)
	var p_data = data.player_data
	
	# 2. ANIMATE PORTRAIT (The Slam)
	if portrait_rect and p_data.portrait:
		portrait_rect.texture = p_data.portrait
		portrait_rect.position.y = -50 
		portrait_rect.modulate.a = 0.0
		portrait_rect.scale = Vector2(1.1, 1.1)
		
		preview_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		preview_tween.tween_property(portrait_rect, "position:y", 0.0, 0.3)
		preview_tween.tween_property(portrait_rect, "modulate:a", 1.0, 0.2)
		preview_tween.tween_property(portrait_rect, "scale", Vector2.ONE, 0.3)
	elif portrait_rect:
		portrait_rect.texture = null
	
	# 3. BUILD TEXT
	var txt = "[center][b][font_size=24]" + data.run_name + "[/font_size][/b][/center]\n"
	txt += "[center][color=gray]Level " + str(data.current_level) + " - " + _get_difficulty_name(data.difficulty) + "[/color][/center]\n\n"
	txt += "[b]Class:[/b] " + ClassFactory.class_enum_to_string(p_data.class_type) + "\n"
	txt += "[b]HP:[/b] " + str(p_data.current_hp) + "/" + str(p_data.max_hp) + "   "
	txt += "[b]SP:[/b] " + str(p_data.current_sp) + "/" + str(p_data.max_sp) + "\n"
	
	# 4. TYPEWRITER EFFECT
	info_label.text = txt
	info_label.visible_ratio = 0.0 
	
	var type_time = min(info_label.text.length() * 0.005, 0.5) 
	preview_tween.tween_property(info_label, "visible_ratio", 1.0, type_time).set_trans(Tween.TRANS_LINEAR)

func _setup_difficulty():
	difficulty_option.clear()
	difficulty_option.add_item("Very Easy")
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium")
	difficulty_option.add_item("Hard")
	
	difficulty_option.selected = 2 # Medium
	# FIX: Explicitly tell GameManager the starting difficulty!
	GameManager.ai_difficulty = 2 as GameManager.Difficulty
	
	if not difficulty_option.item_selected.is_connected(_on_difficulty_changed):
		difficulty_option.item_selected.connect(_on_difficulty_changed)

func _on_item_selected(index: int, text: String, is_save: bool):
	AudioManager.play_sfx("ui_click")
	
	# 1. Visual Highlight
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == index:
			btn.modulate = Color(1.2, 1.2, 1.2)
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.modulate = Color(1, 1, 1) if not (btn.custom_minimum_size.x > 200) else Color(0.6, 0.8, 1.0)
			btn.remove_theme_color_override("font_color")

	if is_save:
		selected_save_file = text + ".tres"
		start_btn.text = "LOAD RUN"
		name_input.editable = false
		name_input.text = text
		
		var data: RunSaveData = RunManager.peek_save_file(selected_save_file)
		if data == null: return

		# Lock the settings to match the save file
		difficulty_option.selected = data.difficulty
		difficulty_option.disabled = true 
		maintain_hp_toggle.button_pressed = data.maintain_hp
		maintain_hp_toggle.disabled = true
		
		# Call our new helper function!
		_show_save_preview(selected_save_file)
		delete_btn.show()

	else:
		selected_save_file = "" 
		selected_index = index
		start_btn.text = "START RUN"
		name_input.editable = true
		
		# FIX: If we clicked a save file previously, reset dropdown to Medium
		if difficulty_option.disabled == true:
			difficulty_option.selected = 2
			
		difficulty_option.disabled = false 
		maintain_hp_toggle.disabled = false
		
		# FIX: Sync GameManager to whatever the dropdown currently says
		GameManager.ai_difficulty = difficulty_option.selected as GameManager.Difficulty
		
		_update_preview_panel(index)
		delete_btn.hide()

func _on_tutorial_pressed():
	AudioManager.play_sfx("ui_confirm")
	TutorialManager.setup_and_start_tutorial("basic")
