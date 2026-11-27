extends Node
class_name BattleHandController

const CombatRulesScript = preload("res://Scripts/Battle/CombatRules.gd")

signal card_selected(action_card: ActionData, extra_data: Dictionary)
signal card_hovered(card: ActionData, effective_cost: int)
signal card_exited()

var host_layer: CanvasLayer
var button_grid: GridContainer
var btn_offence: Button
var btn_defence: Button
var card_button_scene: PackedScene

var rage_toggle: CheckButton
var tech_dropdown: OptionButton

var current_deck: Array[ActionData] = []
var current_tab: ActionData.Type = ActionData.Type.OFFENCE
var skip_action: ActionData

var active_character: CharacterData = null
var active_player_id: int = 1
var current_sp_limit: int = 0
var current_hp_limit: int = 0
var my_opportunity_val: int = 0
var my_opening_value: int = 0
var turn_cost_limit: int = 99
var opener_restriction: bool = false
var super_allowed: bool = false
var feint_mode: bool = false
var base_feint_cost: int = 0
var is_locked: bool = false


func setup(
	p_host_layer: CanvasLayer,
	p_button_grid: GridContainer,
	p_btn_offence: Button,
	p_btn_defence: Button,
	p_card_button_scene: PackedScene
) -> void:
	host_layer = p_host_layer
	button_grid = p_button_grid
	btn_offence = p_btn_offence
	btn_defence = p_btn_defence
	card_button_scene = p_card_button_scene

	btn_offence.pressed.connect(func() -> void: switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func() -> void: switch_tab(ActionData.Type.DEFENCE))

	skip_action = ActionData.new()
	skip_action.display_name = "SKIP FEINT"
	skip_action.description = "Stop combining and use your original action."
	skip_action.cost = 0

	button_grid.visible = false
	_create_passive_toggles()


func _create_passive_toggles() -> void:
	var container: HBoxContainer = HBoxContainer.new()
	container.name = "PassiveToggles"
	host_layer.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	container.position.y -= 200.0
	container.position.x -= 570.0

	rage_toggle = CheckButton.new()
	rage_toggle.text = "RAGE (Pay HP)"
	rage_toggle.tooltip_text = "RAGE: Pay HP instead of SP when low. Tiring also drains HP when you are out of SP."
	rage_toggle.visible = false
	rage_toggle.toggled.connect(func(_on: bool) -> void: refresh_grid())
	container.add_child(rage_toggle)

	tech_dropdown = OptionButton.new()
	tech_dropdown.add_item("Tech: None")
	tech_dropdown.add_item("+Opener (1 SP)")
	tech_dropdown.add_item("+Tiring 1 (1 SP)")
	tech_dropdown.add_item("+Momentum 1 (1 SP)")
	tech_dropdown.selected = 0
	tech_dropdown.visible = false
	tech_dropdown.item_selected.connect(func(_idx: int) -> void: refresh_grid())
	container.add_child(tech_dropdown)


func setup_passive_toggles(character: CharacterData) -> void:
	active_character = character
	if rage_toggle == null or tech_dropdown == null or character == null:
		return
	rage_toggle.visible = character.can_pay_with_hp
	tech_dropdown.visible = character.has_technique_dropdown
	tech_dropdown.selected = 0
	rage_toggle.button_pressed = false


func load_deck(deck: Array[ActionData]) -> void:
	current_deck = deck
	refresh_grid()


func unlock_for_input(
	player_id: int,
	forced_tab: Variant,
	player_current_sp: int,
	player_current_hp: int,
	must_be_opener: bool = false,
	max_cost: int = 99,
	opening_val: int = 0,
	can_use_super: bool = false,
	opportunity_val: int = 0,
	is_feint_mode: bool = false
) -> void:
	if OS.get_cmdline_args().has("--server") or DisplayServer.get_name() == "headless":
		return

	active_player_id = player_id
	active_character = GameManager.p1_data if player_id == 1 else GameManager.p2_data
	button_grid.visible = true
	is_locked = false
	current_sp_limit = player_current_sp
	current_hp_limit = player_current_hp
	opener_restriction = must_be_opener
	turn_cost_limit = max_cost
	my_opening_value = opening_val
	super_allowed = can_use_super and not GameManager.is_super_disabled(player_id)
	my_opportunity_val = opportunity_val
	feint_mode = is_feint_mode

	var base_card: ActionData = (GameManager.state.p1_action_queue if player_id == 1 else GameManager.state.p2_action_queue) if is_feint_mode else null
	base_feint_cost = base_card.cost if base_card != null else 0

	if forced_tab != null:
		var tab_enum: ActionData.Type = forced_tab as ActionData.Type
		switch_tab(tab_enum)
		btn_offence.disabled = (tab_enum != ActionData.Type.OFFENCE)
		btn_defence.disabled = (tab_enum != ActionData.Type.DEFENCE)
		btn_offence.modulate = Color.WHITE if not btn_offence.disabled else Color(0.3, 0.3, 0.3)
		btn_defence.modulate = Color.WHITE if not btn_defence.disabled else Color(0.3, 0.3, 0.3)
	else:
		btn_offence.disabled = false
		btn_defence.disabled = false
		switch_tab(current_tab)


