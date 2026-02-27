extends CanvasLayer

#region vars
signal human_selected_card(action_card, extra_data)
signal p1_mode_toggled(is_human)
signal p2_mode_toggled(is_human)

# --- REFERENCES ---
@onready var p1_hud = $P1_HUD 
@onready var p2_hud = $P2_HUD
@onready var momentum_slider = $MomentumSlider
@onready var momentum_label = $MomentumSlider/Label 
@onready var combat_log = $CombatLog

@onready var button_grid = %ButtonGrid
@onready var preview_card = %PreviewCard
@onready var tooltip_label = $MainLayout/PreviewAnchor/ToolTipLabel
@onready var btn_offence = %Offence        
@onready var btn_defence = %Defence      
@onready var equipment_grid = $EquipmentGrid

@onready var log_toggle = $LogToggle 

@onready var clash_layer = $ClashLayer
@onready var left_card_display = $ClashLayer/LeftCard
@onready var right_card_display = $ClashLayer/RightCard
@onready var background = $Background

@onready var env_button = $EnvButton
@onready var env_popup = $EnvPopup
@onready var env_title = $EnvPopup/VBoxContainer/EnvTitle
@onready var env_details = $EnvPopup/VBoxContainer/EnvDetails
@onready var close_env_button = $EnvPopup/VBoxContainer/CloseEnvButton
@onready var inspect_btn = $InspectButton
@onready var inspect_popup = $InspectPopup
@onready var inspect_grid = $InspectPopup/ScrollContainer/InspectGrid

@onready var p1_bark_label = $P1_Bark # Adjust path
@onready var p2_bark_label = $P2_Bark

var card_display_scene = preload("res://Scenes/CardDisplay.tscn")

# --- DATA ---
var card_button_scene = preload("res://Scenes/CardButton.tscn")
var floating_text_scene = preload("res://Scenes/FloatingText.tscn")
var compendium_scene = preload("res://Scenes/compendium.tscn")
var current_deck: Array[ActionData] = []
var current_tab = ActionData.Type.OFFENCE

var _prev_p1_stats = { "hp": 0, "sp": 0 }
var _prev_p2_stats = { "hp": 0, "sp": 0 }

# State Constraints
var current_sp_limit: int = 0 
var current_hp_limit: int = 0
var my_opportunity_val: int = 0
var my_opening_value: int = 0
var turn_cost_limit: int = 99 
var opener_restriction: bool = false
var super_allowed: bool = false 
var feint_mode: bool = false 

var skip_action: ActionData
var is_locked = false
var finisher_triggered: bool = false # PREVENTS DOUBLE TRIGGERS

# Toggle Buttons
var p1_toggle: CheckButton
var p2_toggle: CheckButton

# --- VISUALS (Passives & Juice) ---
var rage_toggle: CheckButton
var keep_up_toggle: CheckButton
var tech_dropdown: OptionButton

