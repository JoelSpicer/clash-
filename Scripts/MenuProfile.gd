extends Control

const AchievementCatalogScript = preload("res://Scripts/Data/AchievementCatalog.gd")
const AchievementManagerScript = preload("res://Scripts/Meta/AchievementManager.gd")
const MatchTelemetryScript = preload("res://Scripts/Meta/MatchTelemetry.gd")

var _header_label: RichTextLabel = null
var _tabs: TabContainer = null
var _stats_grid: GridContainer = null
var _history_vbox: VBoxContainer = null
var _ach_vbox: VBoxContainer = null
var _title_option: OptionButton = null
var _unlocked_titles: Array[String] = []


func _ready() -> void:
	_build_ui()
	_refresh_all()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	var header_panel: PanelContainer = _make_panel(Color(0.06, 0.08, 0.13, 0.9), Color(0.95, 0.8, 0.3, 0.8))
	main_vbox.add_child(header_panel)

	_header_label = RichTextLabel.new()
	_header_label.bbcode_enabled = true
	_header_label.fit_content = true
	_header_label.scroll_active = false
	_header_label.add_theme_font_size_override("normal_font_size", 16)
	header_panel.add_child(_header_label)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_tabs)

	# --- TAB 1: CAREER STATS ---
	var stats_tab: ScrollContainer = ScrollContainer.new()
	stats_tab.name = "Career Stats"
	stats_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(stats_tab)

	var stats_pad: MarginContainer = MarginContainer.new()
	stats_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_pad.add_theme_constant_override("margin_left", 16)
	stats_pad.add_theme_constant_override("margin_right", 16)
	stats_pad.add_theme_constant_override("margin_top", 16)
	stats_pad.add_theme_constant_override("margin_bottom", 16)
	stats_tab.add_child(stats_pad)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 3
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", 14)
	_stats_grid.add_theme_constant_override("v_separation", 14)
	stats_pad.add_child(_stats_grid)

	# --- TAB 2: MATCH HISTORY ---
	var hist_tab: ScrollContainer = ScrollContainer.new()
	hist_tab.name = "Match History"
	hist_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(hist_tab)

	var hist_pad: MarginContainer = MarginContainer.new()
	hist_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hist_pad.add_theme_constant_override("margin_left", 16)
	hist_pad.add_theme_constant_override("margin_right", 16)
	hist_pad.add_theme_constant_override("margin_top", 14)
	hist_pad.add_theme_constant_override("margin_bottom", 14)
	hist_tab.add_child(hist_pad)

	_history_vbox = VBoxContainer.new()
	_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_vbox.add_theme_constant_override("separation", 8)
	hist_pad.add_child(_history_vbox)

	# --- TAB 3: ACHIEVEMENTS & TITLES ---
	var ach_root: VBoxContainer = VBoxContainer.new()
	ach_root.name = "Achievements & Titles"
	ach_root.add_theme_constant_override("separation", 10)
	_tabs.add_child(ach_root)

	var title_bar: PanelContainer = _make_panel(Color(0.07, 0.1, 0.16, 0.92), Color(0.45, 0.72, 1.0, 0.7))
	ach_root.add_child(title_bar)

	var title_hbox: HBoxContainer = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 14)
	title_bar.add_child(title_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "EQUIPPED VS TITLE:"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_hbox.add_child(title_lbl)

	_title_option = OptionButton.new()
	_title_option.custom_minimum_size = Vector2(240, 34)
	_title_option.item_selected.connect(_on_title_selected)
	title_hbox.add_child(_title_option)

	var title_hint: Label = Label.new()
	title_hint.text = "Displayed on the VS Screen across all game modes!"
	title_hint.add_theme_font_size_override("font_size", 13)
	title_hint.add_theme_color_override("font_color", Color(0.75, 0.84, 0.95))
	title_hbox.add_child(title_hint)

	var ach_scroll: ScrollContainer = ScrollContainer.new()
	ach_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ach_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ach_root.add_child(ach_scroll)

	var ach_pad: MarginContainer = MarginContainer.new()
	ach_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_pad.add_theme_constant_override("margin_left", 14)
	ach_pad.add_theme_constant_override("margin_right", 14)
	ach_pad.add_theme_constant_override("margin_top", 8)
	ach_pad.add_theme_constant_override("margin_bottom", 14)
	ach_scroll.add_child(ach_pad)

	_ach_vbox = VBoxContainer.new()
	_ach_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ach_vbox.add_theme_constant_override("separation", 8)
	ach_pad.add_child(_ach_vbox)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or Pausemenu.visible or _tabs == null:
		return
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_1:
		_tabs.current_tab = 0
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_2:
		_tabs.current_tab = 1
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_3:
		_tabs.current_tab = 2
		get_viewport().set_input_as_handled()


func _refresh_all() -> void:
	var meta: GlobalSaveData = RunManager.meta_data
	if meta == null:
		return

	var all_ach: Array[Dictionary] = AchievementCatalogScript.get_all()
	var unlocked_cnt: int = meta.unlocked_achievements.size()
	var trials_cnt: int = meta.completed_trials.size()
	var total_trials: int = TrialManager.get_all_trials().size()
	var active_t: String = meta.active_title
	var title_disp: String = "[color=#ffd966]« %s »[/color]" % active_t.to_upper() if active_t != "" else "[color=#99aabb]No Title Equipped[/color]"

	_header_label.text = (
		"[center][b]%s[/b]    |    Tokens: [color=#66e0ff][b]%dT[/b][/color]"
		+ "    |    Achievements: [color=#ffd966][b]%d / %d[/b][/color]"
		+ "    |    Dojo Trials: [color=#73ff8c][b]%d / %d[/b][/color][/center]"
	) % [title_disp, meta.circuit_tokens, unlocked_cnt, all_ach.size(), trials_cnt, total_trials]

	_populate_stats(meta)
	_populate_history(meta)
	_populate_achievements(meta)


func _populate_stats(meta: GlobalSaveData) -> void:
	for c: Node in _stats_grid.get_children():
		c.queue_free()

	var cs: Dictionary = meta.career_stats
	var matches: int = int(cs.get("matches", 0))
	var wins: int = int(cs.get("wins", 0))
	var losses: int = int(cs.get("losses", 0))
	var wr: float = (100.0 * float(wins) / float(matches)) if matches > 0 else 0.0
	var cards_map: Dictionary = cs.get("cards_played", {}) as Dictionary if cs.get("cards_played") is Dictionary else {}
	var wbc: Dictionary = cs.get("wins_by_class", {}) as Dictionary if cs.get("wins_by_class") is Dictionary else {}

	var fav_class: String = "—"
	var fav_wins: int = 0
	for k: Variant in wbc.keys():
		if int(wbc[k]) > fav_wins:
			fav_wins = int(wbc[k])
			fav_class = "%s (%dW)" % [str(k), fav_wins]

	var tiles: Array[Dictionary] = [
		{ "k": "CAREER RECORD", "v": "%dW - %dL (%.1f%%)" % [wins, losses, wr], "c": Color(0.45, 0.95, 0.6) },
		{ "k": "HIGHEST LEAGUE", "v": "League %d (%d Won)" % [int(cs.get("highest_league", 0)), int(cs.get("leagues_won", 0))], "c": Color(1.0, 0.85, 0.35) },
		{ "k": "FAVORITE CLASS", "v": fav_class, "c": Color(0.6, 0.88, 1.0) },
		{ "k": "TOTAL CLASHES", "v": "%d  (Max Combo: %d)" % [int(cs.get("clashes", 0)), int(cs.get("max_combo", 0))], "c": Color.WHITE },
		{ "k": "DAMAGE DEALT / TAKEN", "v": "%d  /  %d" % [int(cs.get("damage_dealt", 0)), int(cs.get("damage_taken", 0))], "c": Color(1.0, 0.58, 0.45) },
		{ "k": "MOST-PLAYED CARD", "v": MatchTelemetryScript.get_top_card(cards_map), "c": Color(1.0, 0.88, 0.45) },
		{ "k": "PARRIES / DODGES", "v": "%d  /  %d" % [int(cs.get("parries", 0)), int(cs.get("dodges", 0))], "c": Color(0.55, 0.92, 1.0) },
		{ "k": "REVERSALS / GUARD BREAKS", "v": "%d  /  %d" % [int(cs.get("reversals", 0)), int(cs.get("guard_breaks", 0))], "c": Color(0.4, 1.0, 0.85) },
		{ "k": "WALL CRUSHES (INFL / SUFF)", "v": "%d  /  %d" % [int(cs.get("wall_crushes_inflicted", 0)), int(cs.get("wall_crushes_suffered", 0))], "c": Color(1.0, 0.48, 0.48) },
		{ "k": "SUPERS / FINISHES", "v": "%d  /  %d" % [int(cs.get("supers_used", 0)), int(cs.get("super_finishes", 0))], "c": Color(1.0, 0.78, 0.25) },
		{ "k": "FLAWLESS WINS", "v": str(int(cs.get("flawless_wins", 0))), "c": Color(0.75, 1.0, 0.55) },
		{ "k": "RIVALS / 2-TRAIT BOSSES", "v": "%d  /  %d" % [int(cs.get("rival_wins", 0)), int(cs.get("double_boss_wins", 0))], "c": Color(1.0, 0.65, 0.85) },
	]

	for tile: Dictionary in tiles:
		var p: PanelContainer = _make_panel(Color(0.08, 0.1, 0.16, 0.9), Color(0.32, 0.44, 0.65, 0.65))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vb: VBoxContainer = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		p.add_child(vb)

		var kl: Label = Label.new()
		kl.text = str(tile["k"])
		kl.add_theme_font_size_override("font_size", 12)
		kl.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88))
		vb.add_child(kl)

		var vl: Label = Label.new()
		vl.text = str(tile["v"])
		vl.add_theme_font_size_override("font_size", 20)
		vl.add_theme_color_override("font_color", tile["c"] as Color)
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(vl)

		_stats_grid.add_child(p)


