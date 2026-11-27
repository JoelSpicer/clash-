extends Control

const CustomFighterStoreScript = preload("res://Scripts/Meta/CustomFighterStore.gd")
const CARD_DISPLAY_SCENE: PackedScene = preload("res://Scenes/CardDisplay.tscn")

const CLASS_ORDER: Array[CharacterData.ClassType] = [
	CharacterData.ClassType.HEAVY,
	CharacterData.ClassType.PATIENT,
	CharacterData.ClassType.QUICK,
	CharacterData.ClassType.TECHNICAL,
]

var _saved_fighters: Array[Dictionary] = []
var _editing_id: String = ""
var _selected_class: CharacterData.ClassType = CharacterData.ClassType.HEAVY
var _selected_tier: String = "veteran"
var _bonus_hp: int = 2
var _bonus_sp: int = 3
var _is_sandbox: bool = false
var _selected_cards: Array[String] = []
var _card_filter: int = 0 # 0=All, 1=Offence, 2=Defence

var _saved_list_vbox: VBoxContainer
var _name_input: LineEdit
var _class_option: OptionButton
var _tier_option: OptionButton
var _sandbox_toggle: CheckButton
var _origin_badge: Label
var _portrait_rect: TextureRect
var _passive_lbl: Label
var _points_lbl: Label
var _hp_val_lbl: Label
var _sp_val_lbl: Label
var _hand_count_lbl: Label
var _warning_lbl: Label
var _status_lbl: Label
var _card_grid: GridContainer


