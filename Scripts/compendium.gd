extends Control

@onready var keyword_container = $TabContainer/Traits/VBoxContainer
@onready var card_grid = $"TabContainer/Card Library/GridContainer"
@onready var back_button = $BackButton

# We need the CardDisplay scene to spawn cards
var card_scene = preload("res://Scenes/CardDisplay.tscn")

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	
	_populate_keywords()
	_populate_card_library()

func _populate_keywords():
	# Loop through the global dictionary
	for key in GameManager.KEYWORD_DEFS:
		var definition = GameManager.KEYWORD_DEFS[key]
		
		# Create a Label for each
		var l = RichTextLabel.new()
		l.bbcode_enabled = true
		l.text = "[b][color=yellow]" + key + ":[/color][/b] " + definition
		l.fit_content = true
		l.custom_minimum_size.y = 50 # Give it some space
		
		keyword_container.add_child(l)

func _populate_card_library():
	# We use the ID map from ClassFactory to find every card
	var all_ids = ClassFactory.ID_TO_NAME_MAP.keys()
	all_ids.sort() # Keep them in order
	
	for id in all_ids:
		# skip class nodes
		if id >= 73: continue 
		
		var card_name = ClassFactory.ID_TO_NAME_MAP[id]
		var card_data = ClassFactory._find_action_resource(card_name)
		
		if card_data:
			var display = card_scene.instantiate()
			card_grid.add_child(display)
			
			# Setup visuals
			display.set_card_data(card_data)
			display.custom_minimum_size = Vector2(200, 280) # Smaller version
			display.scale = Vector2(0.8, 0.8) # Shrink to fit more

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
