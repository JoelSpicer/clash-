extends CanvasLayer

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

@onready var log_toggle = $LogToggle 

# --- DATA ---
var card_button_scene = preload("res://Scenes/CardButton.tscn")
var floating_text_scene = preload("res://Scenes/FloatingText.tscn")
var compendium_scene = preload("res://Scenes/Compendium.tscn")
var current_deck: Array[ActionData] = []
var current_tab = ActionData.Type.OFFENCE

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

# Toggle Buttons
var p1_toggle: CheckButton
var p2_toggle: CheckButton

# --- NEW VARIABLES ---
var rage_toggle: CheckButton
var keep_up_toggle: CheckButton
var tech_dropdown: OptionButton
var shake_strength: float = 0.0
var shake_decay: float = 5.0

func _ready():
	if not btn_offence or not btn_defence:
		printerr("CRITICAL: Buttons missing in BattleUI")
		return
	
	if clash_layer: clash_layer.visible = false
	
	log_toggle.button_pressed = false
	combat_log.visible = false
	
	if log_toggle:
		log_toggle.toggled.connect(_on_log_toggled)
		# Sync the log visibility to the button's starting state
		combat_log.visible = log_toggle.button_pressed
	
	btn_offence.pressed.connect(func(): _switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func(): _switch_tab(ActionData.Type.DEFENCE))
	
	# Skip Action Init
	skip_action = ActionData.new()
	skip_action.display_name = "SKIP FEINT"
	skip_action.description = "Stop combining and use your original action."
	skip_action.cost = 0
	
	# Initially hide input grid
	button_grid.visible = false
	preview_card.visible = false
	if tooltip_label: tooltip_label.visible = false
	
	# Connect Visual Signals
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.healing_received.connect(_on_healing_received)
	GameManager.status_applied.connect(_on_status_applied)	
	GameManager.combat_log_updated.connect(_on_combat_log_updated)
	GameManager.damage_dealt.connect(_on_damage_shake)
	
	_create_debug_toggles()
	_create_passive_toggles() # Add this new function call
	setup_toggles()
	
	var btn = get_node_or_null("MenuButton")
	if btn:
		btn.pressed.connect(_on_menu_pressed)

func _process(delta):
	# This applies the shake to the entire UI Layer
	if shake_strength > 0:
		shake_strength = lerpf(shake_strength, 0, shake_decay * delta)
		
		# Apply random offset to the CanvasLayer
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		offset = Vector2.ZERO

func _create_passive_toggles():
	var container = HBoxContainer.new()
	add_child(container)
	# Position this near the card grid or bottom of screen
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	container.position.y -= 200
	container.position.x -= 570
	rage_toggle = CheckButton.new()
	rage_toggle.text = "RAGE (Pay HP)"
	rage_toggle.visible = false
	rage_toggle.toggled.connect(func(_on): _refresh_grid()) # Refresh card availability when clicked
	container.add_child(rage_toggle)
	
	keep_up_toggle = CheckButton.new()
	keep_up_toggle.text = "KEEP UP (Pay SP)"
	keep_up_toggle.visible = false
	# No refresh needed for Keep Up as it doesn't change card playability, only resolution
	container.add_child(keep_up_toggle)
	
	# --- ADD THIS BLOCK ---
	tech_dropdown = OptionButton.new()
	tech_dropdown.add_item("Tech: None")
	tech_dropdown.add_item("+Opener (1 SP)")
	tech_dropdown.add_item("+Tiring 1 (1 SP)")
	tech_dropdown.add_item("+Momentum 1 (1 SP)")
	tech_dropdown.selected = 0
	tech_dropdown.visible = false
	# Refresh grid when selection changes to update costs/validity
	tech_dropdown.item_selected.connect(func(_idx): _refresh_grid())
	container.add_child(tech_dropdown)
	
# Helper to set correct toggle visibility (Call this from TestArena)
func setup_passive_toggles(class_type: CharacterData.ClassType):
	rage_toggle.visible = (class_type == CharacterData.ClassType.HEAVY)
	keep_up_toggle.visible = (class_type == CharacterData.ClassType.PATIENT)
	tech_dropdown.visible = (class_type == CharacterData.ClassType.TECHNICAL)
	tech_dropdown.selected = 0 # Always reset to "None" at start of turn
	
	# Reset them to false at start of turn? Or keep them? Usually reset is safer.
	rage_toggle.button_pressed = false
	keep_up_toggle.button_pressed = false

