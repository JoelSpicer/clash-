extends Control

# --- UI REFERENCES ---
@onready var class_list_root: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/ClassScroll/ClassList
@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/InfoLabel
@onready var portrait_rect: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/P1_Portrait
@onready var tutorial_btn: Button = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/TutorialButton
@onready var sponsor_option: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/SponsorOption
@onready var sponsor_info_panel: PanelContainer = %SponsorInfoPanel
@onready var sponsor_icon: TextureRect = %SponsorInfoPanel/HBox/SponsorIcon
@onready var sponsor_name: Label = %SponsorInfoPanel/HBox/VBox/SponsorName
@onready var sponsor_desc: Label = %SponsorInfoPanel/HBox/VBox/SponsorDesc
var available_sponsors: Array[SponsorData] = []
# Settings
@onready var difficulty_option: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DifficultyOption
@onready var start_btn: Button = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/StartButton
@onready var delete_btn: Button = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DeleteButton
@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/NameInput

# --- DATA ---
@export var base_classes: Array[ClassDefinition]

# --- STATE ---
var selected_index: int = 0
var buttons: Array[Button] = []
var selected_save_file: String = "" 
var preview_tween: Tween

func _ready() -> void:
	_setup_difficulty()
	_load_sponsors()
	_generate_lists() 
	
	start_btn.pressed.connect(_on_start_pressed)
	
	if tutorial_btn:
		tutorial_btn.pressed.connect(_on_tutorial_pressed)
	
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_pressed)
		delete_btn.hide() 
	
	_select_class(0)

# --- NEW: DYNAMIC SECTION GENERATION ---
func _generate_lists() -> void:
	# Clear the root
	for child in class_list_root.get_children(): child.queue_free()
	buttons.clear()
	
	# 1. CREATE NEW GAME GRID
	var class_grid: GridContainer = GridContainer.new()
	class_grid.columns = 2
	class_grid.add_theme_constant_override("h_separation", 10)
	class_grid.add_theme_constant_override("v_separation", 10)
	class_list_root.add_child(class_grid)
	
	for i in range(base_classes.size()):
		var def: ClassDefinition = base_classes[i]
		var is_unlocked: bool = (def.class_named == "Heavy") or (def.class_named in RunManager.meta_data.unlocked_classes)
		
		if is_unlocked:
			_create_button(class_grid, i, def.class_named, def.portrait, false)

	# 2. CREATE SAVE FILES SECTION
	var saves: Array[String] = RunManager.get_save_files()
	if saves.size() > 0:
		var header: Label = Label.new()
		header.text = "- SAVED RUNS -"
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_color_override("font_color", Color.YELLOW)
		class_list_root.add_child(header)
		
		var save_vbox: VBoxContainer = VBoxContainer.new()
		save_vbox.add_theme_constant_override("separation", 10)
		class_list_root.add_child(save_vbox)
		
		for i in range(saves.size()):
			var filename: String = saves[i]
			var save_index: int = 100 + i 
			_create_button(save_vbox, save_index, filename.replace(".tres", ""), null, true)

func _create_button(parent_container: Control, index: int, text: String, icon: Texture2D, is_save: bool) -> void:
	var btn: Button = Button.new()
	btn.text = text
	
	btn.set_meta("id", index)
	btn.set_meta("is_save", is_save)
	
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
	
	btn.mouse_entered.connect(func() -> void: _on_class_hover(index, is_save, text))
	btn.mouse_exited.connect(_on_class_unhover)
	btn.pressed.connect(func() -> void: _on_item_selected(index, text, is_save))
	
	parent_container.add_child(btn)
	buttons.append(btn)

# --- INTERACTION ---
func _on_class_hover(index: int, is_save: bool, text: String = "") -> void:
	AudioManager.play_sfx("ui_hover", 0.1)
	
	if is_save:
		_show_save_preview(text + ".tres")
	else:
		_update_preview_panel(index)

func _on_class_unhover() -> void:
	if selected_save_file != "":
		_show_save_preview(selected_save_file)
	else:
		_update_preview_panel(selected_index)

