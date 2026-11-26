extends Node
class_name BattleTooltipController

var preview_card: Control
var tooltip_panel: PanelContainer
var tooltip_label: RichTextLabel
var equipment_grid: HBoxContainer
var preview_base_pos: Vector2 = Vector2.ZERO

var _tooltip_tween: Tween
var _preview_tween: Tween


func setup(
	p_preview_card: Control,
	p_tooltip_panel: PanelContainer,
	p_tooltip_label: RichTextLabel,
	p_equipment_grid: HBoxContainer,
	p_preview_base_pos: Vector2
) -> void:
	preview_card = p_preview_card
	tooltip_panel = p_tooltip_panel
	tooltip_label = p_tooltip_label
	equipment_grid = p_equipment_grid
	preview_base_pos = p_preview_base_pos

	if preview_card:
		preview_card.visible = false
	if tooltip_label:
		tooltip_label.visible = false
	if tooltip_panel:
		tooltip_panel.visible = false


func show_card_preview(card: ActionData, effective_cost: int) -> void:
	if not preview_card or card == null:
		return
	preview_card.call("set_card_data", card, effective_cost)

	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()

	preview_card.visible = true
	preview_card.modulate.a = 0.0
	preview_card.position.y = preview_base_pos.y + 20.0

	_preview_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_preview_tween.tween_property(preview_card, "modulate:a", 1.0, 0.15)
	_preview_tween.tween_property(preview_card, "position:y", preview_base_pos.y, 0.2)

	_update_keyword_tooltip(card)


func hide_all() -> void:
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	if preview_card:
		preview_card.visible = false

	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	if tooltip_panel:
		tooltip_panel.visible = false


func populate_equipment(p1_data: CharacterData) -> void:
	if not equipment_grid or p1_data == null:
		return
	for child: Node in equipment_grid.get_children():
		child.queue_free()

	for item: EquipmentData in p1_data.equipment:
		if item == null:
			continue
		var icon: TextureRect = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon if item.icon else preload("res://icon.svg")

		var tip: String = _build_equipment_tooltip_text(item)
		icon.mouse_entered.connect(func() -> void: show_equipment_tooltip(tip, icon))
		icon.mouse_exited.connect(hide_all)
		equipment_grid.add_child(icon)


func show_equipment_tooltip(text: String, icon_node: Control) -> void:
	if not tooltip_panel or not tooltip_label:
		return
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()

	tooltip_label.text = text
	tooltip_label.visible = true
	var target_size: Vector2 = tooltip_panel.get_minimum_size()
	tooltip_panel.size = target_size

	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0.0

	var icon_bottom: float = icon_node.global_position.y + icon_node.size.y
	var final_y: float = icon_bottom + 15.0
	var start_y: float = final_y - 15.0

	tooltip_panel.global_position = Vector2(icon_node.global_position.x, start_y)

	_tooltip_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tooltip_tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.15)
	_tooltip_tween.tween_property(tooltip_panel, "global_position:y", final_y, 0.2)


