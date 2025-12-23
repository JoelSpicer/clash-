extends CanvasLayer

# SIGNAL: Sent to TestArena when the human clicks a button
signal human_selected_card(action_card)

# References
@onready var button_grid = $MainLayout/BottomBar/ContentSplit/ScrollContainer/ButtonGrid
@onready var preview_card = $MainLayout/PreviewAnchor/PreviewCard
@onready var btn_offence = $MainLayout/BottomBar/ContentSplit/TabButtons/Offence
@onready var btn_defence = $MainLayout/BottomBar/ContentSplit/TabButtons/Defence # Rename in scene if needed

# The Prefab we spawn
var card_button_scene = preload("res://Scenes/CardButton.tscn")

# State
var current_deck: Array[ActionData] = []
var current_tab = ActionData.Type.OFFENCE

var current_sp_limit: int = 0 # NEW: Tracks player's available SP

# NEW: Tracks if the player is restricted to "Opener" moves only
var opener_restriction: bool = false

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

# --- INPUT HANDLING ---

# UPDATED: Now accepts 'must_be_opener' flag
func unlock_for_input(forced_tab, player_current_sp: int, must_be_opener: bool = false):
	visible = true
	is_locked = false
	current_sp_limit = player_current_sp
	opener_restriction = must_be_opener # Store restriction
	
	# 1. Handle Role Locking
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
	print("[UI] Unlocked. " + log_text)

func lock_ui():
	is_locked = true
	visible = false 
	print("[UI] Locked.")

func _on_card_selected(card: ActionData):
	if is_locked: return
	emit_signal("human_selected_card", card)
	lock_ui() 

# --- TABS & GRID ---

func _switch_tab(type):
	current_tab = type
	_refresh_grid()
	
	if not btn_offence.disabled:
		btn_offence.modulate = Color.WHITE if type == ActionData.Type.OFFENCE else Color(0.6, 0.6, 0.6)
	
	if not btn_defence.disabled:
		btn_defence.modulate = Color.WHITE if type == ActionData.Type.DEFENCE else Color(0.6, 0.6, 0.6)

func _refresh_grid():
	for child in button_grid.get_children():
		child.queue_free()
	
	for card in current_deck:
		if card.type == current_tab:
			var btn = card_button_scene.instantiate()
			button_grid.add_child(btn)
			btn.setup(card)
			
			# CHECK 1: Affordability
			var is_affordable = (card.cost <= current_sp_limit)
			
			# CHECK 2: Opener Restriction (Only applies to OFFENCE cards)
			var passes_opener_check = true
			if opener_restriction and card.type == ActionData.Type.OFFENCE:
				if not card.is_opener:
					passes_opener_check = false
			
			# Combined availability
			btn.set_available(is_affordable and passes_opener_check)
			
			btn.card_hovered.connect(_on_card_hovered)
			btn.card_selected.connect(_on_card_selected)

func _on_card_hovered(card: ActionData):
	preview_card.set_card_data(card)
	preview_card.visible = true
