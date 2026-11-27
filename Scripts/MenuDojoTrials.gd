extends Control

var _list_vbox: VBoxContainer
var _progress_lbl: Label
var _dossier_title: Label
var _dossier_meta: Label
var _dossier_reward: Label
var _dossier_briefing: RichTextLabel
var _dossier_setup: RichTextLabel
var _dossier_cards: RichTextLabel
var _start_btn: Button

var _selected_trial: TrialData = null
var _trial_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_populate_trial_list()
	var all_trials: Array[TrialData] = TrialManager.get_all_trials()
	if not all_trials.is_empty():
		_select_trial(all_trials[0])


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# CarouselHub's ContentContainer already applies outer offsets (61/75/65/37)
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

	# Progress Header
	_progress_lbl = Label.new()
	_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_lbl.add_theme_font_size_override("font_size", 18)
	_progress_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	main_vbox.add_child(_progress_lbl)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(hbox)

	# --- LEFT PANEL: SCROLLABLE TRIAL LIST ---
	var left_panel: PanelContainer = _make_card_panel(Color(0.06, 0.08, 0.12, 0.88), Color(0.35, 0.55, 0.85, 0.7))
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.05
	left_panel.clip_contents = true
	hbox.add_child(left_panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 100)
	left_panel.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_vbox)

	# --- RIGHT PANEL: TRIAL DOSSIER ---
	var right_panel: PanelContainer = _make_card_panel(Color(0.07, 0.09, 0.14, 0.92), Color(0.95, 0.78, 0.25, 0.8))
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.15
	right_panel.clip_contents = true
	hbox.add_child(right_panel)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	_dossier_title = Label.new()
	_dossier_title.add_theme_font_size_override("font_size", 26)
	_dossier_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_dossier_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_dossier_title)

	_dossier_meta = Label.new()
	_dossier_meta.add_theme_font_size_override("font_size", 15)
	_dossier_meta.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	_dossier_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_dossier_meta)

	_dossier_reward = Label.new()
	_dossier_reward.add_theme_font_size_override("font_size", 15)
	right_vbox.add_child(_dossier_reward)

	var sep1: HSeparator = HSeparator.new()
	right_vbox.add_child(sep1)

	var dossier_scroll: ScrollContainer = ScrollContainer.new()
	dossier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dossier_scroll.custom_minimum_size = Vector2(0, 80)
	right_vbox.add_child(dossier_scroll)

	var dossier_body: VBoxContainer = VBoxContainer.new()
	dossier_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_body.add_theme_constant_override("separation", 10)
	dossier_scroll.add_child(dossier_body)

	_dossier_briefing = RichTextLabel.new()
	_dossier_briefing.bbcode_enabled = true
	_dossier_briefing.fit_content = true
	_dossier_briefing.scroll_active = false
	_dossier_briefing.add_theme_font_size_override("normal_font_size", 16)
	dossier_body.add_child(_dossier_briefing)

	_dossier_setup = RichTextLabel.new()
	_dossier_setup.bbcode_enabled = true
	_dossier_setup.fit_content = true
	_dossier_setup.scroll_active = false
	_dossier_setup.add_theme_font_size_override("normal_font_size", 15)
	dossier_body.add_child(_dossier_setup)

	_dossier_cards = RichTextLabel.new()
	_dossier_cards.bbcode_enabled = true
	_dossier_cards.fit_content = true
	_dossier_cards.scroll_active = false
	_dossier_cards.add_theme_font_size_override("normal_font_size", 15)
	dossier_body.add_child(_dossier_cards)

	_start_btn = Button.new()
	_start_btn.text = "START TRIAL"
	_start_btn.custom_minimum_size = Vector2(220, 48)
	_start_btn.add_theme_font_size_override("font_size", 20)
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.6, 0.32)
	btn_style.set_corner_radius_all(8)
	_start_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.24, 0.72, 0.4)
	_start_btn.add_theme_stylebox_override("hover", btn_hover)
	_start_btn.pressed.connect(_on_start_pressed)
	right_vbox.add_child(_start_btn)


func _populate_trial_list() -> void:
	for child: Node in _list_vbox.get_children():
		child.queue_free()
	_trial_buttons.clear()

	var all_count: int = TrialManager.get_all_trials().size()
	var cleared_count: int = TrialManager.get_completed_count()
	_progress_lbl.text = "DOJO MASTERY: %d / %d TRIALS CLEARED" % [cleared_count, all_count]

	_add_category_section("TIER 1 — CORE INTERACTION DRILLS", TrialData.Category.INTERACTION_DRILL, Color(0.55, 0.88, 1.0))
	_add_category_section("TIER 2 — CLASS PASSIVES & HYBRID TRAITS", TrialData.Category.PASSIVES_AND_HYBRIDS, Color(1.0, 0.84, 0.38))
	_add_category_section("TIER 3 — TACTICAL PUZZLES", TrialData.Category.TACTICAL_PUZZLE, Color(1.0, 0.58, 0.58))