func _update_keyword_tooltip(card: ActionData) -> void:
	if not tooltip_label or not tooltip_panel:
		return

	var active_keys: Array[String] = []
	if card.type == ActionData.Type.OFFENCE: active_keys.append("Offence")
	if card.type == ActionData.Type.DEFENCE: active_keys.append("Defence")
	if card.cost > 0: active_keys.append("Cost")
	if card.damage > 0: active_keys.append("Damage")
	if card.momentum_gain > 0: active_keys.append("Momentum")
	if card.block_value > 0: active_keys.append("Block")
	if card.dodge_value > 0: active_keys.append("Dodge")
	if card.heal_value > 0: active_keys.append("Heal")
	if card.recover_value > 0: active_keys.append("Recover")
	if card.fall_back_value > 0: active_keys.append("Fall Back")
	if card.counter_value > 0: active_keys.append("Counter")
	if card.tiring > 0: active_keys.append("Tiring")
	if card.is_opener: active_keys.append("Opener")
	if card.is_super: active_keys.append("Super")
	if card.guard_break: active_keys.append("Guard Break")
	if card.feint: active_keys.append("Feint")

	for s: Dictionary in card.statuses_to_apply:
		var s_name: String = str(s.get("name", ""))
		if s_name != "":
			active_keys.append(s_name)

	if card.retaliate: active_keys.append("Retaliate")
	if card.reversal: active_keys.append("Reversal")
	if card.is_parry: active_keys.append("Parry")
	if card.sweep: active_keys.append("Sweep")
	if card.multi_limit > 0: active_keys.append("Multi")
	if card.repeat_count > 1: active_keys.append("Repeat")
	if card.create_opening > 0: active_keys.append("Create Opening")
	if card.opportunity > 0: active_keys.append("Opportunity")

	if active_keys.is_empty():
		tooltip_panel.visible = false
		return

	var full_text: String = ""
	for k: String in active_keys:
		if k in GameManager.KEYWORD_DEFS:
			full_text += "[color=#ffcc00][b]" + k + ":[/b][/color] " + str(GameManager.KEYWORD_DEFS[k]) + "\n"

	tooltip_label.text = full_text.strip_edges()
	tooltip_label.visible = true

	var target_size: Vector2 = tooltip_panel.get_minimum_size()
	tooltip_panel.size = target_size

	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()

	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0.0

	var padding: float = 20.0
	var preview_bottom: float = preview_base_pos.y + preview_card.size.y
	var final_y: float = preview_bottom - target_size.y - padding
	var start_y: float = final_y + 15.0

	tooltip_panel.position.x = preview_card.position.x - target_size.x - padding
	tooltip_panel.position.y = start_y

	_tooltip_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tooltip_tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.15)
	_tooltip_tween.tween_property(tooltip_panel, "position:y", final_y, 0.2)


func _build_equipment_tooltip_text(item: EquipmentData) -> String:
	var lines: Array[String] = [item.item_name]
	if item.description != "":
		lines.append(item.description)

	var stat_lines: Array[String] = []
	if item.bonus_max_hp != 0:
		stat_lines.append("Max HP: %s%d" % ["+" if item.bonus_max_hp > 0 else "", item.bonus_max_hp])
	if item.bonus_max_sp != 0:
		stat_lines.append("Max SP: %s%d" % ["+" if item.bonus_max_sp > 0 else "", item.bonus_max_sp])
	if item.bonus_speed != 0:
		stat_lines.append("Speed: %s%d" % ["+" if item.bonus_speed > 0 else "", item.bonus_speed])
	if item.starting_barrier != 0:
		stat_lines.append("Starting Barrier: +%d" % item.starting_barrier)
	if item.starting_sp_bonus != 0:
		stat_lines.append("Starting SP: %s%d" % ["+" if item.starting_sp_bonus > 0 else "", item.starting_sp_bonus])
	if item.starting_opportunity != 0:
		stat_lines.append("Starting Opportunity: +%d" % item.starting_opportunity)
	if item.damage_modifier != 0:
		stat_lines.append("Damage: %s%d" % ["+" if item.damage_modifier > 0 else "", item.damage_modifier])
	if item.block_modifier != 0:
		stat_lines.append("Block: %s%d" % ["+" if item.block_modifier > 0 else "", item.block_modifier])
	if item.thorns != 0:
		stat_lines.append("Thorns: +%d" % item.thorns)
	if item.momentum_start_bonus != 0:
		stat_lines.append("Starting Momentum: +%d" % item.momentum_start_bonus)
	if item.wall_crush_damage_bonus != 0:
		stat_lines.append("Wall Crush Dmg: +%d" % item.wall_crush_damage_bonus)
	if item.combo_sp_regen_bonus != 0:
		stat_lines.append("Combo SP Regen: +%d" % item.combo_sp_regen_bonus)
	if item.heal_on_win != 0:
		stat_lines.append("Heal on Win: +%d" % item.heal_on_win)
	if item.extra_draft_options != 0:
		stat_lines.append("Reward Options: +%d" % item.extra_draft_options)
	if item.reveal_enemy_opener:
		stat_lines.append("Scouts Enemy Opener")
	if item.disable_supers:
		stat_lines.append("Supers Disabled")

	if not stat_lines.is_empty():
		lines.append("-------------------")
		lines.append_array(stat_lines)

	return "\n".join(lines)
