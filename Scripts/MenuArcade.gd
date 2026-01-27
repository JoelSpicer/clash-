extends Control

# --- NODES ---
@onready var p1_option = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/ClassOption
@onready var p1_info = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/InfoLabel
@onready var p1_portrait = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/P1_Portrait
@onready var difficulty_option = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DifficultyOption
@onready var maintain_hp_toggle = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/MaintainHPToggle
@onready var start_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/StartButton

# --- DATA ---
var classes = ["Heavy", "Patient", "Quick", "Technical"]
var base_classes = ["Heavy", "Patient", "Quick", "Technical"]
var presets: Array[PresetCharacter] = []

func _ready():
	_load_presets()
	_setup_options(p1_option)
	_setup_difficulty()
	
	# Connect Signals
	p1_option.item_selected.connect(_on_selection_changed)
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	start_btn.pressed.connect(_on_start_pressed)
	
	# Initial UI State
	p1_option.selected = 0
	_update_info()

func _on_start_pressed():
	# 1. Save Run Modifiers
	RunManager.maintain_hp_enabled = maintain_hp_toggle.button_pressed
	
	# 2. Identify Selection
	var selected_idx = p1_option.selected
	if selected_idx < base_classes.size():
		# Standard Class Start
		var class_enum = selected_idx as CharacterData.ClassType
		RunManager.start_run(class_enum)
	else:
		# Preset Start
		var preset_idx = selected_idx - base_classes.size() - 1
		if preset_idx >= 0 and preset_idx < presets.size():
			var preset = presets[preset_idx]
			RunManager.start_run_from_preset(preset)

func _update_info():
	var idx = p1_option.selected
	# Helper function derived from your old code [cite: 353]
	var temp = _get_character_data_from_selection(idx, "Preview")
	
	var txt = "[b]" + temp.character_name + "[/b]\n"
	txt += "HP: " + str(temp.max_hp) + " | SP: " + str(temp.max_sp) + "\n"
	txt += "[color=yellow]" + temp.passive_desc + "[/color]"
	p1_info.text = txt
	
	if p1_portrait:
		p1_portrait.texture = temp.portrait

# --- REUSED HELPERS (Copied from CharacterSelect.gd) ---

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

func _setup_options(opt: OptionButton):
	opt.clear()
	for c in classes: opt.add_item(c)
	if presets.size() > 0: opt.add_separator("Presets")
	for p in presets: opt.add_item(p.character_name)

func _setup_difficulty():
	difficulty_option.clear()
	difficulty_option.add_item("Very Easy"); difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium"); difficulty_option.add_item("Hard")
	difficulty_option.selected = 2 # Medium Default

func _on_difficulty_changed(index: int):
	GameManager.ai_difficulty = index as GameManager.Difficulty

func _on_selection_changed(_idx):
	_update_info()

func _get_character_data_from_selection(index: int, p_name: String) -> CharacterData:
	if index < base_classes.size():
		return ClassFactory.create_character(index as CharacterData.ClassType, p_name)
	var preset_idx = index - base_classes.size() - 1
	if preset_idx >= 0: return ClassFactory.create_from_preset(presets[preset_idx])
	return null
