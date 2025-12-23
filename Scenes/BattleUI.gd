extends CanvasLayer

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

func _ready():
	# Connect Tab Buttons
	btn_offence.pressed.connect(func(): _switch_tab(ActionData.Type.OFFENCE))
	btn_defence.pressed.connect(func(): _switch_tab(ActionData.Type.DEFENCE))
	
	# Default hidden until combat starts
	visible = true # Set to false later when we link to Manager

func _switch_tab(type):
	current_tab = type
	_refresh_grid()

func load_deck(deck: Array[ActionData]):
	current_deck = deck
	_refresh_grid()

func _refresh_grid():
	# 1. Clear existing buttons
	for child in button_grid.get_children():
		child.queue_free()
	
	# 2. Filter Deck by Tab
	for card in current_deck:
		if card.type == current_tab:
			var btn = card_button_scene.instantiate()
			button_grid.add_child(btn)
			btn.setup(card)
			
			# Connect signals
			btn.card_hovered.connect(_on_card_hovered)
			btn.card_selected.connect(_on_card_selected)

func _on_card_hovered(card: ActionData):
	# Update the big preview card
	preview_card.set_card_data(card)
	preview_card.visible = true

func _on_card_selected(card: ActionData):
	print("Player selected: " + card.display_name)
	# TODO: Send this to GameManager
