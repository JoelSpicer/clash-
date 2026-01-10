extends Control

@onready var p1_option = $HBoxContainer/P1_Column/ClassOption
@onready var p1_info = $HBoxContainer/P1_Column/InfoLabel
@onready var p2_option = $HBoxContainer/P2_Column/ClassOption
@onready var p2_info = $HBoxContainer/P2_Column/InfoLabel
@onready var p2_custom_check = $HBoxContainer/P2_Column/P2CustomCheck

# New Buttons
@onready var btn_quick = $HBoxContainer/Center_Column/QuickFightButton
@onready var btn_custom = $HBoxContainer/Center_Column/CustomDeckButton
@onready var btn_back = $HBoxContainer/Center_Column/BackButton
@onready var difficulty_option = $HBoxContainer/Center_Column/DifficultyOption

var classes = ["Heavy", "Patient", "Quick", "Technical"]

# BASE CLASSES
var base_classes = ["Heavy", "Patient", "Quick", "Technical"]

# LOADED PRESETS
var presets: Array[PresetCharacter] = []

func _ready():
	
	_load_presets() # <--- Load files on startup
	_setup_options(p1_option)
	_setup_options(p2_option)
	
	_setup_difficulty()
	
	# Default selections
	p1_option.selected = 0
	p2_option.selected = 1
	_update_info()
	
	p1_option.item_selected.connect(func(_idx): _update_info())
	p2_option.item_selected.connect(func(_idx): _update_info())
	
	# --- BUTTON CONNECTIONS ---
	btn_quick.pressed.connect(_on_quick_fight_pressed)
	btn_custom.pressed.connect(_on_custom_deck_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))

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
				
			# --- EXPORT FIX STARTS HERE ---
			# In exported games, files often have a '.remap' extension.
			# We must strip it to get the correct load path.
			var load_path = path + file_name
			if file_name.ends_with(".remap"):
				load_path = load_path.trim_suffix(".remap")
				
			# Now check the extension on the CLEANED path
			if load_path.ends_with(".tres") or load_path.ends_with(".res"):
				var res = load(load_path)
				if res is PresetCharacter:
					presets.append(res)
			# ------------------------------
			
			file_name = dir.get_next()
		dir.list_dir_end()

func _setup_options(opt: OptionButton):
	opt.clear()
	for c in classes:
		opt.add_item(c)
	
	# 2. Add Separator
	if presets.size() > 0:
		opt.add_separator("Presets")
		
	# 3. Add Presets
	for p in presets:
		# We use the local helper function '_class_enum_to_string' instead of calling it on 'p'
		opt.add_item(p.character_name + " (" + _class_enum_to_string(p.class_type) + ")")
		# Note: You might need a helper to convert Enum 0->Heavy string if you want it pretty

func _get_character_data_from_selection(index: int, player_name: String) -> CharacterData:
	# Index 0-3 are Base Classes
	if index < base_classes.size():
		# FIX: Cast the integer 'index' to the ClassType enum using 'as'
		var type = index as CharacterData.ClassType
		return ClassFactory.create_character(type, player_name)
	
	# ... (The rest of your preset logic remains the same) ...
	
	var preset_idx = index - base_classes.size() - 1 
	if preset_idx >= 0 and preset_idx < presets.size():
		var p = presets[preset_idx]
		var char_data = ClassFactory.create_from_preset(p)
		char_data.character_name = p.character_name
		return char_data
		
	# FIX: Cast the 0 fallback here too just to be safe
	return ClassFactory.create_character(0 as CharacterData.ClassType, "ErrorBot")

func _update_info():
	_display_stats(p1_option.selected, p1_info)
	_display_stats(p2_option.selected, p2_info)

func _display_stats(idx: int, label: RichTextLabel):
	var temp = _get_character_data_from_selection(idx, "Preview")
	
	var txt = "[b]" + temp.character_name + "[/b] (" + _class_enum_to_string(temp.class_type) + ")\n"
	txt += "[b]HP:[/b] " + str(temp.max_hp) + "\n"
	txt += "[b]SP:[/b] " + str(temp.max_sp) + "\n"
	txt += "[b]Speed:[/b] " + str(temp.speed) + "\n\n"
	
	# List Skills if it's a preset
	if idx >= base_classes.size():
		txt += "[u]Custom Skills:[/u]\n"
		for card in temp.deck:
			# Only show non-basic cards to save space
			if not card.display_name.begins_with("Basic"):
				txt += "- " + card.display_name + "\n"
	
	txt += "\n[color=yellow]" + temp.passive_desc + "[/color]"
	label.text = txt