# DYNAMIC CAMERA VARIABLES
var shake_strength: float = 0.0
var shake_decay: float = 5.0
var zoom_strength: float = 0.0 
var zoom_decay: float = 5.0    
var camera: Camera2D
#endregion

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	# --- FIX: FORCE RESET AT START OF FIGHT ---
	# This ensures we don't inherit "Black & White" from the previous match
	if GlobalCinematics:
		GlobalCinematics.reset_visuals()
	# ------------------------------------------
	
	# --- NEW: HARDWARE CAMERA SETUP ---
	camera = Camera2D.new()
	# Center the camera perfectly based on screen size
	camera.position = get_viewport().get_visible_rect().size / 2.0
	add_child(camera)
	
	# This magical checkbox tells Godot to apply the Camera's zoom and shake
	# directly to the CanvasLayer using hardware acceleration!
	self.follow_viewport_enabled = true
	# ----------------------------------
	
	if not btn_offence or not btn_defence:
		printerr("CRITICAL: Buttons missing in BattleUI")
		return
	
	# --- NEW: GENERATE SHADER FOR BACKGROUND ---
	# This allows us to desaturate the BG without needing a file
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float saturation : hint_range(0.0, 1.0) = 1.0;
	void fragment() {
		vec4 tex_color = texture(TEXTURE, UV);
		float grey = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
		vec3 final_color = mix(vec3(grey), tex_color.rgb, saturation);
		COLOR = vec4(final_color, tex_color.a);
	}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	if background:
		background.material = mat
	# -------------------------------------------

	GameManager.wall_crush_occurred.connect(_on_wall_crush_ui)
	
	momentum_slider.max_value = GameManager.TOTAL_MOMENTUM_SLOTS
	momentum_slider.min_value = 1
	
	GameManager.combat_log_updated.emit("Location: " + GameManager.current_environment_name + " (" + str(GameManager.TOTAL_MOMENTUM_SLOTS) + " Slots)")
	
	if clash_layer: clash_layer.visible = false
	
	log_toggle.button_pressed = false
	combat_log.visible = false
	
	if log_toggle:
		log_toggle.toggled.connect(_on_log_toggled)
		combat_log.visible = log_toggle.button_pressed
	
	btn_offence.pressed.connect(func(): _switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func(): _switch_tab(ActionData.Type.DEFENCE))
	
	skip_action = ActionData.new()
	skip_action.display_name = "SKIP FEINT"
	skip_action.description = "Stop combining and use your original action."
	skip_action.cost = 0
	
	button_grid.visible = false
	preview_card.visible = false
	if tooltip_label: tooltip_label.visible = false
	
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.healing_received.connect(_on_healing_received)
	GameManager.status_applied.connect(_on_status_applied)	
	GameManager.combat_log_updated.connect(_on_combat_log_updated)
	GameManager.clash_resolved.connect(_on_clash_resolved_log)
	
	if not GameManager.state_changed.is_connected(_on_game_state_changed):
		GameManager.state_changed.connect(_on_game_state_changed)
	
	await get_tree().process_frame
	_snapshot_stats()
	
	_create_debug_toggles()
	_create_passive_toggles()
	setup_toggles()
	

	$MomentumSlider/Label2.text = str(GameManager.momentum)

	if env_button and env_popup:
		env_button.pressed.connect(_on_env_button_pressed)
		close_env_button.pressed.connect(func(): env_popup.visible = false)
		env_details.bbcode_enabled = true
		env_details.fit_content = true
		env_button.text = "LOCATION: " + GameManager.current_environment_name.to_upper()
	
	if inspect_btn:
		inspect_btn.pressed.connect(_on_inspect_pressed)
	
	_update_background()
	
# --- DYNAMIC CAMERA PROCESS ---
# --- DYNAMIC CAMERA PROCESS ---
func _process(delta):
	# 1. Decay Values
	var is_frozen = (finisher_triggered and get_tree().paused)
	
	if not is_frozen:
		if shake_strength > 0:
			shake_strength = lerpf(shake_strength, 0, shake_decay * delta)
			if shake_strength < 0.1: shake_strength = 0
			
		if zoom_strength > 0:
			zoom_strength = lerpf(zoom_strength, 0, zoom_decay * delta)
			if zoom_strength < 0.001: zoom_strength = 0

	# 2. Apply to Camera2D directly (Highly Efficient)
	if camera:
		# Base zoom is 1.0. We zoom IN by increasing the numbers.
		var current_zoom = 1.0 + zoom_strength
		camera.zoom = Vector2(current_zoom, current_zoom)
		
		# Shake Offset
		if shake_strength > 0:
			camera.offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
		else:
			camera.offset = Vector2.ZERO

func apply_camera_impact(zoom_amount: float, shake_amount: float):
	zoom_strength = max(zoom_strength, zoom_amount)
	shake_strength = max(shake_strength, shake_amount)

func _play_finisher_sequence():
	if finisher_triggered: return
	finisher_triggered = true
	
	HitStopManager.stop_frame(1.5)
	
	# Visuals
	zoom_strength = 0.45
	shake_strength = 0.0 
	
	# --- CALL GLOBAL ---
	GlobalCinematics.apply_finisher_effect()

func _on_game_state_changed(new_state):
	if new_state == GameManager.State.POST_CLASH:
		_log_stat_changes()
		finisher_triggered = false
		
		# --- CALL GLOBAL ---
		GlobalCinematics.reset_visuals()