func lock_ui() -> void:
	is_locked = true
	button_grid.visible = false
	card_exited.emit()


func switch_tab(type: ActionData.Type) -> void:
	current_tab = type
	refresh_grid()
	if not btn_offence.disabled:
		btn_offence.modulate = Color.WHITE if type == ActionData.Type.OFFENCE else Color(0.6, 0.6, 0.6)
	if not btn_defence.disabled:
		btn_defence.modulate = Color.WHITE if type == ActionData.Type.DEFENCE else Color(0.6, 0.6, 0.6)


func toggle_tab_if_allowed() -> bool:
	if is_locked or btn_offence.disabled or btn_defence.disabled:
		return false
	var next_tab: ActionData.Type = ActionData.Type.DEFENCE if current_tab == ActionData.Type.OFFENCE else ActionData.Type.OFFENCE
	switch_tab(next_tab)
	AudioManager.play_sfx("ui_hover", 0.1)
	return true


func trigger_hotkey_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or is_locked or not button_grid.visible:
		return false
	if slot_idx >= button_grid.get_child_count():
		return false
	var btn: BaseButton = button_grid.get_child(slot_idx) as BaseButton
	if btn == null or btn.disabled:
		return false
	if btn.has_method("_pressed"):
		btn.call("_pressed")
	else:
		btn.emit_signal("pressed")
	return true


func refresh_grid() -> void:
	# Detach before freeing so hotkeys 1-9 never index doomed nodes on the same frame
	var old_children: Array[Node] = button_grid.get_children()
	for child: Node in old_children:
		button_grid.remove_child(child)
		child.queue_free()

	if OS.get_cmdline_args().has("--server") or DisplayServer.get_name() == "headless":
		return
	if current_deck == null or current_deck.is_empty():
		return

	var tech_idx: int = tech_dropdown.selected if (tech_dropdown != null and tech_dropdown.visible) else 0
	var rage_on: bool = rage_toggle.button_pressed if (rage_toggle != null and rage_toggle.visible) else false
	var constraints: Dictionary = {
		"filter": current_tab,
		"needs_opener": opener_restriction,
		"max_cost": turn_cost_limit,
		"opening_stat": my_opening_value,
		"can_use_super": super_allowed,
		"opportunity_stat": my_opportunity_val,
	}

	var entries: Array[Dictionary] = []
	for card: ActionData in current_deck:
		if card == null or card.type != current_tab:
			continue
		var eval: Dictionary = _evaluate_ui_card(card, constraints, rage_on, tech_idx)
		entries.append({ "card": card, "cost": int(eval["effective_cost"]), "valid": bool(eval["valid"]) })

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_valid: bool = bool(a["valid"])
		var b_valid: bool = bool(b["valid"])
		if a_valid != b_valid:
			return a_valid
		var a_cost: int = int(a["cost"])
		var b_cost: int = int(b["cost"])
		if a_cost != b_cost:
			return a_cost < b_cost
		var a_card: ActionData = a["card"] as ActionData
		var b_card: ActionData = b["card"] as ActionData
		if a_card.cost != b_card.cost:
			return a_card.cost < b_card.cost
		return a_card.display_name < b_card.display_name
	)

	var hotkey_idx: int = 1
	for entry: Dictionary in entries:
		_spawn_card_button(entry["card"] as ActionData, int(entry["cost"]), bool(entry["valid"]), Color.WHITE, hotkey_idx)
		hotkey_idx += 1

	var hide_struggle: bool = false
	if TutorialManager.is_tutorial_active:
		var required_card_name: String = str(TutorialManager.get_current_data().get("player_card", ""))
		if required_card_name != "Struggle":
			hide_struggle = true

	if not feint_mode and not hide_struggle:
		var struggle: ActionData = GameManager.get_struggle_action(current_tab)
		_spawn_card_button(struggle, 0, true, Color(0.9, 0.9, 0.9), hotkey_idx)
		hotkey_idx += 1

	if feint_mode:
		skip_action.type = current_tab
		_spawn_card_button(skip_action, 0, true, Color(0.9, 0.9, 1.0), hotkey_idx)

	_wire_grid_focus()