func _populate_history(meta: GlobalSaveData) -> void:
	for c: Node in _history_vbox.get_children():
		c.queue_free()

	if meta.match_history.is_empty():
		var empty: Label = Label.new()
		empty.text = "No matches recorded yet. Fight in The Circuit, Quick Match, or Online to build your Match History!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
		_history_vbox.add_child(empty)
		return

	for entry: Dictionary in meta.match_history:
		var is_win: bool = (str(entry.get("result", "")) == "WIN")
		var border_col: Color = Color(0.3, 0.82, 0.45, 0.75) if is_win else Color(0.85, 0.32, 0.32, 0.75)
		var row: PanelContainer = _make_panel(Color(0.07, 0.09, 0.14, 0.9), border_col)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		row.add_child(hb)

		var res_lbl: Label = Label.new()
		res_lbl.text = "WIN" if is_win else "LOSS"
		res_lbl.custom_minimum_size = Vector2(56, 0)
		res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		res_lbl.add_theme_font_size_override("font_size", 16)
		res_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55) if is_win else Color(1.0, 0.42, 0.42))
		hb.add_child(res_lbl)

		var info: RichTextLabel = RichTextLabel.new()
		info.bbcode_enabled = true
		info.fit_content = true
		info.scroll_active = false
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("normal_font_size", 14)

		var mode_s: String = str(entry.get("mode", "Match"))
		var league_n: int = int(entry.get("league", 0))
		if league_n > 0:
			mode_s += " L%d" % league_n
		info.text = "[b]%s[/b] (%s)  vs  [b]%s[/b] (%s)   [color=#88bbff][%s][/color]\n[color=#bbbbcc]Clashes: %d  ·  Dmg: %d / -%d  ·  Parries: %d  ·  Top: %s[/color]" % [
			str(entry.get("fighter", "P1")),
			str(entry.get("fighter_class", "")),
			str(entry.get("opponent", "P2")),
			str(entry.get("opponent_class", "")),
			mode_s,
			int(entry.get("clashes", 0)),
			int(entry.get("damage_dealt", 0)),
			int(entry.get("damage_taken", 0)),
			int(entry.get("parries", 0)),
			str(entry.get("top_card", "—")),
		]
		hb.add_child(info)

		var ts: Label = Label.new()
		ts.text = str(entry.get("timestamp", ""))
		ts.add_theme_font_size_override("font_size", 12)
		ts.add_theme_color_override("font_color", Color(0.6, 0.66, 0.74))
		hb.add_child(ts)

		_history_vbox.add_child(row)


