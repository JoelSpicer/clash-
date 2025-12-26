extends CanvasLayer

signal human_selected_card(action_card)

# UI References
@onready var button_grid = %ButtonGrid
@onready var preview_card = %PreviewCard
@onready var btn_offence = %Offence        
@onready var btn_defence = %Defence       

var card_button_scene = preload("res://Scenes/CardButton.tscn")
var current_deck: Array[ActionData] = []
var current_tab = ActionData.Type.OFFENCE

# Turn State passed from TestArena
var current_sp_limit: int = 0 
var my_opportunity_val: int = 0
var my_opening_value: int = 0
var turn_cost_limit: int = 99 
var opener_restriction: bool = false
var super_allowed: bool = false 
var feint_mode: bool = false 

# Special Actions
var skip_action: ActionData
var is_locked = false

func _ready():
	# UI Setup
	if not btn_offence or not btn_defence:
		printerr("CRITICAL ERROR: Buttons not found!")
		return

	btn_offence.pressed.connect(func(): _switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func(): _switch_tab(ActionData.Type.DEFENCE))
	visible = false 
	
	# Initialize Skip Card (for Feint)
	skip_action = ActionData.new()
	skip_action.display_name = "SKIP FEINT"
	skip_action.description = "Stop combining and use your original action."
	skip_action.cost = 0

func load_deck(deck: Array[ActionData]):
	current_deck = deck
	_refresh_grid()

# Unlocks UI for player input with specific constraints
func unlock_for_input(forced_tab, player_current_sp: int, must_be_opener: bool = false, max_cost: int = 99, opening_val: int = 0, can_use_super: bool = false, opportunity_val: int = 0, is_feint_mode: bool = false):
	visible = true
	is_locked = false
	current_sp_limit = player_current_sp
	opener_restriction = must_be_opener
	turn_cost_limit = max_cost 
	my_opening_value = opening_val
	super_allowed = can_use_super 
	my_opportunity_val = opportunity_val 
	feint_mode = is_feint_mode 
	
	# Force specific tab if required (e.g. Attacker/Defender roles)
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

	# Debug Log
	var log_text = "SP: " + str(current_sp_limit)
	if opener_restriction: log_text += " | OPENERS ONLY"
	if turn_cost_limit < 99: log_text += " | MAX COST " + str(turn_cost_limit)
	if my_opportunity_val > 0: log_text += " | OPPORTUNITY -" + str(my_opportunity_val) + " COST"
	if feint_mode: log_text += " | FEINT SELECTION"
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
	
	# Update Button Visuals
	if !btn_offence.disabled: btn_offence.modulate = Color.WHITE if type == ActionData.Type.OFFENCE else Color(0.6, 0.6, 0.6)
	if !btn_defence.disabled: btn_defence.modulate = Color.WHITE if type == ActionData.Type.DEFENCE else Color(0.6, 0.6, 0.6)

func _refresh_grid():
	# Clear old buttons
	for child in button_grid.get_children():
		child.queue_free()
	
	# Populate Grid
	for card in current_deck:
		if card.type == current_tab:
			var btn = card_button_scene.instantiate()
			button_grid.add_child(btn)
			btn.setup(card)
			
			# Logic: Is this card playable?
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

	# Feint Mode: Add Skip Button
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
