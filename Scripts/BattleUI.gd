extends CanvasLayer

const BattleEffectsControllerScript = preload("res://Scripts/Battle/BattleEffectsController.gd")
const BattleTooltipControllerScript = preload("res://Scripts/Battle/BattleTooltipController.gd")
const BattleInspectPanelScript = preload("res://Scripts/Battle/BattleInspectPanel.gd")

#region Signals & Scenes

signal human_selected_card(action_card: ActionData, extra_data: Dictionary)
signal p1_mode_toggled(is_human: bool)
signal p2_mode_toggled(is_human: bool)

var game_over_scene: PackedScene = preload("res://Scenes/GameOverScreen.tscn")
var card_display_scene: PackedScene = preload("res://Scenes/CardDisplay.tscn")
var card_button_scene: PackedScene = preload("res://Scenes/CardButton.tscn")
var floating_text_scene: PackedScene = preload("res://Scenes/FloatingText.tscn")
var compendium_scene: PackedScene = preload("res://Scenes/compendium.tscn")

#endregion

#region Node References

@onready var p1_hud: Control = $P1_HUD
@onready var p2_hud: Control = $P2_HUD
@onready var momentum_tracker: VBoxContainer = $MomentumTracker
@onready var status_label: Label = $MomentumTracker/StatusLabel
@onready var slot_grid: HBoxContainer = $MomentumTracker/SlotGrid
@onready var combat_log: Control = $CombatLog

@onready var button_grid: GridContainer = %ButtonGrid
@onready var preview_card: Control = %PreviewCard
@onready var tooltip_panel: PanelContainer = $MainLayout/PreviewAnchor/TooltipPanel
@onready var tooltip_label: RichTextLabel = $MainLayout/PreviewAnchor/TooltipPanel/ToolTipLabel
@onready var btn_offence: Button = %Offence
@onready var btn_defence: Button = %Defence
@onready var equipment_grid: HBoxContainer = $EquipmentGrid
@onready var log_toggle: CheckButton = $LogToggle

@onready var clash_layer: Control = $ClashLayer
@onready var left_card_display: Control = $ClashLayer/LeftCard
@onready var right_card_display: Control = $ClashLayer/RightCard
@onready var background: TextureRect = $Background

@onready var env_button: Button = $EnvButton
@onready var env_popup: PanelContainer = $EnvPopup
@onready var env_title: Label = $EnvPopup/VBoxContainer/EnvTitle
@onready var env_details: RichTextLabel = $EnvPopup/VBoxContainer/EnvDetails
@onready var close_env_button: Button = $EnvPopup/VBoxContainer/CloseEnvButton
@onready var inspect_btn: Button = $InspectButton
@onready var inspect_popup: Panel = $InspectPopup
@onready var inspect_grid: GridContainer = $InspectPopup/ScrollContainer/InspectGrid

@onready var p1_bark_label: PanelContainer = $P1_Bark
@onready var p2_bark_label: PanelContainer = $P2_Bark

#endregion

#region Runtime State

var _effects_ctrl: Node
var _tooltip_ctrl: Node
var _inspect_ctrl: Node

var game_over_screen: Control = null
var go_layer: CanvasLayer = null
var momentum_slots: Array[Panel] = []
var current_deck: Array[ActionData] = []
var current_tab: ActionData.Type = ActionData.Type.OFFENCE

var _prev_p1_stats: Dictionary = { "hp": 0, "sp": 0 }
var _prev_p2_stats: Dictionary = { "hp": 0, "sp": 0 }

# Turn Input Constraints
var current_sp_limit: int = 0
var current_hp_limit: int = 0
var my_opportunity_val: int = 0
var my_opening_value: int = 0
var turn_cost_limit: int = 99
var opener_restriction: bool = false
var super_allowed: bool = false
var feint_mode: bool = false

var skip_action: ActionData
var is_locked: bool = false
var active_input_player: int = 1
var _hotseat_banner: Label = null

# Dynamic Controls
var p1_toggle: CheckButton
var p2_toggle: CheckButton
var rage_toggle: CheckButton
var keep_up_toggle: CheckButton
var tech_dropdown: OptionButton

