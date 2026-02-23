extends Control

# --- NODES ---
# Added Portrait references
@onready var p1_option = $MarginContainer/HBoxContainer/P1_Column/ClassOption
@onready var p1_portrait = $MarginContainer/HBoxContainer/P1_Column/Portrait # <--- NEW
@onready var p2_option = $MarginContainer/HBoxContainer/P2_Column/ClassOption
@onready var p2_portrait = $MarginContainer/HBoxContainer/P2_Column/Portrait # <--- NEW
@onready var p2_mode_btn = $MarginContainer/HBoxContainer/P2_Column/P2_Mode_Button
@onready var fight_btn = $MarginContainer/HBoxContainer/VS_Column/QuickFightButton
@onready var custom_btn = $MarginContainer/HBoxContainer/VS_Column/CustomDeckButton

var presets: Array[PresetCharacter] = []
var base_classes = []

func _ready():
	# --- NEW: AUTO-GENERATE CLASS ARRAYS ---
	for key in CharacterData.ClassType.keys():
		base_classes.append(key.capitalize())
	# ---------------------------------------
	# ... rest of your _ready code
	_load_presets()
	_setup_options(p1_option)
	_setup_options(p2_option)
	
	# Defaults
	p1_option.selected = 0
	p2_option.selected = 1
	
	# --- NEW: Connect Signals to Update Portraits ---
	p1_option.item_selected.connect(func(_idx): _update_portraits())
	p2_option.item_selected.connect(func(_idx): _update_portraits())
	
	# Connections
	fight_btn.pressed.connect(_on_fight_pressed)
	p2_mode_btn.pressed.connect(_on_p2_mode_toggle)
	if custom_btn:
		custom_btn.pressed.connect(_on_custom_deck_pressed)
	# Sync State
	if GameManager.p2_is_custom == null: GameManager.p2_is_custom = false
	_update_p2_btn_visuals()
	
	# Initial Update
	_update_portraits()

# --- NEW: UPDATE LOGIC ---
func _update_portraits():
	# Update P1
	var p1_data = _get_char(p1_option.selected, "P1")
	if p1_portrait:
		p1_portrait.texture = p1_data.portrait
		
	# Update P2
	var p2_data = _get_char(p2_option.selected, "P2")
	if p2_portrait:
		p2_portrait.texture = p2_data.portrait
		# Flip P2 to face center
		p2_portrait.flip_h = true

func _on_fight_pressed():
	# 1. Random Environment
	var envs = ["Ring", "Dojo", "Street"]
	GameManager.apply_environment_rules(envs.pick_random())
	
	# 2. Setup Data
	var p1 = _get_char(p1_option.selected, "Player 1")
	var p2 = _get_char(p2_option.selected, "Player 2")
	
	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2
	
	# 3. Launch
	SceneLoader.change_scene("res://Scenes/VsScreen.tscn")

func _on_p2_mode_toggle():
	GameManager.p2_is_custom = !GameManager.p2_is_custom
	_update_p2_btn_visuals()

func _update_p2_btn_visuals():
	if GameManager.p2_is_custom:
		p2_mode_btn.text = "OPPONENT: PLAYER 2"
		p2_mode_btn.modulate = Color.GREEN
	else:
		p2_mode_btn.text = "OPPONENT: CPU BOT"
		p2_mode_btn.modulate = Color.WHITE

# --- HELPERS ---
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

func _setup_options(opt):
	opt.clear()
	for c in base_classes: opt.add_item(c)
	if presets.size() > 0: opt.add_separator("Presets")
	for p in presets: opt.add_item(p.character_name)

func _get_char(idx, pname):
	if idx < base_classes.size():
		return ClassFactory.create_character(idx as CharacterData.ClassType, pname)
	var preset_idx = idx - base_classes.size() - 1
	if preset_idx >= 0: return ClassFactory.create_from_preset(presets[preset_idx])
	return ClassFactory.create_character(0 as CharacterData.ClassType, "Error")

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
		var p2 = _get_char(p2_sel, "Player 2")
		GameManager.next_match_p2_data = p2
	
	SceneLoader.change_scene("res://Scenes/ActionTree.tscn")