func _add_category_section(header_text: String, cat: TrialData.Category, tint: Color) -> void:
	var trials: Array[TrialData] = TrialManager.get_trials_by_category(cat)
	var done: int = TrialManager.get_completed_count(cat)

	var hdr: Label = Label.new()
	hdr.text = "%s  (%d / %d)" % [header_text, done, trials.size()]
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", tint)
	_list_vbox.add_child(hdr)

	for t: TrialData in trials:
		var cleared: bool = TrialManager.is_trial_completed(t.id)
		var check_str: String = "[✓] " if cleared else "[  ] "
		var stars: String = "★".repeat(clampi(t.difficulty, 1, 3))

		var btn: Button = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 15)
		btn.text = "%s%02d. %s   •   %s   %s" % [check_str, t.order, t.title, t.focus_trait, stars]
		btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			_select_trial(t)
		)
		_style_list_button(btn, cleared, false)
		_list_vbox.add_child(btn)
		_trial_buttons[t.id] = btn


func _select_trial(t: TrialData) -> void:
	_selected_trial = t
	for tid: String in _trial_buttons:
		var b: Button = _trial_buttons[tid] as Button
		_style_list_button(b, TrialManager.is_trial_completed(tid), tid == t.id)

	var cleared: bool = TrialManager.is_trial_completed(t.id)
	var stars: String = "★".repeat(clampi(t.difficulty, 1, 3))
	var intent_tag: String = "Telegraphed Move" if t.show_enemy_intent else "Hidden Move (Use Inspect!)"

	_dossier_title.text = t.title
	_dossier_meta.text = "%s  •  %s  •  %d Clash%s  •  %s" % [
		t.focus_trait,
		stars,
		t.turn_limit,
		"es" if t.turn_limit != 1 else "",
		intent_tag,
	]

	if cleared:
		_dossier_reward.text = "STATUS: CLEARED ✓ (First-clear %dT already claimed)" % t.token_reward
		_dossier_reward.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	else:
		_dossier_reward.text = "FIRST-CLEAR REWARD: +%d Circuit Tokens" % t.token_reward
		_dossier_reward.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	_dossier_briefing.text = "[b][color=#ffd966]Objective:[/color][/b] %s\n\n%s" % [
		t.objective_short,
		t.briefing_text,
	]

	var mom_label: String = "Neutral (0)"
	if t.start_momentum > 0 and t.start_momentum <= 4:
		mom_label = "Your Advantage (Slot %d)" % t.start_momentum
	elif t.start_momentum >= 5:
		mom_label = "Sensei Advantage (Slot %d)" % t.start_momentum

	var class_name_str: String = ClassFactory.class_enum_to_string(t.p1_class)
	_dossier_setup.text = (
		"[b][color=#7fd8ff]Starting Setup:[/color][/b]\n"
		+ "• [b]You (%s):[/b] %d/%d HP, %d/%d SP\n"
		+ "• [b]%s:[/b] %d/%d HP, %d/%d SP\n"
		+ "• [b]Momentum:[/b] %s"
	) % [
		class_name_str, t.p1_start_hp, t.p1_max_hp, t.p1_start_sp, t.p1_max_sp,
		t.p2_name, t.p2_start_hp, t.p2_max_hp, t.p2_start_sp, t.p2_max_sp,
		mom_label,
	]

	var hand_str: String = ", ".join(t.p1_card_names)
	_dossier_cards.text = "[b][color=#7fd8ff]Your Hand:[/color][/b] " + hand_str


func _on_start_pressed() -> void:
	if _selected_trial == null:
		return
	AudioManager.play_sfx("ui_click")
	TrialManager.start_trial(_selected_trial.id)


func _style_list_button(btn: Button, cleared: bool, selected: bool) -> void:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	if selected:
		s.bg_color = Color(0.18, 0.34, 0.56, 0.95)
		s.border_color = Color(1.0, 0.88, 0.35)
		s.set_border_width_all(2)
	elif cleared:
		s.bg_color = Color(0.1, 0.2, 0.14, 0.85)
		s.border_color = Color(0.35, 0.75, 0.45, 0.6)
		s.set_border_width_all(1)
	else:
		s.bg_color = Color(0.11, 0.13, 0.19, 0.85)
		s.border_color = Color(0.28, 0.32, 0.42, 0.5)
		s.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", s)
	var hov: StyleBoxFlat = s.duplicate() as StyleBoxFlat
	hov.bg_color = s.bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hov)


func _make_card_panel(bg: Color, border: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", s)
	return p