# --- THE "SLAM" AND "TYPEWRITER" ANIMATION ---
func _update_preview_panel(index: int) -> void:
	if index >= base_classes.size(): return
	var data: ClassDefinition = base_classes[index]
	
	if preview_tween and preview_tween.is_valid():
		preview_tween.kill()
		
	preview_tween = create_tween().set_parallel(true)
	
	# 2. ANIMATE PORTRAIT (The Slam)
	if portrait_rect:
		portrait_rect.texture = data.portrait
		portrait_rect.position.y = -50 
		portrait_rect.modulate.a = 0.0
		portrait_rect.scale = Vector2(1.1, 1.1)
		
		preview_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		preview_tween.tween_property(portrait_rect, "position:y", 0.0, 0.3)
		preview_tween.tween_property(portrait_rect, "modulate:a", 1.0, 0.2)
		preview_tween.tween_property(portrait_rect, "scale", Vector2.ONE, 0.3)
	
	# 3. TYPEWRITER EFFECT FOR INFO
	info_label.text = data.arcade_description.c_unescape() if data.arcade_description != "" else "Info missing."
	info_label.visible_ratio = 0.0
	
	var type_time: float = minf(info_label.text.length() * 0.005, 0.5) 
	preview_tween.tween_property(info_label, "visible_ratio", 1.0, type_time).set_trans(Tween.TRANS_LINEAR)

# --- START RUN ---
func _on_start_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	
	if selected_save_file != "":
		RunManager.load_run(selected_save_file)
	else:
		if selected_index < base_classes.size():
			var run_name: String = name_input.text
			if run_name.strip_edges() == "": run_name = "Unnamed"
			
			var chosen_sponsor: SponsorData = available_sponsors[sponsor_option.selected]
			RunManager.start_new_run(base_classes[selected_index], run_name, chosen_sponsor)

# --- SETTINGS HELPERS ---

func _on_difficulty_changed(index: int) -> void:
	GameManager.ai_difficulty = index as GameManager.Difficulty

# --- UPDATED INTERACTION LOGIC ---

func _select_class(index: int) -> void:
	AudioManager.play_sfx("ui_click")
	selected_index = index
	selected_save_file = "" 
	
	name_input.editable = true
	start_btn.text = "START RUN"
	
	difficulty_option.disabled = false 
	GameManager.ai_difficulty = difficulty_option.selected as GameManager.Difficulty
	
	for btn: Button in buttons:
		if int(btn.get_meta("id")) == index and bool(btn.get_meta("is_save")) == false:
			btn.modulate = Color(1.2, 1.2, 1.2)
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.modulate = Color(1, 1, 1) if not bool(btn.get_meta("is_save")) else Color(0.6, 0.8, 1.0)
			btn.remove_theme_color_override("font_color")
			
	_update_preview_panel(index)

func _get_difficulty_name(value: int) -> String:
	var keys: PackedStringArray = GameManager.Difficulty.keys()
	if value >= 0 and value < keys.size(): return keys[value].capitalize()
	return "Unknown"

func _on_delete_pressed() -> void:
	if selected_save_file == "": return
	AudioManager.play_sfx("ui_click")
	RunManager.delete_save_file(selected_save_file)
	selected_save_file = ""
	delete_btn.hide()
	_generate_lists()
	_select_class(0)

func _show_save_preview(filename: String) -> void:
	var data: RunSaveData = RunManager.peek_save_file(filename)
	if data == null:
		info_label.text = "[color=red]Error reading save.[/color]"
		return
		
	if preview_tween and preview_tween.is_valid():
		preview_tween.kill()
		
	preview_tween = create_tween().set_parallel(true)
	var p_data: CharacterData = data.player_data
	
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
	var txt: String = "[center][b][font_size=24]" + data.run_name + "[/font_size][/b][/center]\n"
	txt += "[center][color=gray]Level " + str(data.current_level) + " - " + _get_difficulty_name(data.difficulty) + "[/color][/center]\n\n"
	txt += "[b]Class:[/b] " + ClassFactory.class_enum_to_string(p_data.class_type) + "\n"
	txt += "[b]HP:[/b] " + str(p_data.current_hp) + "/" + str(p_data.max_hp) + "   "
	txt += "[b]SP:[/b] " + str(p_data.current_sp) + "/" + str(p_data.max_sp) + "\n"
	
	# 4. TYPEWRITER EFFECT
	info_label.text = txt
	info_label.visible_ratio = 0.0 
	
	var type_time: float = minf(info_label.text.length() * 0.005, 0.5) 
	preview_tween.tween_property(info_label, "visible_ratio", 1.0, type_time).set_trans(Tween.TRANS_LINEAR)

