class_name TrialOverlay
extends Control

signal briefing_dismissed

var _top_panel: PanelContainer
var _mini_pill: Button
var _title_lbl: Label
var _turn_lbl: Label
var _objective_lbl: Label
var _intent_lbl: RichTextLabel
var _hint_box: PanelContainer
var _hint_lbl: RichTextLabel
var _hint_visible: bool = false
var _collapsed: bool = false

var _modal_layer: CanvasLayer
var _modal_backdrop: ColorRect
var _modal_panel: PanelContainer
var _modal_title: Label
var _modal_badge: Label
var _modal_body: RichTextLabel
var _modal_hint_lbl: RichTextLabel
var _modal_buttons: HBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top_bar()
	_build_modal()
	refresh_banner()


func _build_top_bar() -> void:
	# Positioned directly beneath LogToggle (X: 12, Y: 201..238) on the left side,
	# keeping P1_HUD, P2_HUD, MomentumTracker, ClashLayer, and Inspect completely clear.
	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	outer_vbox.offset_left = 12.0
	outer_vbox.offset_top = 244.0
	outer_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer_vbox.add_theme_constant_override("separation", 5)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer_vbox)

	# Tiny collapsed pill (shown ONLY when hidden)
	_mini_pill = Button.new()
	_mini_pill.text = "TRIAL INFO ▼"
	_mini_pill.custom_minimum_size = Vector2(124, 24)
	_mini_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_mini_pill.add_theme_font_size_override("font_size", 12)
	var pill_style: StyleBoxFlat = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.07, 0.09, 0.14, 0.9)
	pill_style.border_color = Color(0.95, 0.78, 0.25, 0.85)
	pill_style.set_border_width_all(1)
	pill_style.set_corner_radius_all(6)
	_mini_pill.add_theme_stylebox_override("normal", pill_style)
	_mini_pill.pressed.connect(_on_toggle_collapse)
	_mini_pill.visible = false
	outer_vbox.add_child(_mini_pill)

	# Compact left-docked info card (320px wide beneath Show Log)
	_top_panel = PanelContainer.new()
	_top_panel.custom_minimum_size = Vector2(320, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.14, 0.9)
	style.border_color = Color(0.95, 0.78, 0.25, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_top_panel.add_theme_stylebox_override("panel", style)
	outer_vbox.add_child(_top_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_top_panel.add_child(vbox)

	# Row 1: Title + Clash counter
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.clip_text = true
	header_row.add_child(_title_lbl)

	_turn_lbl = Label.new()
	_turn_lbl.add_theme_font_size_override("font_size", 12)
	_turn_lbl.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	header_row.add_child(_turn_lbl)

	# Row 2: Objective + Intent
	_objective_lbl = Label.new()
	_objective_lbl.add_theme_font_size_override("font_size", 12)
	_objective_lbl.add_theme_color_override("font_color", Color.WHITE)
	_objective_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_objective_lbl)

	_intent_lbl = RichTextLabel.new()
	_intent_lbl.bbcode_enabled = true
	_intent_lbl.fit_content = true
	_intent_lbl.scroll_active = false
	_intent_lbl.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(_intent_lbl)

	# Row 3: Compact action buttons
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var hide_btn: Button = _make_bar_button("HIDE ▲")
	hide_btn.pressed.connect(_on_toggle_collapse)
	btn_row.add_child(hide_btn)

	var hint_btn: Button = _make_bar_button("HINT")
	hint_btn.pressed.connect(_on_toggle_hint)
	btn_row.add_child(hint_btn)

	var retry_btn: Button = _make_bar_button("RETRY")
	retry_btn.pressed.connect(func() -> void: TrialManager.retry_trial())
	btn_row.add_child(retry_btn)

	var exit_btn: Button = _make_bar_button("DOJO")
	exit_btn.pressed.connect(func() -> void: TrialManager.exit_trial_to_menu())
	btn_row.add_child(exit_btn)

	# Collapsible Hint Box (matches 320px width)
	_hint_box = PanelContainer.new()
	_hint_box.custom_minimum_size = Vector2(320, 0)
	var hstyle: StyleBoxFlat = StyleBoxFlat.new()
	hstyle.bg_color = Color(0.12, 0.14, 0.22, 0.96)
	hstyle.border_color = Color(0.4, 0.8, 1.0, 0.85)
	hstyle.set_border_width_all(1)
	hstyle.set_corner_radius_all(6)
	hstyle.content_margin_left = 10
	hstyle.content_margin_right = 10
	hstyle.content_margin_top = 6
	hstyle.content_margin_bottom = 6
	_hint_box.add_theme_stylebox_override("panel", hstyle)
	_hint_box.visible = false
	outer_vbox.add_child(_hint_box)

	_hint_lbl = RichTextLabel.new()
	_hint_lbl.bbcode_enabled = true
	_hint_lbl.fit_content = true
	_hint_lbl.scroll_active = false
	_hint_lbl.add_theme_font_size_override("normal_font_size", 12)
	_hint_box.add_child(_hint_lbl)


func _make_bar_button(text_val: String) -> Button:
	var b: Button = Button.new()
	b.text = text_val
	b.custom_minimum_size = Vector2(64, 22)
	b.add_theme_font_size_override("font_size", 11)
	return b


func _build_modal() -> void:
	# Dedicated high CanvasLayer ONLY for Briefing / Result popups
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 110
	_modal_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_modal_layer)

	_modal_backdrop = ColorRect.new()
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	_modal_backdrop.visible = false
	_modal_layer.add_child(_modal_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.add_child(center)

	_modal_panel = PanelContainer.new()
	_modal_panel.custom_minimum_size = Vector2(640, 320)
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	pstyle.border_color = Color(0.95, 0.78, 0.25)
	pstyle.set_border_width_all(3)
	pstyle.set_corner_radius_all(12)
	pstyle.content_margin_left = 28
	pstyle.content_margin_right = 28
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	_modal_panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(_modal_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_modal_panel.add_child(vbox)

	_modal_title = Label.new()
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_modal_title)

	_modal_badge = Label.new()
	_modal_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_badge.add_theme_font_size_override("font_size", 17)
	vbox.add_child(_modal_badge)

	_modal_body = RichTextLabel.new()
	_modal_body.bbcode_enabled = true
	_modal_body.fit_content = true
	_modal_body.scroll_active = false
	_modal_body.add_theme_font_size_override("normal_font_size", 17)
	vbox.add_child(_modal_body)

	_modal_hint_lbl = RichTextLabel.new()
	_modal_hint_lbl.bbcode_enabled = true
	_modal_hint_lbl.fit_content = true
	_modal_hint_lbl.scroll_active = false
	_modal_hint_lbl.visible = false
	_modal_hint_lbl.add_theme_font_size_override("normal_font_size", 15)
	vbox.add_child(_modal_hint_lbl)

	_modal_buttons = HBoxContainer.new()
	_modal_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(_modal_buttons)


func refresh_banner() -> void:
	var t: TrialData = TrialManager.active_trial
	if t == null:
		return

	_title_lbl.text = t.title + " [" + t.focus_trait + "]"
	var shown_turn: int = mini(TrialManager.current_turn + 1, t.turn_limit)
	_turn_lbl.text = "CLASH %d/%d" % [shown_turn, t.turn_limit]
	_objective_lbl.text = "Objective: " + t.objective_short
	_hint_lbl.text = "[color=#7fd8ff][b]Sensei's Hint:[/b][/color] " + t.hint_text

	var intent: Dictionary = TrialManager.get_upcoming_bot_card_info()
	if intent.is_empty():
		_intent_lbl.text = ""
	elif bool(intent.get("hidden", false)):
		_intent_lbl.text = "[color=#c5c5d8][b]Sensei's Next Move:[/b] Hidden — click [b]Inspect[/b] on Sensei to read their SP and hand![/color]"
	else:
		var card_name: String = str(intent.get("name", ""))
		var card_desc: String = str(intent.get("description", ""))
		_intent_lbl.text = "[color=#ff9e80][b]Sensei's Next Move:[/b] %s[/color] [color=#d8d8e5](%s)[/color]" % [card_name, card_desc]


func show_briefing() -> void:
	var t: TrialData = TrialManager.active_trial
	if t == null:
		briefing_dismissed.emit()
		return

	_clear_modal_buttons()
	_modal_hint_lbl.visible = false
	_modal_title.text = t.title.to_upper()
	_modal_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_modal_badge.text = t.focus_trait + "  •  " + ("★".repeat(clampi(t.difficulty, 1, 3)))
	_modal_badge.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))

	var body_text: String = "[center]%s\n\n[color=#ffd966][b]Objective:[/b][/color] %s[/center]" % [
		t.briefing_text, t.objective_short
	]
	_modal_body.text = body_text

	var start_btn: Button = _make_modal_button("BEGIN TRIAL", Color(0.2, 0.65, 0.35))
	start_btn.pressed.connect(func() -> void:
		_modal_backdrop.visible = false
		get_tree().paused = false
		briefing_dismissed.emit()
	)
	_modal_buttons.add_child(start_btn)

	_modal_backdrop.visible = true
	get_tree().paused = true