func _ready() -> void:
	_build_ui()
	_reload_saved_list()
	if _saved_fighters.is_empty():
		_start_new_fighter()
	else:
		_load_fighter_into_editor(_saved_fighters[0])


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root_vb: VBoxContainer = VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	margin.add_child(root_vb)

	# --- TOP BAR ---
	var top_hb: HBoxContainer = HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 16)
	root_vb.add_child(top_hb)

	var back_btn: Button = Button.new()
	back_btn.text = "← BACK TO QUICK MATCH"
	back_btn.custom_minimum_size = Vector2(220, 42)
	back_btn.pressed.connect(_on_back_pressed)
	top_hb.add_child(back_btn)

	var header: Label = Label.new()
	header.text = "CUSTOM FIGHTER BUILDER (QUICK MATCH & LOCAL 2P)"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	top_hb.add_child(header)

	var save_btn: Button = Button.new()
	save_btn.text = "SAVE FIGHTER"
	save_btn.custom_minimum_size = Vector2(180, 42)
	var save_style: StyleBoxFlat = StyleBoxFlat.new()
	save_style.bg_color = Color(0.16, 0.56, 0.3)
	save_style.set_corner_radius_all(6)
	save_btn.add_theme_stylebox_override("normal", save_style)
	save_btn.pressed.connect(_on_save_pressed)
	top_hb.add_child(save_btn)

	# --- MAIN 3-COLUMN BODY ---
	var body_hb: HBoxContainer = HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 16)
	root_vb.add_child(body_hb)

	# 1. LEFT COLUMN: SAVED ROSTER
	var left_panel: PanelContainer = _make_panel(Color(0.07, 0.09, 0.14, 0.95), Color(0.32, 0.48, 0.72, 0.7))
	left_panel.custom_minimum_size = Vector2(270, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_child(left_panel)

	var left_vb: VBoxContainer = VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vb)

	var roster_hdr: Label = Label.new()
	roster_hdr.text = "YOUR CUSTOM ROSTER"
	roster_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_hdr.add_theme_font_size_override("font_size", 16)
	roster_hdr.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	left_vb.add_child(roster_hdr)

	var new_btn: Button = Button.new()
	new_btn.text = "+ NEW FIGHTER"
	new_btn.custom_minimum_size = Vector2(0, 38)
	new_btn.pressed.connect(_start_new_fighter)
	left_vb.add_child(new_btn)

	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vb.add_child(list_scroll)

	_saved_list_vbox = VBoxContainer.new()
	_saved_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saved_list_vbox.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_saved_list_vbox)

	var left_actions: HBoxContainer = HBoxContainer.new()
	left_actions.add_theme_constant_override("separation", 6)
	left_vb.add_child(left_actions)

	var dup_btn: Button = Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.pressed.connect(_on_duplicate_pressed)
	left_actions.add_child(dup_btn)

	var del_btn: Button = Button.new()
	del_btn.text = "Delete"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.modulate = Color(1.0, 0.65, 0.65)
	del_btn.pressed.connect(_on_delete_pressed)
	left_actions.add_child(del_btn)

	# 2. CENTER COLUMN: IDENTITY, POINT-BUY STATS & SANDBOX
	var mid_panel: PanelContainer = _make_panel(Color(0.08, 0.1, 0.15, 0.95), Color(0.92, 0.78, 0.3, 0.75))
	mid_panel.custom_minimum_size = Vector2(360, 0)
	mid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_child(mid_panel)

	var mid_vb: VBoxContainer = VBoxContainer.new()
	mid_vb.add_theme_constant_override("separation", 10)
	mid_panel.add_child(mid_vb)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(140, 140)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mid_vb.add_child(_portrait_rect)

	_origin_badge = Label.new()
	_origin_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_origin_badge.add_theme_font_size_override("font_size", 14)
	mid_vb.add_child(_origin_badge)

	var name_lbl: Label = Label.new()
	name_lbl.text = "FIGHTER NAME"
	name_lbl.add_theme_font_size_override("font_size", 13)
	mid_vb.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter Fighter Name..."
	_name_input.max_length = 28
	mid_vb.add_child(_name_input)

	var cls_lbl: Label = Label.new()
	cls_lbl.text = "CLASS & PASSIVE"
	cls_lbl.add_theme_font_size_override("font_size", 13)
	mid_vb.add_child(cls_lbl)

	_class_option = OptionButton.new()
	for ct: CharacterData.ClassType in CLASS_ORDER:
		_class_option.add_item(ClassFactory.class_enum_to_string(ct))
	_class_option.item_selected.connect(_on_class_changed)
	mid_vb.add_child(_class_option)

	_passive_lbl = Label.new()
	_passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passive_lbl.add_theme_font_size_override("font_size", 12)
	_passive_lbl.add_theme_color_override("font_color", Color(0.75, 0.86, 0.96))
	mid_vb.add_child(_passive_lbl)

	var tier_lbl: Label = Label.new()
	tier_lbl.text = "POINT-BUY TIER"
	tier_lbl.add_theme_font_size_override("font_size", 13)
	mid_vb.add_child(tier_lbl)

	_tier_option = OptionButton.new()
	for tier: Dictionary in CustomFighterStoreScript.POINT_BUY_TIERS:
		_tier_option.add_item(str(tier["label"]))
	_tier_option.item_selected.connect(_on_tier_changed)
	mid_vb.add_child(_tier_option)

	_points_lbl = Label.new()
	_points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_lbl.add_theme_font_size_override("font_size", 14)
	_points_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	mid_vb.add_child(_points_lbl)

	# HP / SP Allocator Rows
	var hp_row: HBoxContainer = _make_stat_row("MAX HP", func() -> void: _adjust_stat("hp", -1), func() -> void: _adjust_stat("hp", 1))
	_hp_val_lbl = hp_row.get_meta("val_lbl") as Label
	mid_vb.add_child(hp_row)

	var sp_row: HBoxContainer = _make_stat_row("MAX SP", func() -> void: _adjust_stat("sp", -1), func() -> void: _adjust_stat("sp", 1))
	_sp_val_lbl = sp_row.get_meta("val_lbl") as Label
	mid_vb.add_child(sp_row)

	_sandbox_toggle = CheckButton.new()
	_sandbox_toggle.text = "Sandbox Mode (All Class Actions)"
	_sandbox_toggle.toggled.connect(_on_sandbox_toggled)
	mid_vb.add_child(_sandbox_toggle)

	var sep: HSeparator = HSeparator.new()
	mid_vb.add_child(sep)

	_hand_count_lbl = Label.new()
	_hand_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand_count_lbl.add_theme_font_size_override("font_size", 17)
	mid_vb.add_child(_hand_count_lbl)

	_warning_lbl = Label.new()
	_warning_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_lbl.add_theme_font_size_override("font_size", 12)
	_warning_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3))
	mid_vb.add_child(_warning_lbl)

	var autofill_btn: Button = Button.new()
	autofill_btn.text = "Auto-Fill Balanced 8-Card Hand"
	autofill_btn.pressed.connect(_on_autofill_pressed)
	mid_vb.add_child(autofill_btn)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
	mid_vb.add_child(_status_lbl)

	# 3. RIGHT COLUMN: CARD POOL GRID
	var right_panel: PanelContainer = _make_panel(Color(0.07, 0.09, 0.14, 0.95), Color(0.32, 0.48, 0.72, 0.7))
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_child(right_panel)

	var right_vb: VBoxContainer = VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vb)

	var filter_hb: HBoxContainer = HBoxContainer.new()
	filter_hb.add_theme_constant_override("separation", 10)
	right_vb.add_child(filter_hb)

	var pool_lbl: Label = Label.new()
	pool_lbl.text = "CLICK ACTIONS TO EQUIP (MAX 8)"
	pool_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_lbl.add_theme_font_size_override("font_size", 15)
	pool_lbl.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	filter_hb.add_child(pool_lbl)

	for pair: Array in [["ALL", 0], ["OFFENCE", 1], ["DEFENCE", 2]]:
		var fbtn: Button = Button.new()
		fbtn.text = str(pair[0])
		fbtn.custom_minimum_size = Vector2(90, 32)
		var fidx: int = int(pair[1])
		fbtn.pressed.connect(func() -> void:
			_card_filter = fidx
			_refresh_card_pool()
		)
		filter_hb.add_child(fbtn)

	var card_scroll: ScrollContainer = ScrollContainer.new()
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vb.add_child(card_scroll)

	_card_grid = GridContainer.new()
	_card_grid.columns = 5
	_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_grid.add_theme_constant_override("h_separation", 10)
	_card_grid.add_theme_constant_override("v_separation", 10)
	card_scroll.add_child(_card_grid)