func _setup_difficulty() -> void:
	difficulty_option.clear()
	difficulty_option.add_item("Very Easy")
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium")
	difficulty_option.add_item("Hard")
	
	difficulty_option.selected = 2 # Medium
	GameManager.ai_difficulty = 2 as GameManager.Difficulty
	
	if not difficulty_option.item_selected.is_connected(_on_difficulty_changed):
		difficulty_option.item_selected.connect(_on_difficulty_changed)

func _on_item_selected(index: int, text: String, is_save: bool) -> void:
	AudioManager.play_sfx("ui_click")
	
	for btn: Button in buttons:
		if int(btn.get_meta("id")) == index and bool(btn.get_meta("is_save")) == is_save:
			btn.modulate = Color(1.2, 1.2, 1.2)
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.modulate = Color(1, 1, 1) if not bool(btn.get_meta("is_save")) else Color(0.6, 0.8, 1.0)
			btn.remove_theme_color_override("font_color")

	if is_save:
		selected_save_file = text + ".tres"
		start_btn.text = "LOAD RUN"
		name_input.editable = false
		name_input.text = text
		
		sponsor_option.disabled = true
		sponsor_info_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		
		var data: RunSaveData = RunManager.peek_save_file(selected_save_file)
		if data == null: return
		data.player_data.character_name = data.run_name

		difficulty_option.selected = data.difficulty
		difficulty_option.disabled = true 
		
		_show_save_preview(selected_save_file)
		delete_btn.show()
	else:
		selected_save_file = "" 
		selected_index = index
		start_btn.text = "START RUN"
		name_input.editable = true
		
		sponsor_option.disabled = false
		_on_sponsor_selected(sponsor_option.selected)
		
		if difficulty_option.disabled == true:
			difficulty_option.selected = 2
			
		difficulty_option.disabled = false 
		GameManager.ai_difficulty = difficulty_option.selected as GameManager.Difficulty
		
		_update_preview_panel(index)
		delete_btn.hide()

func _on_tutorial_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	TutorialManager.setup_and_start_tutorial("basic")

func _load_sponsors() -> void:
	sponsor_option.clear()
	available_sponsors.clear()
	
	sponsor_option.add_item("No Sponsor")
	available_sponsors.append(null)
	
	var dir_path: String = "res://Data/Sponsors/"
	var seen: Dictionary = {}
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name: String = file_name.replace(".remap", "")
				if (clean_name.ends_with(".tres") or clean_name.ends_with(".res")) and not seen.has(clean_name):
					seen[clean_name] = true
					var sponsor: SponsorData = load(dir_path + clean_name) as SponsorData
					if sponsor:
						if sponsor.item_name in RunManager.meta_data.unlocked_sponsors or sponsor.item_name == "CRASH Supplements" or sponsor.item_name == "SLAM Supplements":
							available_sponsors.append(sponsor)
							sponsor_option.add_item(sponsor.item_name)
			file_name = dir.get_next()
		dir.list_dir_end()
			
	if not sponsor_option.item_selected.is_connected(_on_sponsor_selected):
		sponsor_option.item_selected.connect(_on_sponsor_selected)
		
	_on_sponsor_selected(sponsor_option.selected)

# --- SPONSOR VISUALS ---
func _on_sponsor_selected(index: int) -> void:
	var sponsor: SponsorData = available_sponsors[index]
	
	if sponsor == null:
		sponsor_info_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		sponsor_info_panel.show()
		sponsor_name.text = "Sponsor"
		sponsor_desc.text = "Select a Sponsor to enhance your run"
	else:
		sponsor_info_panel.modulate = Color.WHITE
		sponsor_info_panel.show()
		sponsor_name.text = sponsor.item_name
		sponsor_desc.text = sponsor.description
		
		if sponsor.icon:
			sponsor_icon.texture = sponsor.icon
		else:
			sponsor_icon.texture = preload("res://Art/Icons/icon_Opportunity.png")