func _create_debug_toggles():
	var container = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	container.position.y += 60 
	container.add_theme_constant_override("separation", 20)
	
	# 1. HIDE FOR DEBUG PURPOSES
	# (Change to true if you need to see them for testing)
	container.visible = false
	container.name = "DebugContainer" # Named so you can find it in Remote view
	
	# 2. CALCULATE INITIAL STATES
	# P1 is always Human by default
	var p1_is_human = true 
	
	# P2 is Human only if we are NOT in Arcade Mode AND we selected "Opponent: Player 2"
	var p2_is_human = false
	if not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		p2_is_human = true
	
	# 3. CREATE P1 TOGGLE
	p1_toggle = CheckButton.new()
	p1_toggle.text = "P1 Human"
	p1_toggle.toggled.connect(func(on): emit_signal("p1_mode_toggled", on))
	
	# Set state (Godot emits "toggled" signal automatically when this changes from default)
	p1_toggle.button_pressed = p1_is_human 
	container.add_child(p1_toggle)
	
	# 4. CREATE P2 TOGGLE
	p2_toggle = CheckButton.new()
	p2_toggle.text = "P2 Human"
	p2_toggle.toggled.connect(func(on): emit_signal("p2_mode_toggled", on))
	
	# Set state based on menu selection
	p2_toggle.button_pressed = p2_is_human
	container.add_child(p2_toggle)

# --- VISUAL UPDATE FUNCTIONS ---

func initialize_hud(p1_data: CharacterData, p2_data: CharacterData):
	p1_hud.setup(p1_data)
	p2_hud.setup(p2_data)
	update_momentum(0) 

func update_all_visuals(p1: CharacterData, p2: CharacterData, momentum: int):
	p1_hud.update_stats(p1, GameManager.p1_is_injured, GameManager.p1_opportunity_stat, GameManager.p1_opening_stat)
	p2_hud.update_stats(p2, GameManager.p2_is_injured, GameManager.p2_opportunity_stat, GameManager.p2_opening_stat)
	update_momentum(momentum)

