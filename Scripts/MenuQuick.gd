extends Control

const PRESETS_DIR: String = "res://Data/Presets/"
const ARENA_OPTIONS: Array[String] = ["Random", "Ring", "Dojo", "Street"]
const DIFFICULTY_LABELS: Array[String] = ["Very Easy", "Easy", "Medium", "Hard"]
const CustomFighterStoreScript = preload("res://Scripts/Meta/CustomFighterStore.gd")

@onready var p1_option: OptionButton = $MarginContainer/HBoxContainer/P1_Column/ClassOption
@onready var p1_portrait: TextureRect = $MarginContainer/HBoxContainer/P1_Column/Portrait
@onready var p1_stats_label: Label = $MarginContainer/HBoxContainer/P1_Column/StatsLabel

@onready var p2_option: OptionButton = $MarginContainer/HBoxContainer/P2_Column/ClassOption
@onready var p2_portrait: TextureRect = $MarginContainer/HBoxContainer/P2_Column/Portrait
@onready var p2_stats_label: Label = $MarginContainer/HBoxContainer/P2_Column/StatsLabel
@onready var p2_mode_btn: Button = $MarginContainer/HBoxContainer/P2_Column/P2_Mode_Button

@onready var vs_column: VBoxContainer = $MarginContainer/HBoxContainer/VS_Column
@onready var arena_option: OptionButton = $MarginContainer/HBoxContainer/VS_Column/ArenaOption
@onready var diff_label: Label = $MarginContainer/HBoxContainer/VS_Column/DiffLabel
@onready var difficulty_option: OptionButton = $MarginContainer/HBoxContainer/VS_Column/DifficultyOption
@onready var fight_btn: Button = $MarginContainer/HBoxContainer/VS_Column/QuickFightButton

var roster_entries: Array[Dictionary] = []
var builder_btn: Button = null


func _ready() -> void:
	_load_roster()
	_populate_roster_dropdown(p1_option)
	_populate_roster_dropdown(p2_option)
	_setup_match_options()
	_add_custom_builder_button()

	if roster_entries.size() > 0:
		p1_option.selected = 0
		p2_option.selected = 1 if roster_entries.size() > 1 else 0
	else:
		fight_btn.disabled = true

	p1_option.item_selected.connect(func(_idx: int) -> void: _update_previews())
	p2_option.item_selected.connect(func(_idx: int) -> void: _update_previews())
	fight_btn.pressed.connect(_on_fight_pressed)
	p2_mode_btn.pressed.connect(_on_p2_mode_toggle)

	_update_p2_mode_visuals()
	_update_previews()


func _add_custom_builder_button() -> void:
	if vs_column == null:
		return
	builder_btn = Button.new()
	builder_btn.name = "CustomFighterBuilderButton"
	builder_btn.text = "CUSTOM FIGHTERS"
	builder_btn.custom_minimum_size = Vector2(210, 42)
	builder_btn.add_theme_font_size_override("font_size", 15)
	builder_btn.pressed.connect(_on_builder_pressed)
	vs_column.add_child(builder_btn)


func _on_builder_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	SceneLoader.change_scene("res://Scenes/CustomFighterBuilder.tscn")


func _load_roster() -> void:
	roster_entries.clear()

	# 1. Authored Premade Presets
	for res: Resource in ResourceCatalog.load_dir(PRESETS_DIR):
		if res is PresetCharacter:
			var p: PresetCharacter = res as PresetCharacter
			roster_entries.append({
				"kind": "premade",
				"label": "%s [Premade]" % p.character_name,
				"origin_tag": "Premade",
				"preset": p,
			})

	# 2. Player-Created Custom Fighters (Class & Sandbox)
	for fdata: Dictionary in CustomFighterStoreScript.list_fighters():
		var is_sb: bool = bool(fdata.get("is_sandbox", false))
		var origin_tag: String = CustomFighterStoreScript.get_origin_tag(is_sb)
		roster_entries.append({
			"kind": "custom",
			"label": "%s [%s]" % [str(fdata.get("name", "Custom")), origin_tag],
			"origin_tag": origin_tag,
			"custom": fdata,
		})


func _populate_roster_dropdown(opt: OptionButton) -> void:
	opt.clear()
	for entry: Dictionary in roster_entries:
		opt.add_item(str(entry["label"]))


func _setup_match_options() -> void:
	arena_option.clear()
	for arena_name: String in ARENA_OPTIONS:
		arena_option.add_item(arena_name)
	arena_option.selected = 0

	difficulty_option.clear()
	for d_name: String in DIFFICULTY_LABELS:
		difficulty_option.add_item(d_name)
	difficulty_option.selected = clampi(int(GameManager.ai_difficulty), 0, DIFFICULTY_LABELS.size() - 1)


func _build_roster_fighter(idx: int) -> CharacterData:
	if idx < 0 or idx >= roster_entries.size():
		return null
	var entry: Dictionary = roster_entries[idx]
	if str(entry["kind"]) == "custom":
		return CustomFighterStoreScript.build_character_data(entry["custom"] as Dictionary)
	return ClassFactory.create_from_preset(entry["preset"] as PresetCharacter, true)


func _update_previews() -> void:
	var p1_data: CharacterData = _build_roster_fighter(p1_option.selected)
	if p1_data != null and p1_option.selected >= 0 and p1_option.selected < roster_entries.size():
		p1_portrait.texture = p1_data.portrait
		p1_portrait.flip_h = false
		p1_stats_label.text = _format_roster_summary(roster_entries[p1_option.selected], p1_data)

	var p2_data: CharacterData = _build_roster_fighter(p2_option.selected)
	if p2_data != null and p2_option.selected >= 0 and p2_option.selected < roster_entries.size():
		p2_portrait.texture = p2_data.portrait
		p2_portrait.flip_h = true
		p2_stats_label.text = _format_roster_summary(roster_entries[p2_option.selected], p2_data)


func _format_roster_summary(entry: Dictionary, char_data: CharacterData) -> String:
	var class_str: String = ClassFactory.class_enum_to_string(char_data.class_type)
	var origin: String = str(entry.get("origin_tag", "Premade"))
	var line1: String = "[%s]  %s\nHP: %d  |  SP: %d  |  %d Cards" % [
		origin, class_str, char_data.max_hp, char_data.max_sp, char_data.deck.size()
	]
	if str(entry["kind"]) == "custom":
		var fdata: Dictionary = entry["custom"] as Dictionary
		var tier_lbl: String = CustomFighterStoreScript.get_tier_label(str(fdata.get("point_tier", "veteran")))
		return line1 + "\nPoint Buy: " + tier_lbl
	var preset: PresetCharacter = entry["preset"] as PresetCharacter
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
	if roster_entries.is_empty() or fight_btn.disabled:
		return
	fight_btn.disabled = true

	# 1. Clear any leftover Circuit/Trial/Tutorial state so modifiers never bleed in
	RunManager.clear_active_run_state()
	TrialManager.clear_active_trial()
	TutorialManager.clear_active_tutorial()
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

	# 4. Build Selected Fighters (Premade or Custom)
	var p1: CharacterData = _build_roster_fighter(p1_option.selected)
	var p2: CharacterData = _build_roster_fighter(p2_option.selected)
	if p1 == null or p2 == null:
		printerr("MenuQuick: Failed to build fighters.")
		fight_btn.disabled = false
		return

	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2

	# 5. Launch VS Screen -> CombatArena
	SceneLoader.change_scene("res://Scenes/VsScreen.tscn")