#endregion


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not btn_offence or not btn_defence:
		printerr("CRITICAL: Buttons missing in BattleUI")
		return

	# Sub-controllers
	_effects_ctrl = BattleEffectsControllerScript.new()
	_effects_ctrl.name = "BattleEffectsController"
	add_child(_effects_ctrl)
	_effects_ctrl.call(
		"setup",
		self,
		background,
		clash_layer,
		left_card_display,
		right_card_display,
		p1_hud,
		p2_hud,
		momentum_tracker,
		p1_bark_label,
		p2_bark_label,
		floating_text_scene
	)

	_tooltip_ctrl = BattleTooltipControllerScript.new()
	_tooltip_ctrl.name = "BattleTooltipController"
	add_child(_tooltip_ctrl)
	_tooltip_ctrl.call("setup", preview_card, tooltip_panel, tooltip_label, equipment_grid, preview_card.position)

	_inspect_ctrl = BattleInspectPanelScript.new()
	_inspect_ctrl.name = "BattleInspectPanel"
	add_child(_inspect_ctrl)
	_inspect_ctrl.call(
		"setup",
		self,
		inspect_btn,
		inspect_popup,
		inspect_grid,
		env_button,
		env_popup,
		env_title,
		env_details,
		close_env_button,
		card_display_scene,
		compendium_scene
	)

	GameManager.wall_crush_occurred.connect(_on_wall_crush_ui)
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.healing_received.connect(_on_healing_received)
	GameManager.status_applied.connect(_on_status_applied)
	GameManager.combat_log_updated.connect(_on_combat_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved_log)
	if not GameManager.state_changed.is_connected(_on_game_state_changed):
		GameManager.state_changed.connect(_on_game_state_changed)

	GameManager.combat_log_updated.emit(
		"Location: " + GameManager.current_environment_name + " (" + str(GameManager.TOTAL_MOMENTUM_SLOTS) + " Slots)"
	)

	# Combat log drawer starts tucked off-screen left
	combat_log.position.x = -400.0
	combat_log.visible = true
	if log_toggle:
		log_toggle.button_pressed = false
		log_toggle.toggled.connect(_on_log_toggled)

	btn_offence.pressed.connect(func() -> void: _switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func() -> void: _switch_tab(ActionData.Type.DEFENCE))

	skip_action = ActionData.new()
	skip_action.display_name = "SKIP FEINT"
	skip_action.description = "Stop combining and use your original action."
	skip_action.cost = 0

	button_grid.visible = false

	await get_tree().process_frame
	_snapshot_stats()
	_create_passive_toggles()
	setup_toggles()
	_effects_ctrl.call("update_background")

	await get_tree().process_frame
	_effects_ctrl.call("init_background_parallax")
	_effects_ctrl.call("show_player_identity_flash")


func _exit_tree() -> void:
	if GlobalCinematics:
		GlobalCinematics.reset_visuals()


#region Public FX Forwarding

func apply_camera_impact(zoom_amount: float, shake_amount: float) -> void:
	if _effects_ctrl:
		_effects_ctrl.call("apply_camera_impact", zoom_amount, shake_amount)


func play_clash_animation(p1_card: ActionData, p2_card: ActionData) -> void:
	if _effects_ctrl:
		_effects_ctrl.call("play_clash_animation", p1_card, p2_card)

#endregion

#region HUD, Momentum & Passives

func _create_passive_toggles() -> void:
	var container: HBoxContainer = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	container.position.y -= 200.0
	container.position.x -= 570.0

	rage_toggle = CheckButton.new()
	rage_toggle.text = "RAGE (Pay HP)"
	rage_toggle.visible = false
	rage_toggle.toggled.connect(func(_on: bool) -> void: _refresh_grid())
	container.add_child(rage_toggle)

	keep_up_toggle = CheckButton.new()
	keep_up_toggle.text = "KEEP UP (Pay SP)"
	keep_up_toggle.visible = false
	container.add_child(keep_up_toggle)

	tech_dropdown = OptionButton.new()
	tech_dropdown.add_item("Tech: None")
	tech_dropdown.add_item("+Opener (1 SP)")
	tech_dropdown.add_item("+Tiring 1 (1 SP)")
	tech_dropdown.add_item("+Momentum 1 (1 SP)")
	tech_dropdown.selected = 0
	tech_dropdown.visible = false
	tech_dropdown.item_selected.connect(func(_idx: int) -> void: _refresh_grid())
	container.add_child(tech_dropdown)