func _create_passive_toggles():
	var container = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	container.position.y -= 200
	container.position.x -= 570
	rage_toggle = CheckButton.new()
	rage_toggle.text = "RAGE (Pay HP)"
	rage_toggle.visible = false
	rage_toggle.toggled.connect(func(_on): _refresh_grid())
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
	tech_dropdown.item_selected.connect(func(_idx): _refresh_grid())
	container.add_child(tech_dropdown)
	
func setup_passive_toggles(character: CharacterData):
	rage_toggle.visible = character.can_pay_with_hp
	keep_up_toggle.visible = character.has_keep_up_toggle
	tech_dropdown.visible = character.has_technique_dropdown
	tech_dropdown.selected = 0 
	rage_toggle.button_pressed = false
	keep_up_toggle.button_pressed = false

func _create_debug_toggles():
	var container = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	container.position.y += 60 
	container.add_theme_constant_override("separation", 20)
	container.visible = false
	container.name = "DebugContainer" 
	
	var p1_is_human = true 
	var p2_is_human = false
	if not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		p2_is_human = true
	
	p1_toggle = CheckButton.new()
	p1_toggle.text = "P1 Human"
	p1_toggle.toggled.connect(func(on): emit_signal("p1_mode_toggled", on))
	p1_toggle.button_pressed = p1_is_human 
	container.add_child(p1_toggle)
	
	p2_toggle = CheckButton.new()
	p2_toggle.text = "P2 Human"
	p2_toggle.toggled.connect(func(on): emit_signal("p2_mode_toggled", on))
	p2_toggle.button_pressed = p2_is_human
	container.add_child(p2_toggle)

func initialize_hud(p1_data: CharacterData, p2_data: CharacterData):
	p1_hud.setup(p1_data)
	p2_hud.setup(p2_data)
	p1_hud.configure_visuals(false) 
	p2_hud.configure_visuals(true)
	update_momentum(0)
	
	_populate_equipment(p1_data)

func update_all_visuals(p1: CharacterData, p2: CharacterData, momentum: int):
	p1_hud.update_stats(p1, GameManager.p1_opportunity_stat, GameManager.p1_opening_stat, p1.patient_buff_active)
	p2_hud.update_stats(p2, GameManager.p2_opportunity_stat, GameManager.p2_opening_stat, p2.patient_buff_active)
	
	update_momentum(momentum)
	$MomentumSlider/Label2.text = str(GameManager.momentum)

