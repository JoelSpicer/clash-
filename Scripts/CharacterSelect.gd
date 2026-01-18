extends Control

@onready var p1_option = $HBoxContainer/P1_Column/ClassOption
@onready var p1_info = $HBoxContainer/P1_Column/InfoLabel
# NEW: Reference the texture rects you just created
@onready var p1_portrait = $HBoxContainer/P1_Column/P1_Portrait 

@onready var p2_option = $HBoxContainer/P2_Column/ClassOption
@onready var p2_info = $HBoxContainer/P2_Column/InfoLabel
@onready var p2_custom_check = $HBoxContainer/P2_Column/P2CustomCheck
# NEW: Reference the texture rects you just created
@onready var p2_portrait = $HBoxContainer/P2_Column/P2_Portrait

# New Buttons
@onready var btn_quick = $HBoxContainer/Center_Column/QuickFightButton
@onready var btn_custom = $HBoxContainer/Center_Column/CustomDeckButton
@onready var btn_back = $HBoxContainer/Center_Column/BackButton
@onready var difficulty_option = $HBoxContainer/Center_Column/DifficultyOption
@onready var p2_mode_button = $HBoxContainer/P2_Column/P2ModeButton

var compendium_scene = preload("res://Scenes/compendium.tscn")
var classes = ["Heavy", "Patient", "Quick", "Technical"]
var base_classes = ["Heavy", "Patient", "Quick", "Technical"]
var presets: Array[PresetCharacter] = []

func _ready():
	_load_presets()
	_setup_options(p1_option)
	_setup_options(p2_option)
	
	_setup_difficulty()
	
	# Default selections
	p1_option.selected = 6
	p2_option.selected = 5
	_update_info()
	
	p1_option.item_selected.connect(func(_idx): _update_info())
	p2_option.item_selected.connect(func(_idx): _update_info())
	
	btn_quick.pressed.connect(_on_quick_fight_pressed)
	btn_custom.pressed.connect(_on_custom_deck_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))
	
	if GameManager.p2_is_custom == null:
		GameManager.p2_is_custom = false
	
	_update_p2_mode_visuals()
	p2_mode_button.pressed.connect(_on_p2_mode_pressed)
	
	var btn_help = find_child("HelpButton") 
	if btn_help:
		btn_help.pressed.connect(_on_help_pressed)
	
	# NEW: Ensure P2 Portrait is flipped to look at P1 (Symmetry!)
	if p2_portrait:
		p2_portrait.flip_h = true

func _load_presets():
	presets.clear()
	var path = "res://Data/Presets/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				file_name = dir.get_next()
				continue
				
			var load_path = path + file_name
			if file_name.ends_with(".remap"):
				load_path = load_path.trim_suffix(".remap")
				
			if load_path.ends_with(".tres") or load_path.ends_with(".res"):
				var res = load(load_path)
				if res is PresetCharacter:
					presets.append(res)
			
			file_name = dir.get_next()
		dir.list_dir_end()

func _setup_options(opt: OptionButton):
	opt.clear()
	for c in classes:
		opt.add_item(c)
	
	if presets.size() > 0:
		opt.add_separator("Presets")
		
	for p in presets:
		opt.add_item(p.character_name + " (" + ClassFactory.class_enum_to_string(p.class_type) + ")")

func _get_character_data_from_selection(index: int, player_name: String) -> CharacterData:
	if index < base_classes.size():
		var type = index as CharacterData.ClassType
		return ClassFactory.create_character(type, player_name)
	
	var preset_idx = index - base_classes.size() - 1 
	if preset_idx >= 0 and preset_idx < presets.size():
		var p = presets[preset_idx]
		var char_data = ClassFactory.create_from_preset(p)
		char_data.character_name = p.character_name
		return char_data
		
	return ClassFactory.create_character(0 as CharacterData.ClassType, "ErrorBot")

func _update_info():
	# Pass the portrait nodes to the display function
	_display_stats(p1_option.selected, p1_info, p1_portrait)
	_display_stats(p2_option.selected, p2_info, p2_portrait)