func setup_passive_toggles(character: CharacterData) -> void:
	rage_toggle.visible = character.can_pay_with_hp
	keep_up_toggle.visible = character.has_keep_up_toggle
	tech_dropdown.visible = character.has_technique_dropdown
	tech_dropdown.selected = 0
	rage_toggle.button_pressed = false
	keep_up_toggle.button_pressed = false


func initialize_hud(p1_data: CharacterData, p2_data: CharacterData) -> void:
	p1_hud.call("setup", p1_data)
	p2_hud.call("setup", p2_data)
	p1_hud.call("configure_visuals", false)
	p2_hud.call("configure_visuals", true)
	update_momentum(0)
	if _tooltip_ctrl:
		_tooltip_ctrl.call("populate_equipment", p1_data)


func update_all_visuals(p1: CharacterData, p2: CharacterData, momentum: int) -> void:
	p1_hud.call("update_stats", p1, GameManager.state.p1_opportunity_stat, GameManager.state.p1_opening_stat, p1.patient_buff_active)
	p2_hud.call("update_stats", p2, GameManager.state.p2_opportunity_stat, GameManager.state.p2_opening_stat, p2.patient_buff_active)
	update_momentum(momentum)


func update_momentum(val: int) -> void:
	if momentum_slots.is_empty():
		_build_momentum_track()

	var text: String = "NEUTRAL: " + GameManager.current_environment_name.to_upper()
	if val > 0 and val <= GameManager.MOMENTUM_P1_MAX:
		text = "P1 ADVANTAGE"
	elif val > GameManager.MOMENTUM_P1_MAX:
		text = "P2 ADVANTAGE"
	if status_label:
		status_label.text = text

	for i: int in range(momentum_slots.size()):
		var slot: Panel = momentum_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		var slot_num: int = i + 1

		if val == 0:
			style.bg_color.a = 0.3
			slot.scale = Vector2.ONE
		elif slot_num == val:
			style.bg_color = Color.CYAN if slot_num <= GameManager.MOMENTUM_P1_MAX else Color.RED
			style.bg_color.a = 1.0
			var tween: Tween = create_tween()
			slot.pivot_offset = slot.size / 2.0
			slot.scale = Vector2(1.3, 1.3)
			tween.tween_property(slot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE)
		else:
			style.bg_color = Color(0.1, 0.4, 0.5) if slot_num <= GameManager.MOMENTUM_P1_MAX else Color(0.5, 0.1, 0.1)
			style.bg_color.a = 0.4
			slot.scale = Vector2.ONE

		slot.add_theme_stylebox_override("panel", style)


func _build_momentum_track() -> void:
	for child: Node in slot_grid.get_children():
		child.queue_free()
	momentum_slots.clear()

	for i: int in range(1, GameManager.TOTAL_MOMENTUM_SLOTS + 1):
		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(30, 15)

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(2)

		if i <= GameManager.MOMENTUM_P1_MAX:
			style.bg_color = Color(0.1, 0.4, 0.5, 0.5)
			if i == 1:
				style.border_width_left = 4
				style.border_color = Color.CYAN
		else:
			style.bg_color = Color(0.5, 0.1, 0.1, 0.5)
			if i == GameManager.TOTAL_MOMENTUM_SLOTS:
				style.border_width_right = 4
				style.border_color = Color.RED

		slot.add_theme_stylebox_override("panel", style)
		slot_grid.add_child(slot)
		momentum_slots.append(slot)

		if i == floori(float(GameManager.TOTAL_MOMENTUM_SLOTS) / 2.0):
			var div: VSeparator = VSeparator.new()
			slot_grid.add_child(div)