func update_momentum(val: int):
	var visual_val = val
	var text = "NEUTRAL: " + GameManager.current_environment_name
	if val == 0: 
		visual_val = float(GameManager.TOTAL_MOMENTUM_SLOTS) / 2.0 + 0.5
	elif val <= GameManager.MOMENTUM_P1_MAX: 
		text = "P1 MOMENTUM"
	else: 
		text = "P2 MOMENTUM"
		
	var tween = create_tween()
	tween.tween_property(momentum_slider, "value", visual_val, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if momentum_label: momentum_label.text = text

func load_deck(deck: Array[ActionData]):
	current_deck = deck
	_refresh_grid()

func unlock_for_input(forced_tab, player_current_sp: int, player_current_hp: int, must_be_opener: bool = false, max_cost: int = 99, opening_val: int = 0, can_use_super: bool = false, opportunity_val: int = 0, is_feint_mode: bool = false):
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
	
	if forced_tab != null:
		_switch_tab(forced_tab)
		btn_offence.disabled = (forced_tab != ActionData.Type.OFFENCE)
		btn_defence.disabled = (forced_tab != ActionData.Type.DEFENCE)
		btn_offence.modulate = Color.WHITE if !btn_offence.disabled else Color(0.3, 0.3, 0.3)
		btn_defence.modulate = Color.WHITE if !btn_defence.disabled else Color(0.3, 0.3, 0.3)
	else:
		btn_offence.disabled = false
		btn_defence.disabled = false
		_switch_tab(current_tab)

func lock_ui():
	is_locked = true
	button_grid.visible = false 
	_on_card_exited() 

func _on_card_selected(card: ActionData):
	if is_locked: return
	var extra_data = {
		"rage": rage_toggle.button_pressed if rage_toggle.visible else false,
		"keep_up": keep_up_toggle.button_pressed if keep_up_toggle.visible else false,
		"technique": tech_dropdown.selected if tech_dropdown.visible else 0 
	}
	emit_signal("human_selected_card", card, extra_data)
	lock_ui() 

func _switch_tab(type):
	current_tab = type
	_refresh_grid()
	if !btn_offence.disabled: btn_offence.modulate = Color.WHITE if type == ActionData.Type.OFFENCE else Color(0.6, 0.6, 0.6)
	if !btn_defence.disabled: btn_defence.modulate = Color.WHITE if type == ActionData.Type.DEFENCE else Color(0.6, 0.6, 0.6)

func _refresh_grid():
	for child in button_grid.get_children():
		child.queue_free()
		
	# 1. Standard Deck Cards
	for card in current_deck:
		if card == null: continue
		if card.type != current_tab: continue 
		
		var final_cost = _calculate_card_cost(card)
		var is_valid = _check_card_validity(card, final_cost)
		
		var btn = card_button_scene.instantiate()
		button_grid.add_child(btn)
		
		btn.setup(card)
		btn.update_cost_display(final_cost) 
		btn.set_available(is_valid)          
	
		btn.card_hovered.connect(_on_card_hovered)
		btn.card_exited.connect(_on_card_exited) 
		btn.card_selected.connect(_on_card_selected)
	
	# 2. Tutorial Struggle Logic
	var hide_struggle = false
	if TutorialManager.is_tutorial_active:
		var required_card_name = TutorialManager.get_current_data().get("player_card", "")
		
		# If the tutorial wants you to play Struggle, we only show it on the correct tab
		if required_card_name == "Struggle":
			# If the current tab (Offence/Defence) doesn't match the card's required type, hide it
			# This prevents Struggle (Offence) from showing up on the Defence tab
			pass 
		else:
			# If the tutorial wants any other specific card, hide Struggle everywhere
			hide_struggle = true
	
	# 3. Struggle Button instantiation
	if not feint_mode and not hide_struggle:
		var struggle = GameManager.get_struggle_action(current_tab)
		var s_btn = card_button_scene.instantiate()
		button_grid.add_child(s_btn)
		
		s_btn.setup(struggle)
		s_btn.update_cost_display(0)
		s_btn.set_available(true)
		s_btn.modulate = Color(0.9, 0.9, 0.9) 

		s_btn.card_hovered.connect(_on_card_hovered)
		s_btn.card_exited.connect(_on_card_exited)
		s_btn.card_selected.connect(_on_card_selected)
	
	# 4. Skip Feint logic
	if feint_mode:
		skip_action.type = current_tab 
		var skip_btn = card_button_scene.instantiate()
		button_grid.add_child(skip_btn)
		
		skip_btn.setup(skip_action)
		skip_btn.update_cost_display(0)
		skip_btn.set_available(true)
		skip_btn.modulate = Color(0.9, 0.9, 1.0) 
		
		skip_btn.card_hovered.connect(_on_card_hovered)
		skip_btn.card_exited.connect(_on_card_exited)
		skip_btn.card_selected.connect(_on_card_selected)

func _calculate_card_cost(card: ActionData) -> int:
	var tech_idx = tech_dropdown.selected if tech_dropdown.visible else 0
	var tech_cost = 1 if tech_idx > 0 else 0
	var base_cost = card.cost + tech_cost
	var effective_single_cost = max(0, base_cost - my_opportunity_val)
	var total_reps = max(1, card.repeat_count)
	return effective_single_cost * total_reps

func _check_card_validity(card: ActionData, final_cost: int) -> bool:
	var can_afford = false
	if rage_toggle.visible and rage_toggle.button_pressed:
		can_afford = (current_hp_limit > final_cost)
	else:
		can_afford = (final_cost <= current_sp_limit)
	
	if not can_afford: return false

	var tech_idx = tech_dropdown.selected if tech_dropdown.visible else 0
	if tech_idx == 1 and card.type == ActionData.Type.DEFENCE:
		return false

	var effective_is_opener = card.is_opener
	if tech_idx == 1 and card.type == ActionData.Type.OFFENCE:
		effective_is_opener = true
		
	if opener_restriction and card.type == ActionData.Type.OFFENCE and not effective_is_opener:
		return false

	if card.cost > turn_cost_limit: return false
	if card.counter_value > 0 and my_opening_value < card.counter_value: return false
	if card.is_super and not super_allowed: return false
	
	# --- NEW: TUTORIAL RAILROAD ---
	if TutorialManager.is_tutorial_active:
		var required_card = TutorialManager.get_current_data().get("player_card", "")
		# If this card isn't the exact one the Sensei asked for, disable it!
		if required_card != "" and card.display_name != required_card:
			return false
	# ------------------------------
	
	return true

func _on_card_hovered(card: ActionData):
	var effective_cost = max(0, card.cost - my_opportunity_val)
	preview_card.set_card_data(card, effective_cost)
	preview_card.visible = true
	_update_tooltip_text(card)

func _on_card_exited():
	preview_card.visible = false
	if tooltip_label: tooltip_label.visible = false

func _update_tooltip_text(card: ActionData):
	if not tooltip_label: return
	
	var active_keys = []
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
	
	for s in card.statuses_to_apply:
		var s_name = s.get("name", "")
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
		tooltip_label.visible = false
		return
		
	var full_text = ""
	for k in active_keys:
		if k in GameManager.KEYWORD_DEFS:
			full_text += "[b]" + k + ":[/b] " + GameManager.KEYWORD_DEFS[k] + "\n"
			
	tooltip_label.text = full_text
	tooltip_label.visible = true
	
	tooltip_label.size.y = 0 
	var padding = 20
	var preview_bottom = preview_card.position.y + preview_card.size.y
	tooltip_label.position.y = preview_bottom - tooltip_label.size.y - padding
	tooltip_label.position.x = preview_card.position.x - tooltip_label.size.x - padding

func _get_clash_text_pos(target_id: int) -> Vector2:
	var hud = p1_hud if target_id == 1 else p2_hud
	var pos = hud.global_position + (hud.size / 2)
	var center_offset = 100 
	pos.y += 75
	if target_id == 1: pos.x += center_offset
	else: pos.x -= center_offset
	return pos

func _on_damage_dealt(target_id: int, amount: int, is_blocked: bool):
	var spawn_pos = _get_clash_text_pos(target_id)
	if is_blocked: 
		_spawn_text(spawn_pos, "BLOCKED", Color.GRAY)
		AudioManager.play_sfx("block", 0.1)
	else: 
		_spawn_text(spawn_pos, str(amount), Color.RED)
		if amount >= 5:
			AudioManager.play_sfx("hit_heavy", 0.1)
			apply_camera_impact(0.15, 20.0) 
		else:
			AudioManager.play_sfx("hit_light", 0.2) 
			apply_camera_impact(0.05, 5.0)  
			
		if target_id == 1: p1_hud.play_hit_animation()
		else: p2_hud.play_hit_animation()
	
	# React to heavy hits (>3 damage)
	if amount >= 3:
		var victim = GameManager.p1_data if target_id == 1 else GameManager.p2_data
		var line = DialogueManager.get_reaction(victim.class_type, "HURT_HEAVY")
		# High priority: Show this even if we barked recently
		_show_bark(target_id, line)
		
	# React to Death?
	# (Already covered by Low HP lines potentially, or add a specific check here)
	
# --- NEW: CHECK FOR FINISHER ---
	var victim_data = GameManager.p1_data if target_id == 1 else GameManager.p2_data
	
	if victim_data.current_hp <= 0:
		_play_finisher_sequence()
		
		# --- ADD THIS BLOCK ---
		# 1. Wait for the freeze-frame/drama to finish (e.g. 2 seconds)
		# We use create_timer because the game might be in HitStop
		await get_tree().create_timer(2.0).timeout
		
		# 2. Fade the color back in smoothly
		if GlobalCinematics:
			GlobalCinematics.reset_visuals()
	# --------------------------------

func _on_healing_received(target_id: int, amount: int):
	var spawn_pos = _get_clash_text_pos(target_id)
	_spawn_text(spawn_pos, "+" + str(amount), Color.GREEN)

func _on_status_applied(target_id: int, status: String):
	var spawn_pos = _get_clash_text_pos(target_id)
	spawn_pos.y -= 40 
	_spawn_text(spawn_pos, status, Color.YELLOW)

func _spawn_text(pos: Vector2, text: String, color: Color):
	var popup = floating_text_scene.instantiate()
	add_child(popup)
	popup.setup(text, color, pos)

func _on_combat_log_updated(text: String):
	if combat_log: combat_log.add_log(text)

func _on_clash_resolved_log(winner_id, p1_card, p2_card, _log_text):
	if combat_log:
		combat_log.add_clash_log(winner_id, p1_card, p2_card)
		
	apply_camera_impact(0.02, 0.0) 
		
	if p1_card.type == ActionData.Type.OFFENCE:
		p1_hud.play_attack_animation(Vector2(50, 0))
	if p2_card.type == ActionData.Type.OFFENCE:
		p2_hud.play_attack_animation(Vector2(-50, 0))
		
	AudioManager.play_sfx("clash", 0.1)
	
	# 25% chance to bark on win (don't spam every turn)
	if randf() < 0.25:
		var winner_data = GameManager.p1_data if winner_id == 1 else GameManager.p2_data
		var winner_card = p1_card if winner_id == 1 else p2_card
		
		var context = "WIN_OFFENCE"
		if winner_card.type == ActionData.Type.DEFENCE:
			context = "WIN_DEFENCE"
			
		var line = DialogueManager.get_reaction(winner_data.class_type, context)
		_show_bark(winner_id, line)
	
func _on_log_toggled(toggled_on: bool):
	combat_log.visible = toggled_on

func play_clash_animation(p1_card: ActionData, p2_card: ActionData):
	clash_layer.visible = true
	left_card_display.set_card_data(p1_card)
	right_card_display.set_card_data(p2_card)
	
	var card_size = Vector2(250, 350) 
	left_card_display.custom_minimum_size = card_size
	left_card_display.size = card_size
	right_card_display.custom_minimum_size = card_size
	right_card_display.size = card_size
	
	left_card_display.pivot_offset = card_size / 2
	right_card_display.pivot_offset = card_size / 2
	left_card_display.scale = Vector2(1.0, 1.0)
	right_card_display.scale = Vector2(1.0, 1.0)
	
	var center = get_viewport().get_visible_rect().size / 2
	left_card_display.position.x = -400
	right_card_display.position.x = get_viewport().get_visible_rect().size.x + 400
	left_card_display.position.y = center.y - (card_size.y / 2)
	right_card_display.position.y = center.y - (card_size.y / 2)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(left_card_display, "position:x", center.x - card_size.x - 40, 0.4)
	tween.tween_property(right_card_display, "position:x", center.x + 20, 0.4)
	
	await tween.finished
	HitStopManager.stop_frame(0.15) 
	await get_tree().create_timer(1.2).timeout
	
	clash_layer.visible = false
	GameManager.clash_animation_finished.emit()

func _on_menu_pressed():
	var compendium = compendium_scene.instantiate()
	compendium.is_overlay = true
	add_child(compendium)

func setup_toggles(p1_override = null, p2_override = null):
	var container = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	container.position.y += 60 
	container.add_theme_constant_override("separation", 20)
	container.visible = false
	container.name = "DebugContainer"
	
	var p1_is_human = true 
	var p2_is_human = false
	
	if not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		p2_is_human = true
	
	if p1_override != null: p1_is_human = p1_override
	if p2_override != null: p2_is_human = p2_override
	
	p1_toggle = CheckButton.new()
	p1_toggle.text = "P1 Human"
	p1_toggle.toggled.connect(func(on): emit_signal("p1_mode_toggled", on))
	p1_toggle.button_pressed = p1_is_human 
	container.add_child(p1_toggle)
	
	p2_toggle = CheckButton.new()
	p2_toggle.text = "P2 Human"
	p2_toggle.toggled.connect(func(on): emit_signal("p2_mode_toggled", on))
	p2_toggle.button_pressed = p2_is_human
	container.add_child(p2_toggle)

func _log_stat_changes():
	if not combat_log or not GameManager.p1_data or not GameManager.p2_data: return
	
	var p1_cur = { "hp": GameManager.p1_data.current_hp, "sp": GameManager.p1_data.current_sp }
	var p2_cur = { "hp": GameManager.p2_data.current_hp, "sp": GameManager.p2_data.current_sp }
	
	if _prev_p1_stats.hp == 0 and _prev_p2_stats.hp == 0:
		_snapshot_stats()
		return
	
	var p1_diff = { "hp": p1_cur.hp - _prev_p1_stats.hp, "sp": p1_cur.sp - _prev_p1_stats.sp }
	var p2_diff = { "hp": p2_cur.hp - _prev_p2_stats.hp, "sp": p2_cur.sp - _prev_p2_stats.sp }
	
	combat_log.add_round_summary(p1_diff, p2_diff, GameManager.momentum)
	_snapshot_stats()

func _snapshot_stats():
	if GameManager.p1_data:
		_prev_p1_stats = { "hp": GameManager.p1_data.current_hp, "sp": GameManager.p1_data.current_sp }
	if GameManager.p2_data:
		_prev_p2_stats = { "hp": GameManager.p2_data.current_hp, "sp": GameManager.p2_data.current_sp }

func _on_wall_crush_ui(target_id: int, _dmg: int):
	apply_camera_impact(0.05, 15.0) 
	var original_x = momentum_slider.position.x
	var tween = create_tween()
	var shake_dir = -10 if target_id == 1 else 10
	tween.tween_property(momentum_slider, "position:x", original_x + shake_dir, 0.05)
	tween.tween_property(momentum_slider, "position:x", original_x, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_env_button_pressed():
	env_popup.visible = not env_popup.visible
	if env_popup.visible:
		env_title.text = "ENVIRONMENT: " + GameManager.current_environment_name.to_upper()
		var details = "[b]Momentum Tracker:[/b] " + str(GameManager.TOTAL_MOMENTUM_SLOTS) + " Slots\n"
		env_details.text = details

func _populate_equipment(p1_data: CharacterData):
	if not equipment_grid: return
	for child in equipment_grid.get_children():
		child.queue_free()
	for item in p1_data.equipment:
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if item.icon: icon.texture = item.icon
		else: icon.texture = preload("res://icon.svg") 
		var tip = item.display_name + "\n" + item.description + "\n"
		tip += "-------------------\n"
		if item.max_hp_bonus != 0: tip += "Max HP: " + ("+" if item.max_hp_bonus > 0 else "") + str(item.max_hp_bonus) + "\n"
		if item.max_sp_bonus != 0: tip += "Max SP: " + ("+" if item.max_sp_bonus > 0 else "") + str(item.max_sp_bonus) + "\n"
		if item.starting_sp_bonus != 0: tip += "Start SP: +" + str(item.starting_sp_bonus) + "\n"
		if item.wall_crush_damage_bonus != 0: tip += "Wall Crush Dmg: +" + str(item.wall_crush_damage_bonus)
		icon.tooltip_text = tip 
		equipment_grid.add_child(icon)

func _on_inspect_pressed():
	inspect_popup.visible = not inspect_popup.visible
	if inspect_popup.visible:
		inspect_btn.text = "CLOSE INSPECT"
		_populate_enemy_deck()
	else:
		inspect_btn.text = "INSPECT OPPONENT"

func _populate_enemy_deck():
	for child in inspect_grid.get_children():
		child.queue_free()
	var p2 = GameManager.p2_data
	if not p2: return
	for card in p2.deck:
		var card_disp = card_display_scene.instantiate()
		inspect_grid.add_child(card_disp)
		card_disp.set_card_data(card)
		card_disp.custom_minimum_size = Vector2(180, 250)
		card_disp.scale = Vector2(0.8, 0.8) 
		card_disp.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.1))

# Helper to safely tween shader params
func _set_bg_saturation(val: float):
	if background and background.material:
		background.material.set_shader_parameter("saturation", val)

func _update_background():
	var env_name = GameManager.current_environment_name
	if GameManager.environment_backgrounds.has(env_name):
		background.texture = GameManager.environment_backgrounds[env_name]
	else:
		print("Warning: No art found for '" + env_name + "'. Using default.")

func _show_bark(player_id: int, text: String):
	var lbl = p1_bark_label if player_id == 1 else p2_bark_label
	lbl.text = text
	
	# Simple Pop-in Animation
	lbl.modulate.a = 0
	lbl.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tween.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
	
	# Wait, then fade out
	tween.chain().tween_interval(1.5)
	tween.chain().tween_property(lbl, "modulate:a", 0.0, 0.3)

func _exit_tree():
	if GlobalCinematics:
		GlobalCinematics.reset_visuals()
