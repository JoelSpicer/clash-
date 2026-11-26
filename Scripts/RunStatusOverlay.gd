extends CanvasLayer

@onready var panel: Control = $StatusPanel
@onready var btn_toggle: Button = $ToggleBtn
@onready var hp_label: Label = $StatusPanel/VBoxContainer/HpLabel
@onready var sp_label: Label = $StatusPanel/VBoxContainer/SpLabel
@onready var eq_grid: Control = $StatusPanel/VBoxContainer/EquipmentGrid
@onready var status_vbox: VBoxContainer = $StatusPanel/VBoxContainer

var _extra_info_label: Label = null


func _ready() -> void:
	panel.visible = false
	btn_toggle.pressed.connect(_on_toggle)
	btn_toggle.mouse_entered.connect(func() -> void: AudioManager.play_sfx("ui_hover", 0.2))
	btn_toggle.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))


func _on_toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		btn_toggle.text = "Hide Run Status"
		_refresh_display()
	else:
		btn_toggle.text = "View Run Status"


func _refresh_display() -> void:
	var p1: CharacterData = RunManager.player_run_data
	if not p1:
		return

	var barrier_bonus: int = 0
	var starting_sp_bonus: int = 0
	for item: EquipmentData in p1.equipment:
		if item == null:
			continue
		starting_sp_bonus += item.starting_sp_bonus
		barrier_bonus += item.starting_barrier

	if RunManager.active_sponsor != null:
		starting_sp_bonus += RunManager.active_sponsor.starting_sp_bonus
		barrier_bonus += RunManager.active_sponsor.starting_barrier

	var next_fight_hp: int = p1.current_hp + barrier_bonus
	var next_fight_sp: int = maxi(0, p1.max_sp + starting_sp_bonus)

	var barrier_note: String = " (+%d Barrier)" % barrier_bonus if barrier_bonus > 0 else ""
	hp_label.text = "NEXT FIGHT HP: %d / %d%s" % [next_fight_hp, p1.max_hp, barrier_note]
	sp_label.text = "NEXT FIGHT SP: %d / %d" % [next_fight_sp, p1.max_sp]

	# Sponsor, Gym Buff, Statuses, and Rerolls summary
	if _extra_info_label == null:
		_extra_info_label = Label.new()
		_extra_info_label.name = "RunDetailsLabel"
		_extra_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_extra_info_label.add_theme_font_size_override("font_size", 14)
		status_vbox.add_child(_extra_info_label)
		status_vbox.move_child(_extra_info_label, status_vbox.get_child_count() - 2)

	var detail_lines: Array[String] = []
	if RunManager.active_sponsor != null:
		detail_lines.append("SPONSOR: %s — %s" % [RunManager.active_sponsor.item_name, RunManager.active_sponsor.description])
	else:
		detail_lines.append("SPONSOR: Independent")

	if RunManager.active_gym_buff != "":
		var buff_desc: String = "Iron Stance (+1 Block next fight)" if RunManager.active_gym_buff == "iron_stance" else (
			"Exploit Weakness (-20% Enemy HP next fight)" if RunManager.active_gym_buff == "exploit_weakness" else RunManager.active_gym_buff
		)
		detail_lines.append("GYM BUFF: " + buff_desc)

	if not RunManager.next_fight_statuses.is_empty():
		detail_lines.append("NEXT FIGHT STATUS: " + ", ".join(RunManager.next_fight_statuses))

	if RunManager.current_rerolls > 0:
		detail_lines.append("REWARD REROLLS: %d" % RunManager.current_rerolls)

	_extra_info_label.text = "\n".join(detail_lines)

	for child: Node in eq_grid.get_children():
		child.queue_free()

	for item: EquipmentData in p1.equipment:
		if item == null:
			continue
		var icon: TextureRect = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon if item.icon else preload("res://icon.svg")
		icon.tooltip_text = _build_item_tooltip(item)
		eq_grid.add_child(icon)


func _build_item_tooltip(item: EquipmentData) -> String:
	var lines: Array[String] = [item.item_name]
	if item.description != "":
		lines.append(item.description)
	var stats: Array[String] = []
	if item.bonus_max_hp != 0: stats.append("Max HP: %s%d" % ["+" if item.bonus_max_hp > 0 else "", item.bonus_max_hp])
	if item.bonus_max_sp != 0: stats.append("Max SP: %s%d" % ["+" if item.bonus_max_sp > 0 else "", item.bonus_max_sp])
	if item.bonus_speed != 0: stats.append("Speed: %s%d" % ["+" if item.bonus_speed > 0 else "", item.bonus_speed])
	if item.starting_barrier != 0: stats.append("Barrier: +%d" % item.starting_barrier)
	if item.starting_sp_bonus != 0: stats.append("Start SP: %s%d" % ["+" if item.starting_sp_bonus > 0 else "", item.starting_sp_bonus])
	if item.damage_modifier != 0: stats.append("Damage: %s%d" % ["+" if item.damage_modifier > 0 else "", item.damage_modifier])
	if item.block_modifier != 0: stats.append("Block: %s%d" % ["+" if item.block_modifier > 0 else "", item.block_modifier])
	if item.thorns != 0: stats.append("Thorns: +%d" % item.thorns)
	if item.momentum_start_bonus != 0: stats.append("Start Momentum: +%d" % item.momentum_start_bonus)
	if item.wall_crush_damage_bonus != 0: stats.append("Wall Crush Dmg: +%d" % item.wall_crush_damage_bonus)
	if item.combo_sp_regen_bonus != 0: stats.append("Combo SP Regen: +%d" % item.combo_sp_regen_bonus)
	if item.heal_on_win != 0: stats.append("Heal on Win: +%d" % item.heal_on_win)
	if not stats.is_empty():
		lines.append("-------------------")
		lines.append_array(stats)
	return "\n".join(lines)