func show_result(outcome: Dictionary) -> void:
	var t: TrialData = TrialManager.active_trial
	if t == null:
		return

	_clear_modal_buttons()
	_modal_hint_lbl.visible = false
	var status: String = str(outcome.get("status", "FAILED"))
	var reason: String = str(outcome.get("reason", ""))
	var tokens_earned: int = int(outcome.get("tokens_earned", 0))

	if status == "CLEARED":
		_modal_title.text = "WELL DONE!"
		_modal_title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))

		if tokens_earned > 0:
			_modal_badge.text = "TRIAL CLEARED  •  +%d CIRCUIT TOKENS EARNED!" % tokens_earned
			_modal_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		else:
			_modal_badge.text = "TRIAL CLEARED  •  " + t.focus_trait
			_modal_badge.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))

		_modal_body.text = "[center][color=#7fd8ff][b]Key Interaction Takeaway:[/b][/color]\n%s[/center]" % reason

		var next_trial: TrialData = TrialManager.get_next_trial(t.id)
		if next_trial != null:
			var next_btn: Button = _make_modal_button("NEXT TRIAL: " + next_trial.title, Color(0.2, 0.65, 0.35))
			next_btn.pressed.connect(func() -> void: TrialManager.start_next_trial())
			_modal_buttons.add_child(next_btn)

		var retry_btn: Button = _make_modal_button("REPLAY", Color(0.25, 0.35, 0.5))
		retry_btn.pressed.connect(func() -> void: TrialManager.retry_trial())
		_modal_buttons.add_child(retry_btn)

		var back_btn: Button = _make_modal_button("BACK TO DOJO", Color(0.3, 0.3, 0.38))
		back_btn.pressed.connect(func() -> void: TrialManager.exit_trial_to_menu())
		_modal_buttons.add_child(back_btn)
	else:
		_modal_title.text = "TRIAL FAILED"
		_modal_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
		_modal_badge.text = t.title + "  •  " + t.focus_trait
		_modal_badge.add_theme_color_override("font_color", Color(0.85, 0.75, 0.75))
		_modal_body.text = "[center]%s[/center]" % reason

		var retry_btn: Button = _make_modal_button("INSTANT RETRY", Color(0.2, 0.58, 0.85))
		retry_btn.pressed.connect(func() -> void: TrialManager.retry_trial())
		_modal_buttons.add_child(retry_btn)

		var show_hint_btn: Button = _make_modal_button("SHOW HINT", Color(0.65, 0.5, 0.18))
		show_hint_btn.pressed.connect(func() -> void:
			_modal_hint_lbl.text = "[center][color=#7fd8ff][b]Hint:[/b][/color] %s[/center]" % t.hint_text
			_modal_hint_lbl.visible = true
			show_hint_btn.disabled = true
		)
		_modal_buttons.add_child(show_hint_btn)

		var back_btn: Button = _make_modal_button("BACK TO DOJO", Color(0.3, 0.3, 0.38))
		back_btn.pressed.connect(func() -> void: TrialManager.exit_trial_to_menu())
		_modal_buttons.add_child(back_btn)

	_modal_backdrop.visible = true
	get_tree().paused = true


func _on_toggle_collapse() -> void:
	_collapsed = not _collapsed
	_top_panel.visible = not _collapsed
	_mini_pill.visible = _collapsed
	if _collapsed:
		_hint_visible = false
		_hint_box.visible = false


func toggle_hint() -> void:
	_on_toggle_hint()


func _on_toggle_hint() -> void:
	_hint_visible = not _hint_visible
	_hint_box.visible = _hint_visible


func _clear_modal_buttons() -> void:
	for child: Node in _modal_buttons.get_children():
		child.queue_free()


func _make_modal_button(label_text: String, tint: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(150, 44)
	btn.add_theme_font_size_override("font_size", 16)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover_style.bg_color = tint.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	return btn
