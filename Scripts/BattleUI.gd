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

# --- DATA ---
var card_button_scene = preload("res://Scenes/CardButton.tscn")
var floating_text_scene = preload("res://Scenes/FloatingText.tscn")
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
# We send the state of these toggles along with the card

# --- KEYWORD DEFINITIONS ---
const KEYWORD_DEFS = {
	"Block": "Reduce incoming damage by X",
	"Cost": "lose X stamina",
	"Counter": "You must have used an action with Create Opening X or higher in the previous clash",
	"Create Opening": "Your opponent’s next action cannot have a Cost trait higher than X",
	"Damage": "Reduce your opponent’s health by X",
	"Defence": "Can only be used on the defensive. This action gains the Recover 1 trait. You must have the stamina require to use this action.",
	"Feint": "In addition to the action’s listed traits, it gains all the traits of another action that you can use. That action can be chosen after actions are revealed",
	"Dodge": "You ignore the effects of your opponent’s action if its stamina cost is X or below",
	"Fall Back": "Lose X momentum",
	"Guard Break": "Ignore the ‘Block X’ trait of your opponent’s action",
	"Heal": "Gain X HP",
	"Injure": "Your opponent must lose 1 HP every clash after this until you use an action with the Recover X, Heal X or Fall Back X traits, or the combat ends",
	"Momentum": "Gain X momentum",
	"Multi": "After this action, you may use any other action that has a Cost trait of X or below, and that does not have the multi X trait. This action interacts with your opponent’s previous action. If your opponent’s action would end your combo, you do not get to use this trait. In addition, moves with this trait can be used to start a combo",
	"Offence": "Can only be used on the offensive. If you are reduced to 0SP, your combo ends",
	"Opener": "Only actions with this trait can be used to start a combo",
	"Opportunity": "Increase your next actions momentum by X, and reduce its stamina cost by X",
	"Parry": "Your action steals the Momentum X trait of your opponent’s action. If this causes the momentum tracker to move in your direction, your opponent’s action has no affect on you, and your opponent’s next action must have the Opener trait",
	"Recover": "Gain X stamina",
	"Repeat": "After this action, use the same action again, ignoring the Repeat X trait. This must continue X times. This action interacts with your opponent’s chosen action as normal",
	"Retaliate": "Your opponent takes the same damage as they dealt to you in the previous clash",
	"Reversal": "If the momentum tracker moves closer to your side from this clash, the current combo ends and you take the offence, even if you do not have the momentum advantage. This applies even in the inital clash",
	"Super": "This action can only be used when the momentum tracker has reached the end of your side. You can only use an action with this trait once per combat",
	"Sweep": "This action affects all opponents you are in combat with",
	"Tiring": "Cause the opponent to lose X Stamina"
}

func _ready():
	if not btn_offence or not btn_defence:
		printerr("CRITICAL: Buttons missing in BattleUI")
		return

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
	
	_create_debug_toggles()
	_create_passive_toggles() # Add this new function call

func _create_passive_toggles():
	var container = HBoxContainer.new()
	add_child(container)
	# Position this near the card grid or bottom of screen
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	container.position.y -= 50 
	container.position.x -= 100 
	rage_toggle = CheckButton.new()
	rage_toggle.text = "RAGE (Pay HP)"
	rage_toggle.visible = false
	rage_toggle.toggled.connect(func(on): _refresh_grid()) # Refresh card availability when clicked
	container.add_child(rage_toggle)
	
	keep_up_toggle = CheckButton.new()
	keep_up_toggle.text = "KEEP UP (Pay SP)"
	keep_up_toggle.visible = false
	# No refresh needed for Keep Up as it doesn't change card playability, only resolution
	container.add_child(keep_up_toggle)
	
# Helper to set correct toggle visibility (Call this from TestArena)
func setup_passive_toggles(class_type: CharacterData.ClassType):
	rage_toggle.visible = (class_type == CharacterData.ClassType.HEAVY)
	keep_up_toggle.visible = (class_type == CharacterData.ClassType.PATIENT)
	
	# Reset them to false at start of turn? Or keep them? Usually reset is safer.
	rage_toggle.button_pressed = false
	keep_up_toggle.button_pressed = false

func _create_debug_toggles():
	var container = HBoxContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	container.position.y += 60 
	container.add_theme_constant_override("separation", 20)
	
	p1_toggle = CheckButton.new()
	p1_toggle.text = "P1 Human"
	p1_toggle.toggled.connect(func(on): emit_signal("p1_mode_toggled", on))
	container.add_child(p1_toggle)
	
	p2_toggle = CheckButton.new()
	p2_toggle.text = "P2 Human"
	p2_toggle.toggled.connect(func(on): emit_signal("p2_mode_toggled", on))
	container.add_child(p2_toggle)

func setup_toggles(p1_is_human: bool, p2_is_human: bool):
	if p1_toggle: p1_toggle.set_pressed_no_signal(p1_is_human)
	if p2_toggle: p2_toggle.set_pressed_no_signal(p2_is_human)

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
		"keep_up": keep_up_toggle.button_pressed if keep_up_toggle.visible else false
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
	
	for card in current_deck:
		if card == null: continue
		if card.type == current_tab:
			var btn = card_button_scene.instantiate()
			button_grid.add_child(btn)
			btn.setup(card)
			
			var effective_cost = max(0, card.cost - my_opportunity_val)
			btn.update_cost_display(effective_cost)
			
			# --- UPDATED AFFORDABILITY LOGIC ---
			var can_afford = false
			
			# If Rage is ON, we check HP instead of SP
			if rage_toggle.visible and rage_toggle.button_pressed:
				can_afford = (current_hp_limit > effective_cost)
			else:
				can_afford = (effective_cost <= current_sp_limit)
			# -----------------------------------
			var passes_opener = !(opener_restriction and card.type == ActionData.Type.OFFENCE and !card.is_opener)
			var passes_max_cost = (card.cost <= turn_cost_limit)
			var passes_counter = !(card.counter_value > 0 and my_opening_value < card.counter_value)
			var passes_super = !(card.is_super and !super_allowed)

			var is_valid = can_afford and passes_opener and passes_max_cost and passes_counter and passes_super
			btn.set_available(is_valid)
			
			btn.card_hovered.connect(_on_card_hovered)
			btn.card_exited.connect(_on_card_exited) 
			btn.card_selected.connect(_on_card_selected)

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
		if k in KEYWORD_DEFS:
			full_text += "[b]" + k + ":[/b] " + KEYWORD_DEFS[k] + "\n"
			
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