#endregion

#region Deck Input & Validation

func load_deck(deck: Array[ActionData]) -> void:
	current_deck = deck
	_refresh_grid()


func unlock_for_input(
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

	button_grid.visible = true
	is_locked = false
	current_sp_limit = player_current_sp
	current_hp_limit = player_current_hp
	opener_restriction = must_be_opener
	turn_cost_limit = max_cost
	my_opening_value = opening_val
	super_allowed = can_use_super
	my_opportunity_val = opportunity_val
	feint_mode = is_feint_mode

	if GameManager.is_super_disabled(active_input_player):
		super_allowed = false

	if GameManager.has_reveal_enemy_opener(1) and GameManager.state.momentum == 0:
		if GameManager.state.p2_action_queue:
			_effects_ctrl.call("show_bark", 2, "Scouted: " + GameManager.state.p2_action_queue.display_name + "!")
		elif GameManager.p2_data:
			var likely_opener: ActionData = null
			for card: ActionData in GameManager.p2_data.deck:
				if card.type == ActionData.Type.OFFENCE and card.is_opener and card.cost <= GameManager.p2_data.current_sp:
					if likely_opener == null or card.damage > likely_opener.damage:
						likely_opener = card
			if likely_opener:
				_effects_ctrl.call("show_bark", 2, "Likely Opener: " + likely_opener.display_name)

	if forced_tab != null:
		var tab_enum: ActionData.Type = forced_tab as ActionData.Type
		_switch_tab(tab_enum)
		btn_offence.disabled = (tab_enum != ActionData.Type.OFFENCE)
		btn_defence.disabled = (tab_enum != ActionData.Type.DEFENCE)
		btn_offence.modulate = Color.WHITE if not btn_offence.disabled else Color(0.3, 0.3, 0.3)
		btn_defence.modulate = Color.WHITE if not btn_defence.disabled else Color(0.3, 0.3, 0.3)
	else:
		btn_offence.disabled = false
		btn_defence.disabled = false
		_switch_tab(current_tab)


func set_active_input_player(player_id: int, show_hotseat_banner: bool) -> void:
	active_input_player = player_id
	if not show_hotseat_banner:
		if _hotseat_banner:
			_hotseat_banner.visible = false
		return

	if _hotseat_banner == null:
		_hotseat_banner = Label.new()
		_hotseat_banner.name = "HotseatTurnBanner"
		_hotseat_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hotseat_banner.add_theme_font_size_override("font_size", 24)
		_hotseat_banner.add_theme_color_override("font_outline_color", Color.BLACK)
		_hotseat_banner.add_theme_constant_override("outline_size", 4)
		_hotseat_banner.anchor_left = 0.25
		_hotseat_banner.anchor_right = 0.75
		_hotseat_banner.anchor_top = 0.0
		_hotseat_banner.anchor_bottom = 0.0
		_hotseat_banner.offset_top = 108.0
		_hotseat_banner.offset_bottom = 144.0
		add_child(_hotseat_banner)

	var fighter_name: String = ""
	if player_id == 1 and GameManager.p1_data:
		fighter_name = GameManager.p1_data.character_name
	elif player_id == 2 and GameManager.p2_data:
		fighter_name = GameManager.p2_data.character_name

	var label_prefix: String = "PLAYER 1'S TURN" if player_id == 1 else "PLAYER 2'S TURN"
	_hotseat_banner.text = "%s (%s) — CHOOSE ACTION" % [label_prefix, fighter_name] if fighter_name != "" else label_prefix
	_hotseat_banner.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0) if player_id == 1 else Color(1.0, 0.5, 0.5))
	_hotseat_banner.visible = true


func lock_ui() -> void:
	is_locked = true
	button_grid.visible = false
	if _hotseat_banner:
		_hotseat_banner.visible = false
	_on_card_exited()


