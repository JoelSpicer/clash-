extends Control

const PRESETS_DIR: String = "res://Data/Presets/"
const ARENA_OPTIONS: Array[String] = ["Random", "Ring", "Dojo", "Street"]
const DIFFICULTY_LABELS: Array[String] = ["Very Easy", "Easy", "Medium", "Hard"]

@onready var p1_option: OptionButton = $MarginContainer/HBoxContainer/P1_Column/ClassOption
@onready var p1_portrait: TextureRect = $MarginContainer/HBoxContainer/P1_Column/Portrait
@onready var p1_stats_label: Label = $MarginContainer/HBoxContainer/P1_Column/StatsLabel

@onready var p2_option: OptionButton = $MarginContainer/HBoxContainer/P2_Column/ClassOption
@onready var p2_portrait: TextureRect = $MarginContainer/HBoxContainer/P2_Column/Portrait
@onready var p2_stats_label: Label = $MarginContainer/HBoxContainer/P2_Column/StatsLabel
@onready var p2_mode_btn: Button = $MarginContainer/HBoxContainer/P2_Column/P2_Mode_Button

@onready var arena_option: OptionButton = $MarginContainer/HBoxContainer/VS_Column/ArenaOption
@onready var diff_label: Label = $MarginContainer/HBoxContainer/VS_Column/DiffLabel
@onready var difficulty_option: OptionButton = $MarginContainer/HBoxContainer/VS_Column/DifficultyOption
@onready var fight_btn: Button = $MarginContainer/HBoxContainer/VS_Column/QuickFightButton

var presets: Array[PresetCharacter] = []


func _ready() -> void:
	_load_presets()
	_populate_preset_dropdown(p1_option)
	_populate_preset_dropdown(p2_option)
	_setup_match_options()

	if presets.size() > 0:
		p1_option.selected = 0
		p2_option.selected = 1 if presets.size() > 1 else 0
	else:
		fight_btn.disabled = true

	p1_option.item_selected.connect(func(_idx: int) -> void: _update_previews())
	p2_option.item_selected.connect(func(_idx: int) -> void: _update_previews())
	fight_btn.pressed.connect(_on_fight_pressed)
	p2_mode_btn.pressed.connect(_on_p2_mode_toggle)

	_update_p2_mode_visuals()
	_update_previews()


func _load_presets() -> void:
	presets.clear()
	var dir: DirAccess = DirAccess.open(PRESETS_DIR)
	if not dir:
		printerr("MenuQuick: Could not open presets directory: ", PRESETS_DIR)
		return

	var filenames: Array[String] = []
	var seen: Dictionary = {}
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name: String = file_name.replace(".remap", "")
			if (clean_name.ends_with(".tres") or clean_name.ends_with(".res")) and not seen.has(clean_name):
				seen[clean_name] = true
				filenames.append(clean_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	filenames.sort()
	for fn: String in filenames:
		var res: Resource = load(PRESETS_DIR + fn)
		if res is PresetCharacter:
			presets.append(res as PresetCharacter)


func _populate_preset_dropdown(opt: OptionButton) -> void:
	opt.clear()
	for p: PresetCharacter in presets:
		opt.add_item(p.character_name)


func _setup_match_options() -> void:
	arena_option.clear()
	for arena_name: String in ARENA_OPTIONS:
		arena_option.add_item(arena_name)
	arena_option.selected = 0

	difficulty_option.clear()
	for d_name: String in DIFFICULTY_LABELS:
		difficulty_option.add_item(d_name)
	difficulty_option.selected = clampi(int(GameManager.ai_difficulty), 0, DIFFICULTY_LABELS.size() - 1)


func _build_preset_fighter(idx: int) -> CharacterData:
	if idx < 0 or idx >= presets.size():
		return null
	return ClassFactory.create_from_preset(presets[idx], true)


func _update_previews() -> void:
	var p1_data: CharacterData = _build_preset_fighter(p1_option.selected)
	if p1_data != null:
		p1_portrait.texture = p1_data.portrait
		p1_portrait.flip_h = false
		p1_stats_label.text = _format_preset_summary(presets[p1_option.selected], p1_data)

	var p2_data: CharacterData = _build_preset_fighter(p2_option.selected)
	if p2_data != null:
		p2_portrait.texture = p2_data.portrait
		p2_portrait.flip_h = true
		p2_stats_label.text = _format_preset_summary(presets[p2_option.selected], p2_data)


func _format_preset_summary(preset: PresetCharacter, char_data: CharacterData) -> String:
	var class_str: String = ClassFactory.class_enum_to_string(char_data.class_type)
	var line1: String = "%s  |  HP: %d  |  SP: %d  |  %d Cards" % [
		class_str, char_data.max_hp, char_data.max_sp, char_data.deck.size()
	]
	if preset.extra_skills.is_empty():
		return line1
	return line1 + "\nSignature: " + ", ".join(preset.extra_skills)


func _on_p2_mode_toggle() -> void:
	GameManager.p2_is_custom = not GameManager.p2_is_custom
	_update_p2_mode_visuals()


func _update_p2_mode_visuals() -> void:
	if GameManager.p2_is_custom:
		p2_mode_btn.text = "OPPONENT: PLAYER 2 (LOCAL)"
		p2_mode_btn.modulate = Color(0.55, 1.0, 0.65)
		diff_label.visible = false
		difficulty_option.visible = false
	else:
		p2_mode_btn.text = "OPPONENT: CPU BOT"
		p2_mode_btn.modulate = Color.WHITE
		diff_label.visible = true
		difficulty_option.visible = true


func _on_fight_pressed() -> void:
	if presets.is_empty():
		return

	# 1. Clear any leftover Circuit run state so sponsors/equipment/boss flags never bleed in
	RunManager.is_arcade_mode = false
	RunManager.player_run_data = null
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""
	RunManager.is_boss_match = false
	RunManager.is_rival_match = false
	RunManager.next_fight_statuses.clear()
	GameManager.rival_intro_override = ""

	# 2. Apply CPU Difficulty
	GameManager.ai_difficulty = difficulty_option.selected as GameManager.Difficulty

	# 3. Apply Environment & Arena Music
	var selected_env: String = ARENA_OPTIONS[arena_option.selected]
	if selected_env == "Random":
		var pool: Array[String] = ["Ring", "Dojo", "Street"]
		selected_env = pool.pick_random()
	GameManager.apply_environment_rules(selected_env)
	if AudioManager.has_method("play_location_music"):
		AudioManager.play_location_music(selected_env)
		AudioManager.set_music_intensity(0.0, 0.0)

	# 4. Build Preset Fighters (full kit, matching Online Multiplayer rules)
	var p1: CharacterData = _build_preset_fighter(p1_option.selected)
	var p2: CharacterData = _build_preset_fighter(p2_option.selected)
	if p1 == null or p2 == null:
		printerr("MenuQuick: Failed to build preset fighters.")
		return

	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2

	# 5. Launch VS Screen -> CombatArena
	SceneLoader.change_scene("res://Scenes/VsScreen.tscn")