func update_momentum(val: int):
	var visual_val = val
	var text = "NEUTRAL"
	if val == 0: visual_val = 4.5 
	elif val <= 4: text = "P1 MOMENTUM"
	else: text = "P2 MOMENTUM"
		
	var tween = create_tween()
	tween.tween_property(momentum_slider, "value", visual_val, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if momentum_label: momentum_label.text = text

# --- INPUT HANDLING ---

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
	_on_card_exited() # Clean up tooltips when locking

func _on_card_selected(card: ActionData):
	if is_locked: return
	# --- NEW: GATHER TOGGLE DATA ---
	var extra_data = {
		"rage": rage_toggle.button_pressed if rage_toggle.visible else false,
		"keep_up": keep_up_toggle.button_pressed if keep_up_toggle.visible else false,
		"technique": tech_dropdown.selected if tech_dropdown.visible else 0 # <--- SEND SELECTION
	}
	emit_signal("human_selected_card", card, extra_data)
	lock_ui() 

func _switch_tab(type):
	current_tab = type
	_refresh_grid()
	if !btn_offence.disabled: btn_offence.modulate = Color.WHITE if type == ActionData.Type.OFFENCE else Color(0.6, 0.6, 0.6)
	if !btn_defence.disabled: btn_defence.modulate = Color.WHITE if type == ActionData.Type.DEFENCE else Color(0.6, 0.6, 0.6)

# 1. THE UI MANAGER (Clean and readable)
func _refresh_grid():
	# Clear existing buttons
	for child in button_grid.get_children():
		child.queue_free()
		
	# Loop through deck
	for card in current_deck:
		if card == null: continue
		if card.type != current_tab: continue # Skip cards from the wrong tab
		
		# --- STEP 1: CALCULATE NUMBERS ---
		# We ask a helper function to do the math
		var final_cost = _calculate_card_cost(card)
		
		# --- STEP 2: CHECK RULES ---
		# We ask a helper function if this play is legal
		var is_valid = _check_card_validity(card, final_cost)
		
		# --- STEP 3: UPDATE UI ---
		var btn = card_button_scene.instantiate()
		button_grid.add_child(btn)
		
		btn.setup(card)
		btn.update_cost_display(final_cost) # Show the calculated cost
		btn.set_available(is_valid)         # Grey out if invalid
		
		# Connect signals
		btn.card_hovered.connect(_on_card_hovered)
		btn.card_exited.connect(_on_card_exited) 
		btn.card_selected.connect(_on_card_selected)

	# (Keep your existing Feint/Skip button logic here at the bottom)
	if feint_mode:
		# Assuming _create_skip_button() is your existing logic for the skip button,
		# or paste your original skip button code block here.
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

# 2. THE MATH HELPER
func _calculate_card_cost(card: ActionData) -> int:
	var tech_idx = tech_dropdown.selected if tech_dropdown.visible else 0
	
	# 1. Determine Base Cost (Card + Tech Modifier)
	# We add the Tech cost BEFORE the discount to match GameManager logic
	var tech_cost = 1 if tech_idx > 0 else 0
	var base_cost = card.cost + tech_cost
	
	# 2. Apply "Opportunity" Discount
	var effective_single_cost = max(0, base_cost - my_opportunity_val)
	
	# 3. Multiply by Repeats (THE FIX)
	# If a card repeats 3 times, you must pay for all 3 upfront.
	var total_reps = max(1, card.repeat_count)
	
	return effective_single_cost * total_reps

# 3. THE RULE REFEREE (Returns True/False if playable)
func _check_card_validity(card: ActionData, final_cost: int) -> bool:
	# A. AFFORDABILITY CHECK
	var can_afford = false
	if rage_toggle.visible and rage_toggle.button_pressed:
		# Heavy Class: Pay with HP
		can_afford = (current_hp_limit > final_cost)
	else:
		# Standard: Pay with SP
		can_afford = (final_cost <= current_sp_limit)
	
	if not can_afford: return false

	# B. TECHNIQUE RESTRICTIONS (Technical Class)
	var tech_idx = tech_dropdown.selected if tech_dropdown.visible else 0
	# Rule: "Opener" tech can only be applied to OFFENCE cards
	if tech_idx == 1 and card.type == ActionData.Type.DEFENCE:
		return false

	# C. OPENER CHECK
	var effective_is_opener = card.is_opener
	# Tech Rule: If "Opener" tech (Index 1) is selected, card BECOMES an opener
	if tech_idx == 1 and card.type == ActionData.Type.OFFENCE:
		effective_is_opener = true
		
	# Game Rule: If 'opener_restriction' is active (e.g. start of combo), 
	# you MUST play an opener.
	if opener_restriction and card.type == ActionData.Type.OFFENCE and not effective_is_opener:
		return false

	# D. SITUATIONAL CHECKS
	# Multi-Hit Limit: Opponent limited our max cost
	if card.cost > turn_cost_limit: return false
	
	# Counter: Requires opponent to have created an opening
	if card.counter_value > 0 and my_opening_value < card.counter_value: return false
	
	# Super: Can only use if momentum meter is full
	if card.is_super and not super_allowed: return false

	return true

# --- TOOLTIP LOGIC ---

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
	
	# Core Type
	if card.type == ActionData.Type.OFFENCE: active_keys.append("Offence")
	if card.type == ActionData.Type.DEFENCE: active_keys.append("Defence")
	
	# Basic Stats
	if card.cost > 0: active_keys.append("Cost")
	if card.damage > 0: active_keys.append("Damage")
	if card.momentum_gain > 0: active_keys.append("Momentum")
	
	# Combat Values
	if card.block_value > 0: active_keys.append("Block")
	if card.dodge_value > 0: active_keys.append("Dodge")
	if card.heal_value > 0: active_keys.append("Heal")
	if card.recover_value > 0: active_keys.append("Recover")
	if card.fall_back_value > 0: active_keys.append("Fall Back")
	if card.counter_value > 0: active_keys.append("Counter")
	if card.tiring > 0: active_keys.append("Tiring")
	
	# Booleans
	if card.is_opener: active_keys.append("Opener")
	if card.is_super: active_keys.append("Super")
	if card.guard_break: active_keys.append("Guard Break")
	if card.feint: active_keys.append("Ditto")
	if card.injure: active_keys.append("Injure")
	if card.retaliate: active_keys.append("Retaliate")
	if card.reversal: active_keys.append("Reversal")
	if card.is_parry: active_keys.append("Parry")
	if card.sweep: active_keys.append("Sweep")
	
	# Advanced
	if card.multi_limit > 0: active_keys.append("Multi")
	if card.repeat_count > 1: active_keys.append("Repeat")
	if card.create_opening > 0: active_keys.append("Create Opening")
	if card.opportunity > 0: active_keys.append("Opportunity")
	
	if active_keys.is_empty():
		tooltip_label.visible = false
		return
		
	# Build Text
	var full_text = ""
	for k in active_keys:
		if k in GameManager.KEYWORD_DEFS:
			full_text += "[b]" + k + ":[/b] " + GameManager.KEYWORD_DEFS[k] + "\n"
			
	tooltip_label.text = full_text
	tooltip_label.visible = true
	
	# --- POSITIONING LOGIC ---
	
	# 1. Force size update so calculations are accurate
	tooltip_label.size.y = 0 
	var padding = 20
	# 2. Calculate Vertical Position (Grow Upwards)
	# We align the BOTTOM of the tooltip with the BOTTOM of the card
	var preview_bottom = preview_card.position.y + preview_card.size.y
	tooltip_label.position.y = preview_bottom - tooltip_label.size.y - padding
	
	# 3. Calculate Horizontal Position (Place on RIGHT)
	# Formula: Card X Position + Card Width + Padding
	tooltip_label.position.x = preview_card.position.x - tooltip_label.size.x - padding

# --- VISUAL HANDLERS (Floating Text etc) ---

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
	if is_blocked: _spawn_text(spawn_pos, "BLOCKED", Color.GRAY)
	else: _spawn_text(spawn_pos, str(amount), Color.RED)

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

func _on_log_toggled(toggled_on: bool):
	combat_log.visible = toggled_on

# BattleUI.gd

@onready var clash_layer = $ClashLayer # Make sure you created this node
@onready var left_card_display = $ClashLayer/LeftCard # Assign these in editor
@onready var right_card_display = $ClashLayer/RightCard

func play_clash_animation(p1_card: ActionData, p2_card: ActionData):
	clash_layer.visible = true
	
	# 1. Setup Data
	left_card_display.set_card_data(p1_card)
	right_card_display.set_card_data(p2_card)
	
	# --- FIX START: FORCE SIZE & PIVOT ---
	# Force standard card size (Portrait)
	var card_size = Vector2(250, 350) 
	
	left_card_display.custom_minimum_size = card_size
	left_card_display.size = card_size
	
	right_card_display.custom_minimum_size = card_size
	right_card_display.size = card_size
	
	# Set Pivot to center so they scale/rotate from the middle, not top-left
	left_card_display.pivot_offset = card_size / 2
	right_card_display.pivot_offset = card_size / 2
	
	# Reset Scale (Try 1.0, or 1.2 for big impact)
	left_card_display.scale = Vector2(1.0, 1.0)
	right_card_display.scale = Vector2(1.0, 1.0)
	# --- FIX END ---
	
	# 2. Reset Positions (Off-screen)
	var center = get_viewport().get_visible_rect().size / 2
	
	# Start far left/right
	left_card_display.position.x = -400
	right_card_display.position.x = get_viewport().get_visible_rect().size.x + 400
	
	# Center Y (adjusted for pivot)
	left_card_display.position.y = center.y - (card_size.y / 2)
	right_card_display.position.y = center.y - (card_size.y / 2)
	
	# 3. Animate Slam
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	
	# Move to center (Target positions)
	# Left card stops slightly left of center
	tween.tween_property(left_card_display, "position:x", center.x - card_size.x - 40, 0.4)
	# Right card stops slightly right of center
	tween.tween_property(right_card_display, "position:x", center.x + 20, 0.4)
	
	# Add a little shake/scale punch on impact
	await tween.finished
	HitStopManager.stop_frame(0.15) 
	
	# Hold for reading
	await get_tree().create_timer(1.2).timeout
	
	# Fade out
	clash_layer.visible = false
	GameManager.clash_animation_finished.emit()

func _on_damage_shake(_target, amount, is_blocked):
	# The higher the damage, the harder the shake
	if is_blocked:
		shake_strength = 2.0 
	else:
		shake_strength = float(amount) * 5.0 # Increased multiplier for visibility


func _on_menu_pressed():
	# 3. Create the Compendium
	var compendium = compendium_scene.instantiate()
	
	# 4. Configure it as an overlay
	compendium.is_overlay = true
	
	# 5. Add it to the UI (It will cover the screen)
	add_child(compendium)

# BattleUI.gd

# We add "= null" to make these arguments optional.
func setup_toggles(p1_override = null, p2_override = null):
	var container = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	container.position.y += 60 
	container.add_theme_constant_override("separation", 20)
	
	container.visible = false
	container.name = "DebugContainer"
	
	# 1. DEFAULT LOGIC (Automatic)
	var p1_is_human = true 
	var p2_is_human = false
	
	if not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		p2_is_human = true
	
	# 2. OVERRIDE LOGIC (If TestArena passed specific values, use them)
	if p1_override != null:
		p1_is_human = p1_override
	
	if p2_override != null:
		p2_is_human = p2_override
	
	# 3. CREATE P1 TOGGLE
	p1_toggle = CheckButton.new()
	p1_toggle.text = "P1 Human"
	p1_toggle.toggled.connect(func(on): emit_signal("p1_mode_toggled", on))
	p1_toggle.button_pressed = p1_is_human 
	container.add_child(p1_toggle)
	
	# 4. CREATE P2 TOGGLE
	p2_toggle = CheckButton.new()
	p2_toggle.text = "P2 Human"
	p2_toggle.toggled.connect(func(on): emit_signal("p2_mode_toggled", on))
	p2_toggle.button_pressed = p2_is_human
	container.add_child(p2_toggle)
