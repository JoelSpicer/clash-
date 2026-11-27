extends Control

@onready var container: Container = $RewardContainer
@onready var title_label: Label = $TitleLabel

const CARD_DISPLAY_SCENE: PackedScene = preload("res://Scenes/CardDisplay.tscn")
const OVERLAY_SCENE: PackedScene = preload("res://Scenes/RunStatusOverlay.tscn")


func _ready() -> void:
	AudioManager.play_music("menu_theme")

	var overlay: Node = OVERLAY_SCENE.instantiate()
	add_child(overlay)

	var tokens_earned: int = 1
	if RunManager.is_boss_match:
		tokens_earned += 1
	if RunManager.is_rival_match and RunManager.active_sponsor:
		tokens_earned += RunManager.active_sponsor.rival_reward_currency_bonus

	RunManager.add_circuit_tokens(tokens_earned)
	_generate_rewards()


func _generate_rewards() -> void:
	for c: Node in container.get_children():
		c.queue_free()

	var valid_actions: Array[ActionData] = RunManager.get_valid_action_rewards()
	var all_items: Array[EquipmentData] = RunManager.get_all_equipment()
	var stat_upgrades: Array[Dictionary] = RunManager.get_stat_upgrades()

	var valid_items: Array[EquipmentData] = []
	for item: EquipmentData in all_items:
		if not _player_has_item(item):
			valid_items.append(item)

	var choices: Array = []

	if valid_actions.size() > 0:
		choices.append(valid_actions.pick_random())
	else:
		choices.append(stat_upgrades.pick_random())

	if valid_items.size() > 0 and randf() > 0.5:
		choices.append(_get_weighted_random(valid_items))
	else:
		choices.append(stat_upgrades.pick_random())

	var roll: float = randf()
	if roll < 0.4 and valid_actions.size() > 0:
		choices.append(valid_actions.pick_random())
	elif roll < 0.7 and valid_items.size() > 0:
		choices.append(_get_weighted_random(valid_items))
	else:
		choices.append(stat_upgrades.pick_random())

	var extra_opts: int = 0
	if RunManager.active_sponsor:
		extra_opts += RunManager.active_sponsor.extra_draft_options
	if RunManager.player_run_data:
		for eq: EquipmentData in RunManager.player_run_data.equipment:
			if eq:
				extra_opts += eq.extra_draft_options
	if extra_opts > 0:
		for _i: int in range(extra_opts):
			if valid_actions.size() > 0 and randf() > 0.5:
				choices.append(valid_actions.pick_random())
			else:
				choices.append(stat_upgrades.pick_random())

	if RunManager.is_boss_match:
		if title_label:
			title_label.text = "BOSS VICTORY! CHOOSE YOUR REWARD"
		var has_equipment_choice: bool = false
		for ch: Variant in choices:
			if ch is EquipmentData:
				has_equipment_choice = true
				break
		if not has_equipment_choice and valid_items.size() > 0:
			choices.insert(0, _get_weighted_random(valid_items))
		elif valid_actions.size() > 0:
			choices.append(valid_actions.pick_random())
		else:
			choices.append(stat_upgrades.pick_random())

	if RunManager.is_rival_match and RunManager.active_sponsor:
		if RunManager.active_sponsor.rival_reward_item != null:
			choices.insert(0, RunManager.active_sponsor.rival_reward_item)
		RunManager.is_rival_match = false

	for reward: Variant in choices:
		_create_reward_card(reward)

	if RunManager.current_rerolls > 0:
		var reroll_btn: Button = Button.new()
		reroll_btn.text = "Reroll Options (" + str(RunManager.current_rerolls) + " left)"
		reroll_btn.custom_minimum_size = Vector2(200, 50)
		add_child(reroll_btn)
		reroll_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		reroll_btn.position.y -= 50.0

		reroll_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			RunManager.current_rerolls -= 1
			reroll_btn.queue_free()
			_generate_rewards()
		)


func _create_reward_card(reward: Variant) -> void:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(220, 320)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(btn)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("normal", style)

	if reward is ActionData:
		var disp: Control = CARD_DISPLAY_SCENE.instantiate() as Control
		disp.call("set_card_data", reward as ActionData)
		disp.mouse_filter = Control.MOUSE_FILTER_IGNORE

		btn.add_child(disp)
		disp.set_anchors_preset(Control.PRESET_FULL_RECT)
		disp.offset_left = 5.0
		disp.offset_top = 5.0
		disp.offset_right = -5.0
		disp.offset_bottom = -5.0

	elif reward is EquipmentData:
		var eq: EquipmentData = reward as EquipmentData
		_build_info_card(btn, eq.item_name, eq.description, Color(0.4, 0.6, 1.0), "EQUIPMENT")

	elif reward is Dictionary:
		var dict_reward: Dictionary = reward as Dictionary
		_build_info_card(btn, str(dict_reward.get("text", "")), str(dict_reward.get("desc", "")), Color(1.0, 0.5, 0.5), "UPGRADE")

	btn.pressed.connect(func() -> void: _on_selected(reward))


func _on_selected(reward: Variant) -> void:
	AudioManager.play_sfx("ui_click")
	RunManager.is_boss_match = false
	RunManager.apply_reward(reward)


func _player_has_item(item_data: EquipmentData) -> bool:
	var p: CharacterData = RunManager.player_run_data
	for i: EquipmentData in p.equipment:
		if i and i.item_name == item_data.item_name:
			return true
	return false


func _get_weighted_random(pool: Array) -> Variant:
	if pool.is_empty():
		return null

	var active_synergies: Array[String] = []
	if RunManager.has_method("get_active_synergies"):
		active_synergies = RunManager.get_active_synergies()

	var weighted_pool: Array = []
	for item: Variant in pool:
		var weight: int = 1
		if item is BaseModifierData:
			var mod: BaseModifierData = item as BaseModifierData
			for keyword: String in active_synergies:
				if keyword in mod.synergy_keywords:
					weight += 2

		for _i: int in range(weight):
			weighted_pool.append(item)

	return weighted_pool.pick_random()


func _build_info_card(parent: Control, title: String, desc: String, color: Color, category: String) -> void:
	var t: Label = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.modulate = color
	t.position = Vector2(10, 40)
	t.size = Vector2(200, 60)
	parent.add_child(t)

	var cat: Label = Label.new()
	cat.text = category
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.modulate = Color(0.5, 0.5, 0.5)
	cat.position = Vector2(0, 10)
	cat.size.x = 220.0
	parent.add_child(cat)

	var d: RichTextLabel = RichTextLabel.new()
	d.text = "[center]" + desc + "[/center]"
	d.bbcode_enabled = true
	d.position = Vector2(10, 120)
	d.size = Vector2(200, 150)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
