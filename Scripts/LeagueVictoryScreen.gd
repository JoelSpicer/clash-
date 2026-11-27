extends Control

const MatchTelemetryScript = preload("res://Scripts/Meta/MatchTelemetry.gd")

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var portrait: TextureRect = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FighterRow/Portrait
@onready var stats_summary: RichTextLabel = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FighterRow/StatsSummary
@onready var token_reward_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TokenRewardLabel
@onready var heal_note_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HealNoteLabel
@onready var continue_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/ContinueButton
@onready var retire_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/RetireButton


func _ready() -> void:
	AudioManager.play_music("menu_theme")
	AudioManager.play_sfx("ui_confirm")

	var league_num: int = maxi(1, RunManager.leagues_completed)
	var next_league: int = league_num + 1

	title_label.text = "LEAGUE %d CHAMPION!" % league_num
	subtitle_label.text = "You conquered the League %d Finals and claimed the title." % league_num
	continue_btn.text = "CONTINUE TO LEAGUE %d (2-TRAIT BOSSES)" % next_league

	var awarded: int = RunManager.last_league_tokens_awarded
	var bank: int = RunManager.meta_data.circuit_tokens if RunManager.meta_data else 0
	token_reward_label.text = "+%d CIRCUIT TOKENS EARNED! (Bank: %d)" % [awarded, bank]

	var p1: CharacterData = RunManager.player_run_data
	if p1 != null:
		if p1.portrait:
			portrait.texture = p1.portrait
		var class_str: String = ClassFactory.class_enum_to_string(p1.class_type)
		var sponsor_str: String = RunManager.active_sponsor.item_name if RunManager.active_sponsor else "Independent"
		var summary_txt: String = (
			"[b]%s[/b] (%s — Lv.%d)\n" % [p1.character_name, class_str, RunManager.current_level]
			+ "Max HP: [color=#ff7777]%d[/color]   |   Max SP: [color=#66ccff]%d[/color]\n" % [p1.max_hp, p1.max_sp]
			+ "Sponsor: [color=#ffcc44]%s[/color]\n" % sponsor_str
			+ "Equipment Collected: %d   |   Deck Size: %d" % [p1.equipment.size(), p1.deck.size()]
		)
		if not RunManager.run_stats.is_empty():
			summary_txt += "\n\n" + MatchTelemetryScript.format_summary_bbcode(RunManager.run_stats, true)
		if not RunManager.last_unlocked_achievements.is_empty():
			var ach_names: Array[String] = []
			for a: Dictionary in RunManager.last_unlocked_achievements:
				ach_names.append(str(a.get("name", "")))
			summary_txt += "\n[color=#ffd966]★ Achievements Unlocked: " + ", ".join(ach_names) + "[/color]"
		stats_summary.text = summary_txt
		heal_note_label.text = "Full HP restored (%d/%d) ahead of League %d." % [p1.current_hp, p1.max_hp, next_league]
	else:
		stats_summary.text = "[b]Champion Preview[/b]\nNo active run loaded."
		heal_note_label.text = ""

	continue_btn.pressed.connect(_on_continue_pressed)
	retire_btn.pressed.connect(_on_retire_pressed)


func _on_continue_pressed() -> void:
	continue_btn.disabled = true
	retire_btn.disabled = true
	RunManager.continue_to_next_league()


func _on_retire_pressed() -> void:
	continue_btn.disabled = true
	retire_btn.disabled = true
	RunManager.retire_champion()
