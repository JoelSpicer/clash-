extends Node
class_name BattleInspectPanel

var inspect_btn: Button
var inspect_popup: Panel
var inspect_grid: GridContainer
var env_button: Button
var env_popup: PanelContainer
var env_title: Label
var env_details: RichTextLabel
var close_env_button: Button
var card_display_scene: PackedScene
var compendium_scene: PackedScene
var overlay_parent: Node
var _active_compendium: Node = null


func setup(
	p_overlay_parent: Node,
	p_inspect_btn: Button,
	p_inspect_popup: Panel,
	p_inspect_grid: GridContainer,
	p_env_button: Button,
	p_env_popup: PanelContainer,
	p_env_title: Label,
	p_env_details: RichTextLabel,
	p_close_env_button: Button,
	p_card_display_scene: PackedScene,
	p_compendium_scene: PackedScene
) -> void:
	overlay_parent = p_overlay_parent
	inspect_btn = p_inspect_btn
	inspect_popup = p_inspect_popup
	inspect_grid = p_inspect_grid
	env_button = p_env_button
	env_popup = p_env_popup
	env_title = p_env_title
	env_details = p_env_details
	close_env_button = p_close_env_button
	card_display_scene = p_card_display_scene
	compendium_scene = p_compendium_scene

	if env_button and env_popup:
		env_button.pressed.connect(toggle_env_popup)
		if close_env_button:
			close_env_button.pressed.connect(func() -> void: env_popup.visible = false)
		if env_details:
			env_details.bbcode_enabled = true
			env_details.fit_content = true
		env_button.text = "LOCATION: " + GameManager.current_environment_name.to_upper()

	if inspect_btn:
		inspect_btn.pressed.connect(toggle_inspect)


func toggle_inspect() -> void:
	if not inspect_popup or not inspect_btn:
		return
	inspect_popup.visible = not inspect_popup.visible
	if inspect_popup.visible:
		inspect_btn.text = "CLOSE INSPECT"
		populate_enemy_deck()
	else:
		inspect_btn.text = "INSPECT OPPONENT"


func toggle_env_popup() -> void:
	if not env_popup:
		return
	env_popup.visible = not env_popup.visible
	if env_popup.visible:
		if env_title:
			env_title.text = "ENVIRONMENT: " + GameManager.current_environment_name.to_upper()
		if env_details:
			env_details.text = "[b]Momentum Tracker:[/b] " + str(GameManager.TOTAL_MOMENTUM_SLOTS) + " Slots\n"


func open_compendium() -> void:
	if not compendium_scene or not overlay_parent:
		return
	if is_instance_valid(_active_compendium):
		return
	_active_compendium = compendium_scene.instantiate()
	_active_compendium.set("is_overlay", true)
	overlay_parent.add_child(_active_compendium)


func populate_enemy_deck() -> void:
	if not inspect_grid:
		return
	for child: Node in inspect_grid.get_children():
		child.queue_free()

	var opponent_data: CharacterData = GameManager.p2_data
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		if not multiplayer.is_server():
			var my_id: int = multiplayer.get_unique_id()
			if my_id == GameManager.p2_network_id:
				opponent_data = GameManager.p1_data
	elif overlay_parent and int(overlay_parent.get("active_input_player")) == 2:
		opponent_data = GameManager.p1_data

	if opponent_data == null:
		return

	_update_inspect_traits_banner(opponent_data)

	for card: ActionData in opponent_data.deck:
		var card_disp: Control = card_display_scene.instantiate() as Control
		inspect_grid.add_child(card_disp)
		card_disp.call("set_card_data", card)
		card_disp.custom_minimum_size = Vector2(180, 250)
		card_disp.scale = Vector2(0.8, 0.8)
		card_disp.mouse_entered.connect(func() -> void: AudioManager.play_sfx("ui_hover", 0.1))


func _update_inspect_traits_banner(opponent_data: CharacterData) -> void:
	if not inspect_popup:
		return
	var scroll: Control = inspect_popup.get_node_or_null("ScrollContainer") as Control
	var banner: PanelContainer = inspect_popup.get_node_or_null("EnemyTraitsBanner") as PanelContainer

	var trait_lines: Array[String] = []
	var has_boss_trait: bool = false
	for eq: EquipmentData in opponent_data.equipment:
		if eq == null:
			continue
		var epithet: Variant = eq.get("boss_epithet")
		if epithet != null and str(epithet) != "":
			has_boss_trait = true
			trait_lines.append("[%s] %s — %s" % [str(epithet), eq.item_name, eq.description])
		else:
			trait_lines.append("%s — %s" % [eq.item_name, eq.description])

	if trait_lines.is_empty():
		if banner:
			banner.visible = false
		if scroll:
			scroll.offset_top = 0.0
		return

	if banner == null:
		banner = PanelContainer.new()
		banner.name = "EnemyTraitsBanner"
		banner.anchor_left = 0.0
		banner.anchor_right = 1.0
		banner.anchor_top = 0.0
		banner.anchor_bottom = 0.0
		banner.offset_left = 12.0
		banner.offset_top = 10.0
		banner.offset_right = -12.0
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.08, 0.08, 0.92)
		style.border_color = Color(0.9, 0.35, 0.25, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8)
		banner.add_theme_stylebox_override("panel", style)
		var lbl: Label = Label.new()
		lbl.name = "TraitsText"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 15)
		banner.add_child(lbl)
		inspect_popup.add_child(banner)

	var text_lbl: Label = banner.get_node("TraitsText") as Label
	var header: String = "BOSS TRAITS:\n" if has_boss_trait else "OPPONENT EQUIPMENT:\n"
	text_lbl.text = header + "\n".join(trait_lines)
	text_lbl.modulate = Color(1.0, 0.85, 0.55) if has_boss_trait else Color(0.75, 0.9, 1.0)
	var banner_height: float = clampf(38.0 + float(trait_lines.size()) * 26.0, 64.0, 140.0)
	banner.offset_bottom = 10.0 + banner_height
	banner.visible = true
	if scroll:
		scroll.offset_top = banner.offset_bottom + 8.0