func _on_card_selected(card: ActionData) -> void:
	if is_locked:
		return
	var extra_data: Dictionary = {
		"rage": rage_toggle.button_pressed if rage_toggle.visible else false,
		"keep_up": keep_up_toggle.button_pressed if keep_up_toggle.visible else false,
		"technique": tech_dropdown.selected if tech_dropdown.visible else 0
	}
	human_selected_card.emit(card, extra_data)
	lock_ui()


func _switch_tab(type: ActionData.Type) -> void:
	current_tab = type
	_refresh_grid()
	if not btn_offence.disabled:
		btn_offence.modulate = Color.WHITE if type == ActionData.Type.OFFENCE else Color(0.6, 0.6, 0.6)
	if not btn_defence.disabled:
		btn_defence.modulate = Color.WHITE if type == ActionData.Type.DEFENCE else Color(0.6, 0.6, 0.6)


func _refresh_grid() -> void:
	for child: Node in button_grid.get_children():
		child.queue_free()

	if OS.get_cmdline_args().has("--server") or DisplayServer.get_name() == "headless":
		return
	if current_deck == null or current_deck.is_empty():
		return

	for card: ActionData in current_deck:
		if card == null or card.type != current_tab:
			continue
		var final_cost: int = _calculate_card_cost(card)
		var is_valid: bool = _check_card_validity(card, final_cost)
		_spawn_card_button(card, final_cost, is_valid, Color.WHITE)

	var hide_struggle: bool = false
	if TutorialManager.is_tutorial_active:
		var required_card_name: String = str(TutorialManager.get_current_data().get("player_card", ""))
		if required_card_name != "Struggle":
			hide_struggle = true

	if not feint_mode and not hide_struggle:
		var struggle: ActionData = GameManager.get_struggle_action(current_tab)
		_spawn_card_button(struggle, 0, true, Color(0.9, 0.9, 0.9))

	if feint_mode:
		skip_action.type = current_tab
		_spawn_card_button(skip_action, 0, true, Color(0.9, 0.9, 1.0))


func _spawn_card_button(card: ActionData, cost_display: int, available: bool, tint: Color) -> void:
	var btn: Control = card_button_scene.instantiate() as Control
	button_grid.add_child(btn)
	btn.call("setup", card)
	btn.call("update_cost_display", cost_display)
	btn.call("set_available", available)
	btn.modulate = tint
	btn.connect("card_hovered", _on_card_hovered)
	btn.connect("card_exited", _on_card_exited)
	btn.connect("card_selected", _on_card_selected)


func _calculate_card_cost(card: ActionData) -> int:
	var tech_idx: int = tech_dropdown.selected if tech_dropdown.visible else 0
	var tech_cost: int = 1 if tech_idx > 0 else 0
	var base_cost: int = card.cost + tech_cost
	return maxi(0, base_cost - my_opportunity_val)


func _check_card_validity(card: ActionData, final_cost: int) -> bool:
	var can_afford: bool = false
	if rage_toggle.visible and rage_toggle.button_pressed:
		can_afford = (current_hp_limit > final_cost)
	else:
		can_afford = (final_cost <= current_sp_limit)

	if feint_mode and RunManager.active_sponsor and RunManager.active_sponsor.feints_cost_hp:
		if (current_hp_limit + current_sp_limit) >= final_cost:
			can_afford = true

	if not can_afford:
		return false

	var tech_idx: int = tech_dropdown.selected if tech_dropdown.visible else 0
	if tech_idx == 1 and card.type == ActionData.Type.DEFENCE:
		return false

	var effective_is_opener: bool = card.is_opener
	if tech_idx == 1 and card.type == ActionData.Type.OFFENCE:
		effective_is_opener = true

	if opener_restriction and card.type == ActionData.Type.OFFENCE and not effective_is_opener:
		return false
	if card.cost > turn_cost_limit:
		return false
	if card.counter_value > 0 and my_opening_value < card.counter_value:
		return false
	if card.is_super and not super_allowed:
		return false

	if TutorialManager.is_tutorial_active:
		var required_card: String = str(TutorialManager.get_current_data().get("player_card", ""))
		if required_card != "" and card.display_name != required_card:
			return false

	return true