func _reload_saved_list() -> void:
	_saved_fighters = CustomFighterStoreScript.list_fighters()
	for c: Node in _saved_list_vbox.get_children():
		c.queue_free()

	if _saved_fighters.is_empty():
		var empty: Label = Label.new()
		empty.text = "No custom fighters saved yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
		_saved_list_vbox.add_child(empty)
		return

	for fdata: Dictionary in _saved_fighters:
		var btn: Button = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 48)
		var tag: String = "Sandbox" if bool(fdata.get("is_sandbox", false)) else "Class"
		var pts: int = CustomFighterStoreScript.get_tier_points(str(fdata.get("point_tier", "veteran")))
		btn.text = "%s\n[%s · %dpt]" % [str(fdata.get("name", "Fighter")), tag, pts]
		var copy_d: Dictionary = fdata
		btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			_load_fighter_into_editor(copy_d)
		)
		_saved_list_vbox.add_child(btn)


func _start_new_fighter() -> void:
	_editing_id = ""
	_name_input.text = "New Fighter"
	_selected_class = CharacterData.ClassType.HEAVY
	_class_option.selected = 0
	_selected_tier = "veteran"
	_tier_option.selected = 1
	_bonus_hp = 3
	_bonus_sp = 2
	_is_sandbox = false
	_sandbox_toggle.set_pressed_no_signal(false)
	_selected_cards.clear()
	_on_autofill_pressed()
	_status_lbl.text = ""
	_refresh_editor_visuals()


func _load_fighter_into_editor(data: Dictionary) -> void:
	_editing_id = str(data.get("id", ""))
	_name_input.text = str(data.get("name", "Custom Fighter"))
	_selected_class = int(data.get("class_type", int(CharacterData.ClassType.HEAVY))) as CharacterData.ClassType
	var cls_idx: int = CLASS_ORDER.find(_selected_class)
	_class_option.selected = maxi(0, cls_idx)

	_selected_tier = str(data.get("point_tier", "veteran"))
	var tier_idx: int = 1
	for i: int in range(CustomFighterStoreScript.POINT_BUY_TIERS.size()):
		if str(CustomFighterStoreScript.POINT_BUY_TIERS[i]["id"]) == _selected_tier:
			tier_idx = i
			break
	_tier_option.selected = tier_idx

	_bonus_hp = int(data.get("bonus_hp", 0))
	_bonus_sp = int(data.get("bonus_sp", 0))
	_is_sandbox = bool(data.get("is_sandbox", false))
	_sandbox_toggle.set_pressed_no_signal(_is_sandbox)

	_selected_cards.clear()
	for cn: Variant in data.get("deck_cards", []):
		_selected_cards.append(str(cn))

	_status_lbl.text = ""
	_refresh_editor_visuals()


func _on_class_changed(idx: int) -> void:
	if idx < 0 or idx >= CLASS_ORDER.size():
		return
	_selected_class = CLASS_ORDER[idx]
	if not _is_sandbox:
		_prune_illegal_cards()
	_refresh_editor_visuals()


func _on_tier_changed(idx: int) -> void:
	if idx < 0 or idx >= CustomFighterStoreScript.POINT_BUY_TIERS.size():
		return
	_selected_tier = str(CustomFighterStoreScript.POINT_BUY_TIERS[idx]["id"])
	var budget: int = CustomFighterStoreScript.get_tier_points(_selected_tier)
	if _bonus_hp + _bonus_sp > budget:
		_bonus_hp = mini(_bonus_hp, budget)
		_bonus_sp = mini(_bonus_sp, budget - _bonus_hp)
	_refresh_editor_visuals()