func _populate_achievements(meta: GlobalSaveData) -> void:
	# 1. Populate Title Selector
	_title_option.clear()
	_unlocked_titles.clear()
	_title_option.add_item("None")
	_unlocked_titles.append("")

	var selected_idx: int = 0
	for t: String in AchievementCatalogScript.get_unlocked_titles(meta):
		_unlocked_titles.append(t)
		_title_option.add_item("« %s »" % t)
		if t == meta.active_title:
			selected_idx = _unlocked_titles.size() - 1
	_title_option.selected = selected_idx

	# 2. Populate Achievement Cards grouped by Category
	for c: Node in _ach_vbox.get_children():
		c.queue_free()

	var categories: Array[String] = [
		AchievementCatalogScript.CATEGORY_COMBAT,
		AchievementCatalogScript.CATEGORY_CIRCUIT,
		AchievementCatalogScript.CATEGORY_CHALLENGES,
		AchievementCatalogScript.CATEGORY_COLLECTION,
	]
	var all_ach: Array[Dictionary] = AchievementCatalogScript.get_all()

	for cat: String in categories:
		var cat_lbl: Label = Label.new()
		cat_lbl.text = cat.to_upper()
		cat_lbl.add_theme_font_size_override("font_size", 15)
		cat_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		_ach_vbox.add_child(cat_lbl)

		for ach: Dictionary in all_ach:
			if str(ach.get("category", "")) != cat:
				continue
			var prog: Dictionary = AchievementManagerScript.get_progress(ach, meta)
			var unlocked: bool = bool(prog["unlocked"])
			var cur: int = int(prog["current"])
			var tgt: int = int(prog["target"])

			var card: PanelContainer = _make_panel(
				Color(0.09, 0.16, 0.12, 0.92) if unlocked else Color(0.07, 0.09, 0.14, 0.88),
				Color(1.0, 0.86, 0.3, 0.9) if unlocked else Color(0.3, 0.36, 0.48, 0.65)
			)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var hb: HBoxContainer = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 14)
			card.add_child(hb)

			var left_vb: VBoxContainer = VBoxContainer.new()
			left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			left_vb.add_theme_constant_override("separation", 3)
			hb.add_child(left_vb)

			var name_lbl: Label = Label.new()
			name_lbl.text = ("%s  %s" % ["[✓]" if unlocked else "[  ]", str(ach.get("name", ""))])
			name_lbl.add_theme_font_size_override("font_size", 16)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45) if unlocked else Color.WHITE)
			left_vb.add_child(name_lbl)

			var desc_lbl: Label = Label.new()
			desc_lbl.text = str(ach.get("description", ""))
			desc_lbl.add_theme_font_size_override("font_size", 13)
			desc_lbl.add_theme_color_override("font_color", Color(0.76, 0.82, 0.9))
			left_vb.add_child(desc_lbl)

			var right_vb: VBoxContainer = VBoxContainer.new()
			right_vb.custom_minimum_size = Vector2(210, 0)
			right_vb.add_theme_constant_override("separation", 4)
			hb.add_child(right_vb)

			var rew_parts: Array[String] = ["+%dT" % int(ach.get("token_reward", 0))]
			var title_rew: String = str(ach.get("title_reward", ""))
			if title_rew != "":
				rew_parts.append("«%s»" % title_rew)
			var rew_lbl: Label = Label.new()
			rew_lbl.text = " · ".join(rew_parts)
			rew_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rew_lbl.add_theme_font_size_override("font_size", 13)
			rew_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65) if unlocked else Color(1.0, 0.82, 0.35))
			right_vb.add_child(rew_lbl)

			var pbar: ProgressBar = ProgressBar.new()
			pbar.min_value = 0
			pbar.max_value = tgt
			pbar.value = cur
			pbar.custom_minimum_size = Vector2(200, 18)
			pbar.show_percentage = false
			right_vb.add_child(pbar)

			var plbl: Label = Label.new()
			plbl.text = "UNLOCKED" if unlocked else ("%d / %d" % [cur, tgt])
			plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			plbl.add_theme_font_size_override("font_size", 11)
			plbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65) if unlocked else Color(0.7, 0.78, 0.88))
			right_vb.add_child(plbl)

			_ach_vbox.add_child(card)


func _on_title_selected(idx: int) -> void:
	if idx < 0 or idx >= _unlocked_titles.size():
		return
	AudioManager.play_sfx("ui_click")
	RunManager.set_active_title(_unlocked_titles[idx])
	_refresh_all()


func _make_panel(bg: Color, border: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	return p
