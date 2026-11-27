extends Control

@onready var card_grid: GridContainer = $ScrollContainer/CardGrid
@onready var count_label: Label = $CountLabel
@onready var fight_btn: Button = $FightBtn

const CARD_DISPLAY_SCENE: PackedScene = preload("res://Scenes/CardDisplay.tscn")
const OVERLAY_SCENE: PackedScene = preload("res://Scenes/RunStatusOverlay.tscn")


func _ready() -> void:
	AudioManager.play_music("menu_theme")
	var overlay: Node = OVERLAY_SCENE.instantiate()
	add_child(overlay)

	fight_btn.pressed.connect(_on_fight_pressed)
	fight_btn.text = "CONTINUE"
	_refresh_grid()


func _refresh_grid() -> void:
	for c: Node in card_grid.get_children():
		c.queue_free()

	if RunManager.player_run_data == null:
		return
	var deck: Array[ActionData] = RunManager.player_run_data.deck
	var unlocked: Array[ActionData] = RunManager.player_run_data.unlocked_actions

	count_label.text = "HAND: " + str(deck.size()) + " / " + str(ClassFactory.HAND_LIMIT)
	count_label.modulate = Color.GREEN if deck.size() == ClassFactory.HAND_LIMIT else Color.WHITE
	_update_deck_warnings(deck)

	for action: ActionData in unlocked:
		var wrapper: Control = Control.new()
		wrapper.custom_minimum_size = Vector2(180, 240)
		wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var disp: Control = CARD_DISPLAY_SCENE.instantiate() as Control
		wrapper.add_child(disp)
		disp.call("set_card_data", action)
		disp.scale = Vector2(0.75, 0.75)
		disp.position = Vector2(10, 10)
		disp.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if RunManager.player_run_data.has_card_in_deck(action.display_name):
			disp.modulate = Color(1, 1, 1, 1)
			_add_equipped_badge(wrapper)
		else:
			disp.modulate = Color(0.5, 0.5, 0.5, 0.8)

		wrapper.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb: InputEventMouseButton = ev as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					_toggle_card(action)
		)

		card_grid.add_child(wrapper)


func _toggle_card(action: ActionData) -> void:
	var player: CharacterData = RunManager.player_run_data
	if player == null:
		return

	if player.has_card_in_deck(action.display_name):
		player.remove_card_from_deck(action.display_name)
		AudioManager.play_sfx("ui_back")
	else:
		if player.deck.size() < ClassFactory.HAND_LIMIT:
			player.deck.append(action)
			AudioManager.play_sfx("ui_click")
		else:
			AudioManager.play_sfx("error")

	_refresh_grid()


func _add_equipped_badge(parent: Control) -> void:
	var lbl: Label = Label.new()
	lbl.text = "EQUIPPED"
	lbl.add_theme_color_override("font_color", Color.GREEN)
	lbl.position = Vector2(30, -5)
	lbl.z_index = 5
	parent.add_child(lbl)


func _on_fight_pressed() -> void:
	if RunManager.player_run_data == null or RunManager.player_run_data.deck.size() < 1:
		return
	fight_btn.disabled = true
	AudioManager.play_sfx("ui_confirm")
	RunManager.exit_deck_editor()


func _update_deck_warnings(deck: Array[ActionData]) -> void:
	var warn_lbl: Label = get_node_or_null("DeckWarningLabel") as Label
	if warn_lbl == null:
		warn_lbl = Label.new()
		warn_lbl.name = "DeckWarningLabel"
		warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn_lbl.add_theme_font_size_override("font_size", 16)
		warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3))
		warn_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		warn_lbl.add_theme_constant_override("outline_size", 2)
		warn_lbl.anchor_left = 0.2
		warn_lbl.anchor_right = 0.8
		warn_lbl.anchor_top = 0.0
		warn_lbl.anchor_bottom = 0.0
		warn_lbl.offset_top = 64.0
		warn_lbl.offset_bottom = 112.0
		add_child(warn_lbl)

	var warnings: Array[String] = []
	var has_opener: bool = false
	var has_defence: bool = false
	var max_opening: int = 0
	for card: ActionData in deck:
		if card == null:
			continue
		if card.type == ActionData.Type.OFFENCE and card.is_opener:
			has_opener = true
		if card.type == ActionData.Type.DEFENCE:
			has_defence = true
		if card.create_opening > max_opening:
			max_opening = card.create_opening

	if not deck.is_empty():
		if not has_opener:
			warnings.append("No Opener card in hand (hard to start combos)")
		if not has_defence:
			warnings.append("No Defence cards in hand")
		for card: ActionData in deck:
			if card and card.counter_value > 0 and max_opening < card.counter_value:
				warnings.append("%s needs Create Opening %d" % [card.display_name, card.counter_value])

	warn_lbl.visible = not warnings.is_empty()
	warn_lbl.text = "⚠ " + "  |  ".join(warnings) if not warnings.is_empty() else ""