func _on_sandbox_toggled(enabled: bool) -> void:
	_is_sandbox = enabled
	if not _is_sandbox:
		_prune_illegal_cards()
	_refresh_editor_visuals()


func _prune_illegal_cards() -> void:
	var pool: Array[ActionData] = CustomFighterStoreScript.get_legal_card_pool(_selected_class, false)
	var allowed: Dictionary = {}
	for c: ActionData in pool:
		allowed[c.display_name] = true
	var kept: Array[String] = []
	for cname: String in _selected_cards:
		if allowed.has(cname):
			kept.append(cname)
	_selected_cards = kept


func _adjust_stat(which: String, delta: int) -> void:
	var budget: int = CustomFighterStoreScript.get_tier_points(_selected_tier)
	var rem: int = budget - (_bonus_hp + _bonus_sp)
	if which == "hp":
		if delta > 0 and rem <= 0:
			AudioManager.play_sfx("error")
			return
		_bonus_hp = maxi(0, _bonus_hp + delta)
	else:
		if delta > 0 and rem <= 0:
			AudioManager.play_sfx("error")
			return
		_bonus_sp = maxi(0, _bonus_sp + delta)
	AudioManager.play_sfx("ui_click")
	_refresh_editor_visuals()


func _on_autofill_pressed() -> void:
	var base: CharacterData = ClassFactory.create_character(_selected_class, "Preview", false)
	if base == null:
		return
	_selected_cards.clear()
	for card: ActionData in base.deck:
		if card != null and _selected_cards.size() < ClassFactory.HAND_LIMIT:
			_selected_cards.append(card.display_name)
	_refresh_editor_visuals()


func _on_save_pressed() -> void:
	if _selected_cards.is_empty():
		AudioManager.play_sfx("error")
		_status_lbl.text = "Pick at least 1 action card before saving!"
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		return

	var fname: String = _name_input.text.strip_edges()
	if fname == "":
		fname = "Custom " + ClassFactory.class_enum_to_string(_selected_class)
		_name_input.text = fname

	var new_id: String = CustomFighterStoreScript.sanitize_id(fname)
	if _editing_id != "" and _editing_id != new_id:
		CustomFighterStoreScript.delete_fighter(_editing_id)

	var payload: Dictionary = {
		"id": new_id,
		"name": fname,
		"class_type": int(_selected_class),
		"point_tier": _selected_tier,
		"bonus_hp": _bonus_hp,
		"bonus_sp": _bonus_sp,
		"is_sandbox": _is_sandbox,
		"deck_cards": _selected_cards.duplicate(),
	}
	var err: Error = CustomFighterStoreScript.save_fighter(payload)
	if err == OK:
		_editing_id = new_id
		AudioManager.play_sfx("ui_confirm")
		_reload_saved_list()
		RunManager.check_achievements(_saved_fighters.size())
		_status_lbl.text = "Saved '%s' (%s)!" % [fname, CustomFighterStoreScript.get_origin_tag(_is_sandbox)]
		_status_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
	else:
		AudioManager.play_sfx("error")
		_status_lbl.text = "Error saving fighter."
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))


func _on_duplicate_pressed() -> void:
	_editing_id = ""
	_name_input.text = _name_input.text.strip_edges() + " II"
	_status_lbl.text = "Duplicated in editor — click SAVE FIGHTER to keep."


func _on_delete_pressed() -> void:
	if _editing_id == "":
		return
	AudioManager.play_sfx("ui_back")
	CustomFighterStoreScript.delete_fighter(_editing_id)
	_reload_saved_list()
	if _saved_fighters.is_empty():
		_start_new_fighter()
	else:
		_load_fighter_into_editor(_saved_fighters[0])


func _on_back_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	RunManager.return_to_carousel_slide = 1 # Quick Match slide
	SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")


