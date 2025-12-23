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

var is_locked = false

func _ready():
	if not btn_offence or not btn_defence:
		printerr("CRITICAL ERROR: Buttons not found! Check node names in BattleUI.gd")
		return

	btn_offence.pressed.connect(func(): _switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func(): _switch_tab(ActionData.Type.DEFENCE))
	
	# Start hidden until the game asks for input
	visible = false 

func load_deck(deck: Array[ActionData]):
	current_deck = deck
	_refresh_grid()

# --- INPUT HANDLING ---

func unlock_for_input(forced_tab = null):
	visible = true
	is_locked = false
	
	# If the game tells us "You MUST Defend", force that tab
	if forced_tab != null:
		_switch_tab(forced_tab)
		# Optional: You could disable the other button here if you want strictly enforced UI
	else:
		_refresh_grid() # Just refresh current tab
	
	print("[UI] Unlocked for input.")

func lock_ui():
	is_locked = true
	visible = false # Hide the menu during resolution
	print("[UI] Locked.")

func _on_card_selected(card: ActionData):
	if is_locked: return
	
	print("[UI] Clicked: " + card.display_name)
	emit_signal("human_selected_card", card)
	lock_ui() # Prevent double-clicking

# --- TABS & GRID ---

func _switch_tab(type):
	current_tab = type
	_refresh_grid()
	
	# Visual feedback for tabs
	if type == ActionData.Type.OFFENCE:
		btn_offence.modulate = Color.WHITE
		btn_defence.modulate = Color(0.5, 0.5, 0.5)
	else:
		btn_offence.modulate = Color(0.5, 0.5, 0.5)
		btn_defence.modulate = Color.WHITE

func _refresh_grid():
	for child in button_grid.get_children():
		child.queue_free()
	
	for card in current_deck:
		if card.type == current_tab:
			var btn = card_button_scene.instantiate()
			button_grid.add_child(btn)
			btn.setup(card)
			btn.card_hovered.connect(_on_card_hovered)
			btn.card_selected.connect(_on_card_selected)

func _on_card_hovered(card: ActionData):
	preview_card.set_card_data(card)
	preview_card.visible = true
