extends CanvasLayer

signal human_selected_card(action_card)

# References
@onready var button_grid = %ButtonGrid
@onready var preview_card = %PreviewCard
@onready var btn_offence = %Offence        
@onready var btn_defence = %Defence       

var card_button_scene = preload("res://Scenes/CardButton.tscn")
var current_deck: Array[ActionData] = []
var current_tab = ActionData.Type.OFFENCE

var super_allowed: bool = false # NEW

var current_sp_limit: int = 0 
var opener_restriction: bool = false
var turn_cost_limit: int = 99 # Replaces cost_limit_from_opponent
var my_opening_value: int = 0

var is_locked = false

func _ready():
	if not btn_offence or not btn_defence:
		printerr("CRITICAL ERROR: Buttons not found!")
		return

	btn_offence.pressed.connect(func(): _switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func(): _switch_tab(ActionData.Type.DEFENCE))
	visible = false 

func load_deck(deck: Array[ActionData]):
	current_deck = deck
	_refresh_grid()

# UPDATED: 'max_cost' now represents the STRICTEST limit (from Opponent OR Self)
# UPDATED: Added 'can_use_super'
func unlock_for_input(forced_tab, player_current_sp: int, must_be_opener: bool = false, max_cost: int = 99, opening_val: int = 0, can_use_super: bool = false):
	visible = true
	is_locked = false
	current_sp_limit = player_current_sp
	opener_restriction = must_be_opener
	turn_cost_limit = max_cost 
	my_opening_value = opening_val
	super_allowed = can_use_super # Store permission
	
	if forced_tab != null:
		_switch_tab(forced_tab)
		if forced_tab == ActionData.Type.OFFENCE:
			btn_offence.disabled = false
			btn_defence.disabled = true
			btn_defence.modulate = Color(0.3, 0.3, 0.3)
		else:
			btn_offence.disabled = true
			btn_defence.disabled = false
			btn_offence.modulate = Color(0.3, 0.3, 0.3)
	else:
		btn_offence.disabled = false
		btn_defence.disabled = false
		_switch_tab(current_tab)

	var log_text = "SP: " + str(current_sp_limit)
	if opener_restriction: log_text += " | OPENERS ONLY"
	if turn_cost_limit < 99: log_text += " | MAX COST " + str(turn_cost_limit)
	if my_opening_value > 0: log_text += " | OPENING LVL " + str(my_opening_value)
	if super_allowed: log_text += " | SUPER AVAILABLE!"
	
	print("[UI] Unlocked. " + log_text)

func lock_ui():
	is_locked = true
	visible = false 
	print("[UI] Locked.")

func _on_card_selected(card: ActionData):
	if is_locked: return
	emit_signal("human_selected_card", card)
	lock_ui() 

func _switch_tab(type):
	current_tab = type
	_refresh_grid()
	
	# Helper lambda to update button visuals
	var update_btn = func(btn, is_active):
		if not btn.disabled:
			btn.modulate = Color.WHITE if is_active else Color(0.6, 0.6, 0.6)

	update_btn.call(btn_offence, type == ActionData.Type.OFFENCE)
	update_btn.call(btn_defence, type == ActionData.Type.DEFENCE)

func _refresh_grid():
	for child in button_grid.get_children():
		child.queue_free()
	
	for card in current_deck:
		if card.type == current_tab:
			var btn = card_button_scene.instantiate()
			button_grid.add_child(btn)
			btn.setup(card)
			
			# CHECK 1: SP Affordability
			var is_affordable = (card.cost <= current_sp_limit)
			
			# CHECK 2: Opener Restriction
			var passes_opener = true
			if opener_restriction and card.type == ActionData.Type.OFFENCE:
				if not card.is_opener: passes_opener = false
			
			# CHECK 3: Max Cost Constraint
			var passes_cost_limit = (card.cost <= turn_cost_limit)
			
			# CHECK 4: Counter Requirement
			var passes_counter = true
			if card.counter_value > 0:
				if my_opening_value < card.counter_value:
					passes_counter = false

			# NEW CHECK 5: Super Restriction
			var passes_super = true
			if card.is_super and not super_allowed:
				passes_super = false

			btn.set_available(is_affordable and passes_opener and passes_cost_limit and passes_counter and passes_super)
			
			btn.card_hovered.connect(_on_card_hovered)
			btn.card_selected.connect(_on_card_selected)

func _on_card_hovered(card: ActionData):
	preview_card.set_card_data(card)
	preview_card.visible = true