func _refresh_editor_visuals() -> void:
	var def: ClassDefinition = ClassFactory.class_registry.get(_selected_class) as ClassDefinition
	var base_hp: int = def.base_hp if def != null else 5
	var base_sp: int = def.base_sp if def != null else 4
	if def != null:
		_portrait_rect.texture = def.portrait
		_passive_lbl.text = def.passive_description
	else:
		_portrait_rect.texture = null
		_passive_lbl.text = ""

	_origin_badge.text = "[ %s ]" % CustomFighterStoreScript.get_origin_tag(_is_sandbox).to_upper()
	_origin_badge.add_theme_color_override("font_color", Color(1.0, 0.6, 1.0) if _is_sandbox else Color(0.55, 0.9, 1.0))

	var budget: int = CustomFighterStoreScript.get_tier_points(_selected_tier)
	var rem: int = maxi(0, budget - (_bonus_hp + _bonus_sp))
	_points_lbl.text = "POINT BUY REMAINING: %d / %d" % [rem, budget]
	_hp_val_lbl.text = "%d  (+%d)" % [base_hp + _bonus_hp, _bonus_hp]
	_sp_val_lbl.text = "%d  (+%d)" % [base_sp + _bonus_sp, _bonus_sp]

	_hand_count_lbl.text = "ACTIVE HAND: %d / %d" % [_selected_cards.size(), ClassFactory.HAND_LIMIT]
	_hand_count_lbl.modulate = Color(0.45, 1.0, 0.55) if _selected_cards.size() == ClassFactory.HAND_LIMIT else Color.WHITE

	_update_deck_warnings()
	_refresh_card_pool()


func _update_deck_warnings() -> void:
	var has_opener: bool = false
	var has_def: bool = false
	var max_open: int = 0
	var cards: Array[ActionData] = []
	for cname: String in _selected_cards:
		var a: ActionData = CustomFighterStoreScript._find_action(cname)
		if a != null:
			cards.append(a)
			if a.type == ActionData.Type.OFFENCE and a.is_opener:
				has_opener = true
			if a.type == ActionData.Type.DEFENCE:
				has_def = true
			if a.create_opening > max_open:
				max_open = a.create_opening

	var warns: Array[String] = []
	if not cards.is_empty():
		if not has_opener:
			warns.append("No Opener card")
		if not has_def:
			warns.append("No Defence card")
		for a: ActionData in cards:
			if a.counter_value > 0 and max_open < a.counter_value:
				warns.append("%s needs Opening %d" % [a.display_name, a.counter_value])
	_warning_lbl.text = "⚠ " + " · ".join(warns) if not warns.is_empty() else "✓ Balanced Hand"
	_warning_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3) if not warns.is_empty() else Color(0.45, 0.95, 0.6))


func _refresh_card_pool() -> void:
	for c: Node in _card_grid.get_children():
		c.queue_free()

	var pool: Array[ActionData] = CustomFighterStoreScript.get_legal_card_pool(_selected_class, _is_sandbox)
	for action: ActionData in pool:
		if _card_filter == 1 and action.type != ActionData.Type.OFFENCE:
			continue
		if _card_filter == 2 and action.type != ActionData.Type.DEFENCE:
			continue

		var wrapper: Button = Button.new()
		wrapper.custom_minimum_size = Vector2(165, 225)
		wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		wrapper.flat = true

		var disp: Control = CARD_DISPLAY_SCENE.instantiate() as Control
		wrapper.add_child(disp)
		disp.call("set_card_data", action)
		disp.scale = Vector2(0.7, 0.7)
		disp.position = Vector2(4, 6)
		disp.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var equipped: bool = action.display_name in _selected_cards
		disp.modulate = Color.WHITE if equipped else Color(0.55, 0.55, 0.6, 0.85)
		if equipped:
			var badge: Label = Label.new()
			badge.text = "EQUIPPED"
			badge.position = Vector2(36, 0)
			badge.z_index = 10
			badge.add_theme_font_size_override("font_size", 13)
			badge.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
			badge.add_theme_color_override("font_outline_color", Color.BLACK)
			badge.add_theme_constant_override("outline_size", 4)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrapper.add_child(badge)

		var card_name: String = action.display_name
		wrapper.pressed.connect(func() -> void: _toggle_card(card_name))
		_card_grid.add_child(wrapper)


func _toggle_card(card_name: String) -> void:
	if card_name in _selected_cards:
		_selected_cards.erase(card_name)
		AudioManager.play_sfx("ui_back")
	else:
		if _selected_cards.size() >= ClassFactory.HAND_LIMIT:
			AudioManager.play_sfx("error")
			return
		_selected_cards.append(card_name)
		AudioManager.play_sfx("ui_click")
	_refresh_editor_visuals()


func _make_stat_row(label_text: String, on_minus: Callable, on_plus: Callable) -> HBoxContainer:
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lbl)

	var minus_btn: Button = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(36, 32)
	minus_btn.pressed.connect(on_minus)
	hb.add_child(minus_btn)

	var val_lbl: Label = Label.new()
	val_lbl.custom_minimum_size = Vector2(88, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(val_lbl)

	var plus_btn: Button = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(36, 32)
	plus_btn.pressed.connect(on_plus)
	hb.add_child(plus_btn)

	hb.set_meta("val_lbl", val_lbl)
	return hb


func _make_panel(bg: Color, border: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	return p