func _on_card_hovered(card: ActionData) -> void:
	if _tooltip_ctrl:
		var effective_cost: int = maxi(0, card.cost - my_opportunity_val)
		_tooltip_ctrl.call("show_card_preview", card, effective_cost)


func _on_card_exited() -> void:
	if _tooltip_ctrl:
		_tooltip_ctrl.call("hide_all")

#endregion

#region Combat Signal Handlers & Log

func _on_game_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.POST_CLASH:
		_log_stat_changes()
		if _effects_ctrl:
			_effects_ctrl.call("reset_finisher_state")


func _on_damage_dealt(target_id: int, amount: int, is_blocked: bool) -> void:
	if is_blocked:
		_effects_ctrl.call("spawn_floating_text", target_id, "BLOCKED", Color.GRAY, 0.0)
		AudioManager.play_sfx("block", 0.1)
	else:
		_effects_ctrl.call("spawn_floating_text", target_id, str(amount), Color.RED, 0.0)
		if amount >= 5:
			AudioManager.play_sfx("hit_heavy", 0.1)
			apply_camera_impact(0.15, 20.0)
		else:
			AudioManager.play_sfx("hit_light", 0.2)
			apply_camera_impact(0.05, 5.0)

		if target_id == 1:
			p1_hud.call("play_hit_animation")
		else:
			p2_hud.call("play_hit_animation")

	var victim: CharacterData = GameManager.p1_data if target_id == 1 else GameManager.p2_data
	if amount >= 3 and victim:
		var line: String = DialogueManager.get_reaction(victim.class_type, "HURT_HEAVY")
		_effects_ctrl.call("show_bark", target_id, line)

	if victim and victim.current_hp <= 0:
		_effects_ctrl.call("play_finisher_sequence")
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree() and GlobalCinematics:
			GlobalCinematics.reset_visuals()


func _on_healing_received(target_id: int, amount: int) -> void:
	_effects_ctrl.call("spawn_floating_text", target_id, "+" + str(amount), Color.GREEN, 0.0)


func _on_status_applied(target_id: int, status: String) -> void:
	_effects_ctrl.call("spawn_floating_text", target_id, status, Color.YELLOW, -40.0)


func _on_combat_log_updated(text: String) -> void:
	if combat_log:
		combat_log.call("add_log", text)


func _on_clash_resolved_log(winner_id: int, p1_card: ActionData, p2_card: ActionData, _results: Dictionary) -> void:
	if combat_log:
		combat_log.call("add_clash_log", winner_id, p1_card, p2_card)

	apply_camera_impact(0.02, 0.0)

	if p1_card.type == ActionData.Type.OFFENCE:
		p1_hud.call("play_attack_animation", Vector2(50, 0))
	if p2_card.type == ActionData.Type.OFFENCE:
		p2_hud.call("play_attack_animation", Vector2(-50, 0))

	AudioManager.play_sfx("clash", 0.1)

	if randf() < 0.25:
		var winner_data: CharacterData = GameManager.p1_data if winner_id == 1 else GameManager.p2_data
		var winner_card: ActionData = p1_card if winner_id == 1 else p2_card
		if winner_data and winner_card:
			var context: String = "WIN_DEFENCE" if winner_card.type == ActionData.Type.DEFENCE else "WIN_OFFENCE"
			var line: String = DialogueManager.get_reaction(winner_data.class_type, context)
			_effects_ctrl.call("show_bark", winner_id, line)


func _on_log_toggled(toggled_on: bool) -> void:
	var target_x: float = 12.0 if toggled_on else -400.0
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(combat_log, "position:x", target_x, 0.4)


func _on_wall_crush_ui(target_id: int, _dmg: int) -> void:
	if _effects_ctrl:
		_effects_ctrl.call("play_wall_crush_shake", target_id)


