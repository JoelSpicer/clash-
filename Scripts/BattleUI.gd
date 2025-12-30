extends CanvasLayer

signal human_selected_card(action_card)

# --- REFERENCES ---
@onready var p1_hud = $P1_HUD # Make sure you add these to the scene!
@onready var p2_hud = $P2_HUD
@onready var momentum_slider = $MomentumSlider
@onready var momentum_label = $MomentumSlider/Label # Optional text display

@onready var button_grid = %ButtonGrid
@onready var preview_card = %PreviewCard
@onready var btn_offence = %Offence        
@onready var btn_defence = %Defence       

# --- DATA ---
var card_button_scene = preload("res://Scenes/CardButton.tscn")
var floating_text_scene = preload("res://Scenes/FloatingText.tscn")
var current_deck: Array[ActionData] = []
var current_tab = ActionData.Type.OFFENCE

# State Constraints
var current_sp_limit: int = 0 
var my_opportunity_val: int = 0
var my_opening_value: int = 0
var turn_cost_limit: int = 99 
var opener_restriction: bool = false
var super_allowed: bool = false 
var feint_mode: bool = false 

var skip_action: ActionData
var is_locked = false

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
	
	# Initially hide input grid, but keep HUDs visible
	button_grid.visible = false
	preview_card.visible = false
	
	# Connect Visual Signals
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.healing_received.connect(_on_healing_received)
	GameManager.status_applied.connect(_on_status_applied)	

# --- NEW: VISUAL UPDATE FUNCTIONS ---

func initialize_hud(p1_data: CharacterData, p2_data: CharacterData):
	p1_hud.setup(p1_data)
	p2_hud.setup(p2_data)
	update_momentum(0) # Neutral

func update_all_visuals(p1: CharacterData, p2: CharacterData, momentum: int):
	# Fetch Game State directly from GameManager globals would be cleaner,
	# but passing them in is safer for decoupling.
	
	# We need access to status effects. 
	# Ideally, CharacterData should hold 'is_injured', but currently GameManager holds it.
	# For now, we will read from GameManager static instance or pass args.
	
	p1_hud.update_stats(p1, GameManager.p1_is_injured, GameManager.p1_opportunity_stat, GameManager.p1_opening_stat)
	p2_hud.update_stats(p2, GameManager.p2_is_injured, GameManager.p2_opportunity_stat, GameManager.p2_opening_stat)
	
	update_momentum(momentum)

func update_momentum(val: int):
	# If 0, maybe center it? Or map 0 -> 4.5?
	# Let's map logical momentum (1-8) to slider (1-8). 
	# If 0 (Neutral), we visualy place it in the middle.
	
	var visual_val = val
	var text = "NEUTRAL " + str(val)
	
	if val == 0: 
		visual_val = 4.5 # Sits between P1 and P2
	elif val <= 4:
		text = "P1 MOMENTUM " + str(val)
	else:
		text = "P2 MOMENTUM " + str(val)
		
	# Tween the slider for smooth movement
	var tween = create_tween()
	tween.tween_property(momentum_slider, "value", visual_val, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if momentum_label: momentum_label.text = text

# --- INPUT HANDLING (Existing Logic) ---

func load_deck(deck: Array[ActionData]):
	current_deck = deck
	_refresh_grid()

func unlock_for_input(forced_tab, player_current_sp: int, must_be_opener: bool = false, max_cost: int = 99, opening_val: int = 0, can_use_super: bool = false, opportunity_val: int = 0, is_feint_mode: bool = false):
	button_grid.visible = true # Show grid
	is_locked = false
	current_sp_limit = player_current_sp
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

	print("[UI] Input Unlocked.")

func lock_ui():
	is_locked = true
	button_grid.visible = false 
	preview_card.visible = false

func _on_card_selected(card: ActionData):
	if is_locked: return
	emit_signal("human_selected_card", card)
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
		if card.type == current_tab:
			var btn = card_button_scene.instantiate()
			button_grid.add_child(btn)
			btn.setup(card)
			
			var effective_cost = max(0, card.cost - my_opportunity_val)
			btn.update_cost_display(effective_cost)
			
			var can_afford = (effective_cost <= current_sp_limit)
			var passes_opener = !(opener_restriction and card.type == ActionData.Type.OFFENCE and !card.is_opener)
			var passes_max_cost = (card.cost <= turn_cost_limit)
			var passes_counter = !(card.counter_value > 0 and my_opening_value < card.counter_value)
			var passes_super = !(card.is_super and !super_allowed)

			var is_valid = can_afford and passes_opener and passes_max_cost and passes_counter and passes_super
			btn.set_available(is_valid)
			
			btn.card_hovered.connect(_on_card_hovered)
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
		skip_btn.card_selected.connect(_on_card_selected)

func _on_card_hovered(card: ActionData):
	var effective_cost = max(0, card.cost - my_opportunity_val)
	preview_card.set_card_data(card, effective_cost)
	preview_card.visible = true
	
# --- VISUAL HANDLERS ---

# NEW Helper: Calculates a position slightly offset towards the center of the screen
func _get_clash_text_pos(target_id: int) -> Vector2:
	var hud = p1_hud if target_id == 1 else p2_hud
	var pos = hud.global_position + (hud.size / 2)
	
	# The Shift Amount (How far to push text towards the center)
	var center_offset = 100 
	pos.y += 75
	if target_id == 1:
		# P1 is on the Left, so push text Right (+)
		pos.x += center_offset
	else:
		# P2 is on the Right, so push text Left (-)
		pos.x -= center_offset
		
	return pos

func _on_damage_dealt(target_id: int, amount: int, is_blocked: bool):
	# Use the new helper for position
	var spawn_pos = _get_clash_text_pos(target_id)
	
	if is_blocked:
		_spawn_text(spawn_pos, "BLOCKED", Color.GRAY)
	else:
		_spawn_text(spawn_pos, str(amount), Color.RED)

func _on_healing_received(target_id: int, amount: int):
	var spawn_pos = _get_clash_text_pos(target_id)
	_spawn_text(spawn_pos, "+" + str(amount), Color.GREEN)

func _on_status_applied(target_id: int, status: String):
	var spawn_pos = _get_clash_text_pos(target_id)
	# Spawn status slightly higher so it doesn't overlap damage numbers
	spawn_pos.y -= 40 
	_spawn_text(spawn_pos, status, Color.YELLOW)

func _spawn_text(pos: Vector2, text: String, color: Color):
	var popup = floating_text_scene.instantiate()
	add_child(popup)
	popup.setup(text, color, pos)