# --- OPTION 1: QUICK FIGHT (Standard Decks) ---
func _on_quick_fight_pressed():
	# Use the helper function to translate the selection (Index -> Character Data)
	var p1 = _get_character_data_from_selection(p1_option.selected, "Player 1")
	var p2 = _get_character_data_from_selection(p2_option.selected, "Player 2")
	
	# Store in Manager
	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2
	
	# Go straight to Combat
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

# --- OPTION 2: CUSTOM DECK (Skill Tree) ---
func _on_custom_deck_pressed():
	# --- 1. HANDLE PLAYER 1 (The one we edit first) ---
	var p1_sel = p1_option.selected
	var p1_class_id = 0
	
	if p1_sel < base_classes.size():
		# Base Class
		p1_class_id = p1_sel
		GameManager.temp_p1_name = "Player 1"
		GameManager.temp_p1_preset = null # <--- Clear preset
	else:
		# Preset Character
		var preset_idx = p1_sel - base_classes.size() - 1
		if preset_idx >= 0:
			var p = presets[preset_idx]
			p1_class_id = p.class_type
			GameManager.temp_p1_name = p.character_name
			GameManager.temp_p1_preset = p # <--- Save preset

	# --- 2. HANDLE PLAYER 2 (The opponent or next edit) ---
	var p2_sel = p2_option.selected
	var p2_class_id = 0
	
	if p2_sel < base_classes.size():
		# Base Class
		p2_class_id = p2_sel
		GameManager.temp_p2_name = "Player 2"
		GameManager.temp_p2_preset = null # <--- Clear preset
	else:
		# Preset Character
		var preset_idx = p2_sel - base_classes.size() - 1
		if preset_idx >= 0:
			var p = presets[preset_idx]
			p2_class_id = p.class_type
			GameManager.temp_p2_name = p.character_name
			GameManager.temp_p2_preset = p # <--- Save preset

	# Store the CORRECT Class IDs (Enum ints), not the Dropdown Indices
	GameManager.temp_p1_class_selection = p1_class_id
	GameManager.temp_p2_class_selection = p2_class_id
	
	# --- 3. SETUP EDITING STATE ---
	GameManager.editing_player_index = 1 # Start with Player 1
	GameManager.p2_is_custom = p2_custom_check.button_pressed 
	
	# --- 4. HANDLE PLAYER 2 DATA ---
	if GameManager.p2_is_custom:
		# We will build P2 later in the tree
		GameManager.next_match_p2_data = null 
	else:
		# Generate the Bot immediately using the helper
		# (This ensures Presets get their stats/cards calculated correctly)
		var p2 = _get_character_data_from_selection(p2_sel, "Player 2")
		GameManager.next_match_p2_data = p2
	
	# 5. Load the Tree
	get_tree().change_scene_to_file("res://Scenes/ActionTree.tscn")

# Helper to pretty print enum
func _class_enum_to_string(type: int) -> String:
	match type:
		CharacterData.ClassType.HEAVY: return "Heavy"
		CharacterData.ClassType.PATIENT: return "Patient"
		CharacterData.ClassType.QUICK: return "Quick"
		CharacterData.ClassType.TECHNICAL: return "Technical"
	return "Unknown"

func _setup_difficulty():
	# Clear whatever dummy items might be in the editor
	difficulty_option.clear()
	
	# Add items in the same order as the Enum (EASY=0, MEDIUM=1, HARD=2)
	difficulty_option.add_item("Very Easy")
	difficulty_option.add_item("Easy")   # Index 0
	difficulty_option.add_item("Medium") # Index 1
	difficulty_option.add_item("Hard")   # Index 2
	
	# Set Default (Medium)
	difficulty_option.selected = 1
	GameManager.ai_difficulty = GameManager.Difficulty.MEDIUM
	
	# Connect Signal
	difficulty_option.item_selected.connect(_on_difficulty_changed)

func _on_difficulty_changed(index: int):
	# Directly map the dropdown index to the Enum
	# 0 -> EASY, 1 -> MEDIUM, 2 -> HARD
	GameManager.ai_difficulty = index as GameManager.Difficulty
	print("Difficulty set to: " + str(index))