# UPDATED FUNCTION: Now accepts 'portrait_rect'
func _display_stats(idx: int, label: RichTextLabel, portrait_rect: TextureRect):
	var temp = _get_character_data_from_selection(idx, "Preview")
	
	# 1. Update Text
	var txt = "[b]" + temp.character_name + "[/b] (" + ClassFactory.class_enum_to_string(temp.class_type) + ")\n"
	txt += "[b]HP:[/b] " + str(temp.max_hp) + "\n"
	txt += "[b]SP:[/b] " + str(temp.max_sp) + "\n"
	txt += "[b]Speed:[/b] " + str(temp.speed) + "\n\n"
	
	if idx >= base_classes.size():
		txt += "[u]Custom Skills:[/u]\n"
		for card in temp.deck:
			if not card.display_name.begins_with("Basic"):
				txt += "- " + card.display_name + "\n"
	
	txt += "\n[color=yellow]" + temp.passive_desc + "[/color]"
	label.text = txt
	
	# 2. Update Portrait
	if portrait_rect:
		if temp.portrait:
			portrait_rect.texture = temp.portrait
			portrait_rect.modulate = Color.WHITE
		else:
			portrait_rect.texture = null # Clear if missing

func _on_quick_fight_pressed():
	var p1 = _get_character_data_from_selection(p1_option.selected, "Player 1")
	var p2 = _get_character_data_from_selection(p2_option.selected, "Player 2")
	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func _on_custom_deck_pressed():
	# 1. P1 SETUP
	var p1_sel = p1_option.selected
	if p1_sel < base_classes.size():
		GameManager.temp_p1_class_selection = p1_sel
		GameManager.temp_p1_name = "Player 1"
		GameManager.temp_p1_preset = null
	else:
		var preset_idx = p1_sel - base_classes.size() - 1
		if preset_idx >= 0:
			var p = presets[preset_idx]
			GameManager.temp_p1_class_selection = p.class_type
			GameManager.temp_p1_name = p.character_name
			GameManager.temp_p1_preset = p

	# 2. P2 SETUP
	var p2_sel = p2_option.selected
	if p2_sel < base_classes.size():
		GameManager.temp_p2_class_selection = p2_sel
		GameManager.temp_p2_name = "Player 2"
		GameManager.temp_p2_preset = null
	else:
		var preset_idx = p2_sel - base_classes.size() - 1
		if preset_idx >= 0:
			var p = presets[preset_idx]
			GameManager.temp_p2_class_selection = p.class_type
			GameManager.temp_p2_name = p.character_name
			GameManager.temp_p2_preset = p

	GameManager.editing_player_index = 1 
	
	if GameManager.p2_is_custom:
		GameManager.next_match_p2_data = null 
	else:
		var p2 = _get_character_data_from_selection(p2_sel, "Player 2")
		GameManager.next_match_p2_data = p2
	
	get_tree().change_scene_to_file("res://Scenes/ActionTree.tscn")

func _setup_difficulty():
	difficulty_option.clear()
	difficulty_option.add_item("Very Easy")
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium")
	difficulty_option.add_item("Hard")
	difficulty_option.selected = 1
	GameManager.ai_difficulty = GameManager.Difficulty.MEDIUM
	difficulty_option.item_selected.connect(_on_difficulty_changed)

func _on_difficulty_changed(index: int):
	GameManager.ai_difficulty = index as GameManager.Difficulty

func _on_start_arcade_pressed():
	var selected_idx = p1_option.selected
	if selected_idx < base_classes.size():
		var class_enum = selected_idx as CharacterData.ClassType
		RunManager.start_run(class_enum)
	else:
		var preset_idx = selected_idx - base_classes.size() - 1
		if preset_idx >= 0 and preset_idx < presets.size():
			var preset = presets[preset_idx]
			RunManager.start_run_from_preset(preset)

func _on_help_pressed():
	var compendium = compendium_scene.instantiate()
	compendium.is_overlay = true
	compendium.initial_tab_index = 4 
	add_child(compendium)

func _on_p2_mode_pressed():
	GameManager.p2_is_custom = !GameManager.p2_is_custom
	_update_p2_mode_visuals()

func _update_p2_mode_visuals():
	if GameManager.p2_is_custom:
		p2_mode_button.text = "OPPONENT: PLAYER 2"
		p2_mode_button.modulate = Color(0.2, 1.0, 0.2) 
	else:
		p2_mode_button.text = "OPPONENT: CPU BOT"
		p2_mode_button.modulate = Color(0.8, 0.8, 0.8) 
		
	var p2_controls = get_node_or_null("P2Container") # Might be different in your scene
	if p2_controls:
		p2_controls.modulate.a = 1.0 if GameManager.p2_is_custom else 0.7