func _wire_grid_focus() -> void:
	var btns: Array[Control] = []
	for child: Node in button_grid.get_children():
		if child is BaseButton:
			var b: BaseButton = child as BaseButton
			b.focus_mode = Control.FOCUS_ALL if not b.disabled else Control.FOCUS_NONE
			if not b.disabled:
				btns.append(b)
	var cols: int = maxi(1, button_grid.columns)
	for i: int in range(btns.size()):
		var cur: Control = btns[i]
		if i > 0:
			cur.focus_neighbor_left = cur.get_path_to(btns[i - 1])
		if i + 1 < btns.size():
			cur.focus_neighbor_right = cur.get_path_to(btns[i + 1])
		if i - cols >= 0:
			cur.focus_neighbor_top = cur.get_path_to(btns[i - cols])
		if i + cols < btns.size():
			cur.focus_neighbor_bottom = cur.get_path_to(btns[i + cols])


func focus_first_available_card() -> bool:
	if is_locked or not button_grid.visible:
		return false
	for child: Node in button_grid.get_children():
		if child is BaseButton and not (child as BaseButton).disabled:
			(child as Control).grab_focus()
			return true
	return false


func get_hover_context(card: ActionData) -> Dictionary:
	var tech_idx: int = tech_dropdown.selected if (tech_dropdown != null and tech_dropdown.visible) else 0
	var rage_on: bool = rage_toggle.button_pressed if (rage_toggle != null and rage_toggle.visible) else false
	var is_special: bool = (card != null and (card.is_struggle or card == skip_action))
	return {
		"player_id": active_player_id,
		"rage": rage_on,
		"tech_idx": tech_idx,
		"opportunity": my_opportunity_val,
		"feint_mode": feint_mode,
		"base_feint_cost": base_feint_cost,
		"is_special": is_special,
	}


func _evaluate_ui_card(card: ActionData, constraints: Dictionary, rage_on: bool, tech_idx: int) -> Dictionary:
	# Technical "+Opener" is Offence-only
	if tech_idx == 1 and card.type == ActionData.Type.DEFENCE:
		var eff_cost: int = CombatRulesScript.get_display_cost(card, my_opportunity_val, tech_idx, feint_mode, base_feint_cost)
		return { "valid": false, "effective_cost": eff_cost }

	var eval: Dictionary = CombatRulesScript.evaluate_card_legality(
		active_character, card, constraints, rage_on, tech_idx, feint_mode, base_feint_cost
	)
	if not bool(eval["valid"]):
		return eval

	if TutorialManager.is_tutorial_active:
		var required_card: String = str(TutorialManager.get_current_data().get("player_card", ""))
		if required_card != "" and card.display_name != required_card:
			eval["valid"] = false
	return eval


func _spawn_card_button(card: ActionData, cost_display: int, available: bool, tint: Color, hotkey_num: int = 0) -> void:
	var btn: Control = card_button_scene.instantiate() as Control
	button_grid.add_child(btn)
	btn.call("setup", card)
	btn.call("update_cost_display", cost_display)
	btn.call("set_available", available)
	if btn.has_method("set_hotkey_hint"):
		btn.call("set_hotkey_hint", hotkey_num)
	btn.modulate = tint
	btn.connect("card_hovered", _on_button_hovered)
	btn.connect("card_exited", func() -> void: card_exited.emit())
	btn.connect("card_selected", _on_button_selected)


func _on_button_hovered(card: ActionData) -> void:
	if card == null:
		return
	var tech_idx: int = tech_dropdown.selected if (tech_dropdown != null and tech_dropdown.visible) else 0
	var is_special: bool = card.is_struggle or card == skip_action
	var effective_cost: int = 0 if is_special else CombatRulesScript.get_display_cost(card, my_opportunity_val, tech_idx, feint_mode, base_feint_cost)
	card_hovered.emit(card, effective_cost)


func _on_button_selected(card: ActionData) -> void:
	if is_locked:
		return
	var extra_data: Dictionary = {
		"rage": rage_toggle.button_pressed if (rage_toggle != null and rage_toggle.visible) else false,
		"technique": tech_dropdown.selected if (tech_dropdown != null and tech_dropdown.visible) else 0,
	}
	card_selected.emit(card, extra_data)
	lock_ui()
