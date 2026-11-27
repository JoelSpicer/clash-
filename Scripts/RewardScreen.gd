extends Control

@onready var container: Container = $RewardContainer
@onready var title_label: Label = $TitleLabel

const CARD_DISPLAY_SCENE: PackedScene = preload("res://Scenes/CardDisplay.tscn")
const OVERLAY_SCENE: PackedScene = preload("res://Scenes/RunStatusOverlay.tscn")

var _reward_claimed: bool = false
var _reroll_btn: Button = null


func _ready() -> void:
	AudioManager.play_music("menu_theme")

	var overlay: Node = OVERLAY_SCENE.instantiate()
	add_child(overlay)

	# Grant match tokens ONCE per fight win (persisted via reward_tokens_granted to prevent reload exploits)
	if not RunManager.reward_tokens_granted:
		var tokens_earned: int = 1
		if RunManager.is_boss_match:
			tokens_earned += 1
		if RunManager.is_rival_match and RunManager.active_sponsor:
			tokens_earned += RunManager.active_sponsor.rival_reward_currency_bonus
		RunManager.add_circuit_tokens(tokens_earned)
		RunManager.reward_tokens_granted = true
		RunManager.save_run()

	_generate_rewards()


func _generate_rewards() -> void:
	for c: Node in container.get_children():
		c.queue_free()
	if is_instance_valid(_reroll_btn):
		_reroll_btn.queue_free()
		_reroll_btn = null

	var valid_actions: Array[ActionData] = RunManager.get_valid_action_rewards().duplicate()
	var valid_items: Array[EquipmentData] = RunManager.get_unowned_equipment(RunManager.player_run_data)
	var stat_upgrades: Array[Dictionary] = RunManager.get_stat_upgrades().duplicate()

	var choices: Array = []

	# Sample WITHOUT replacement so the same action, equipment, or upgrade never appears twice
	if valid_actions.size() > 0:
		choices.append(_pop_random(valid_actions))
	elif stat_upgrades.size() > 0:
		choices.append(_pop_random(stat_upgrades))

	if valid_items.size() > 0 and randf() > 0.5:
		choices.append(_pop_weighted_random(valid_items))
	elif stat_upgrades.size() > 0:
		choices.append(_pop_random(stat_upgrades))
	elif valid_actions.size() > 0:
		choices.append(_pop_random(valid_actions))

	var roll: float = randf()
	if roll < 0.4 and valid_actions.size() > 0:
		choices.append(_pop_random(valid_actions))
	elif roll < 0.7 and valid_items.size() > 0:
		choices.append(_pop_weighted_random(valid_items))
	elif stat_upgrades.size() > 0:
		choices.append(_pop_random(stat_upgrades))
	elif valid_actions.size() > 0:
		choices.append(_pop_random(valid_actions))
	elif valid_items.size() > 0:
		choices.append(_pop_weighted_random(valid_items))

	var extra_opts: int = 0
	if RunManager.active_sponsor:
		extra_opts += RunManager.active_sponsor.extra_draft_options
	if RunManager.player_run_data:
		for eq: EquipmentData in RunManager.player_run_data.equipment:
			if eq:
				extra_opts += eq.extra_draft_options
	for _i: int in range(extra_opts):
		if valid_actions.size() > 0 and randf() > 0.5:
			choices.append(_pop_random(valid_actions))
		elif stat_upgrades.size() > 0:
			choices.append(_pop_random(stat_upgrades))
		elif valid_actions.size() > 0:
			choices.append(_pop_random(valid_actions))
		elif valid_items.size() > 0:
			choices.append(_pop_weighted_random(valid_items))

	if RunManager.is_boss_match:
		if title_label:
			title_label.text = "BOSS VICTORY! CHOOSE YOUR REWARD"
		var has_equipment_choice: bool = false
		for ch: Variant in choices:
			if ch is EquipmentData:
				has_equipment_choice = true
				break
		if not has_equipment_choice and valid_items.size() > 0:
			choices.insert(0, _pop_weighted_random(valid_items))
		elif valid_actions.size() > 0:
			choices.append(_pop_random(valid_actions))
		elif stat_upgrades.size() > 0:
			choices.append(_pop_random(stat_upgrades))

	# Keep rival_reward_item intact across rerolls; is_rival_match is cleared when a reward is claimed
	if RunManager.is_rival_match and RunManager.active_sponsor:
		if RunManager.active_sponsor.rival_reward_item != null:
			var rival_item: EquipmentData = RunManager.active_sponsor.rival_reward_item
			var already_in: bool = false
			for ch: Variant in choices:
				if ch is EquipmentData and (ch as EquipmentData).item_name == rival_item.item_name:
					already_in = true
					break
			if not already_in:
				choices.insert(0, rival_item)

	for reward: Variant in choices:
		if reward != null:
			_create_reward_card(reward)

	if RunManager.current_rerolls > 0:
		_reroll_btn = Button.new()
		_reroll_btn.text = "Reroll Options (" + str(RunManager.current_rerolls) + " left)"
		_reroll_btn.custom_minimum_size = Vector2(200, 50)
		add_child(_reroll_btn)
		_reroll_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_reroll_btn.position.y -= 50.0

		_reroll_btn.pressed.connect(func() -> void:
			if _reward_claimed:
				return
			AudioManager.play_sfx("ui_click")
			RunManager.current_rerolls -= 1
			RunManager.save_run()
			_generate_rewards()
		)


func _pop_random(pool: Array) -> Variant:
	if pool.is_empty():
		return null
	var idx: int = randi_range(0, pool.size() - 1)
	var item: Variant = pool[idx]
	pool.remove_at(idx)
	return item


func _pop_weighted_random(pool: Array) -> Variant:
	var picked: Variant = _get_weighted_random(pool)
	if picked != null:
		pool.erase(picked)
	return picked


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
	if _reward_claimed:
		return
	_reward_claimed = true
	for child: Node in container.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = true
	if is_instance_valid(_reroll_btn):
		_reroll_btn.disabled = true
	AudioManager.play_sfx("ui_click")
	RunManager.apply_reward(reward)


func _get_weighted_random(pool: Array) -> Variant:
	if pool.is_empty():
		return null

	var active_synergies: Array[String] = RunManager.get_active_synergies()

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
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	parent.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var cat: Label = Label.new()
	cat.text = category
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.modulate = Color(0.55, 0.55, 0.55)
	cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cat)

	var t: Label = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(t)

	var d: RichTextLabel = RichTextLabel.new()
	d.text = "[center]" + desc + "[/center]"
	d.bbcode_enabled = true
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(d)