func _log_stat_changes() -> void:
	if not combat_log or not GameManager.p1_data or not GameManager.p2_data:
		return

	var p1_cur: Dictionary = { "hp": GameManager.p1_data.current_hp, "sp": GameManager.p1_data.current_sp }
	var p2_cur: Dictionary = { "hp": GameManager.p2_data.current_hp, "sp": GameManager.p2_data.current_sp }

	if _prev_p1_stats["hp"] == 0 and _prev_p2_stats["hp"] == 0:
		_snapshot_stats()
		return

	var p1_diff: Dictionary = { "hp": p1_cur["hp"] - _prev_p1_stats["hp"], "sp": p1_cur["sp"] - _prev_p1_stats["sp"] }
	var p2_diff: Dictionary = { "hp": p2_cur["hp"] - _prev_p2_stats["hp"], "sp": p2_cur["sp"] - _prev_p2_stats["sp"] }

	combat_log.call("add_round_summary", p1_diff, p2_diff, GameManager.state.momentum)
	_snapshot_stats()


func _snapshot_stats() -> void:
	if GameManager.p1_data:
		_prev_p1_stats = { "hp": GameManager.p1_data.current_hp, "sp": GameManager.p1_data.current_sp }
	if GameManager.p2_data:
		_prev_p2_stats = { "hp": GameManager.p2_data.current_hp, "sp": GameManager.p2_data.current_sp }

#endregion

#region Menu, Debug Toggles & Match Lifecycle

func _on_menu_pressed() -> void:
	if _inspect_ctrl:
		_inspect_ctrl.call("open_compendium")


func setup_toggles(p1_override: Variant = null, p2_override: Variant = null) -> void:
	var p1_is_human: bool = true
	var p2_is_human: bool = false

	if not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		p2_is_human = true

	if p1_override != null:
		p1_is_human = bool(p1_override)
	if p2_override != null:
		p2_is_human = bool(p2_override)

	if is_instance_valid(p1_toggle) and is_instance_valid(p2_toggle):
		p1_toggle.set_pressed_no_signal(p1_is_human)
		p2_toggle.set_pressed_no_signal(p2_is_human)
		return

	var container: HBoxContainer = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	container.position.y += 60.0
	container.add_theme_constant_override("separation", 20)
	container.visible = false
	container.name = "DebugContainer"

	p1_toggle = CheckButton.new()
	p1_toggle.text = "P1 Human"
	p1_toggle.toggled.connect(func(on: bool) -> void: p1_mode_toggled.emit(on))
	p1_toggle.set_pressed_no_signal(p1_is_human)
	container.add_child(p1_toggle)

	p2_toggle = CheckButton.new()
	p2_toggle.text = "P2 Human"
	p2_toggle.toggled.connect(func(on: bool) -> void: p2_mode_toggled.emit(on))
	p2_toggle.set_pressed_no_signal(p2_is_human)
	container.add_child(p2_toggle)


func setup_match_ui(p1: CharacterData, p2: CharacterData, local_id: int) -> void:
	if not go_layer:
		go_layer = CanvasLayer.new()
		go_layer.layer = 100
		add_child(go_layer)

		game_over_screen = game_over_scene.instantiate() as Control
		game_over_screen.visible = false
		game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS
		go_layer.add_child(game_over_screen)

	if not GameManager.game_over.is_connected(_show_game_over):
		GameManager.game_over.connect(_show_game_over)

	initialize_hud(p1, p2)

	if local_id == 1:
		load_deck(p1.deck)
	elif local_id == 2:
		load_deck(p2.deck)
	else:
		load_deck(p1.deck)


func _show_game_over(winner_id: int) -> void:
	if not game_over_screen or game_over_screen.visible:
		return

	if GameManager.p1_data and GameManager.p2_data:
		update_all_visuals(GameManager.p1_data, GameManager.p2_data, GameManager.state.momentum)

	var winner_data: CharacterData = GameManager.p1_data if winner_id == 1 else GameManager.p2_data
	var final_log_text: String = ""
	if combat_log and combat_log.has_method("get_log_text"):
		final_log_text = str(combat_log.call("get_log_text"))

	game_over_screen.call("setup", winner_data, final_log_text)
	game_over_screen.visible = true

	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		get_tree().paused = true

#endregion
