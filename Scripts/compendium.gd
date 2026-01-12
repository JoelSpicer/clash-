extends Control

@onready var keyword_container = $TabContainer/Traits/VBoxContainer
@onready var combat_container = $TabContainer/Combat/VBoxContainer
@onready var card_grid = $"TabContainer/Card Library/GridContainer"
@onready var rules_container = $"TabContainer/Rules/VBoxContainer"
@onready var back_button = $BackButton

const RULES_DEFS = {
	"Actions": "An action is a move, technique or attack that is used in combat. Every action has a number of traits that convey how the action works.",
	"Passive Abilities": "Passive enhancements that affect all actions. Everyone gets a passive ability from their chosen class.",
	"Combo": "A combo is one or more Offence actions used in a row, without having to check the momentum advantage.",
	"Traits": "All actions have one or more traits. A trait is a keyword that conveys information about how an action interacts with other rules elements or traits. Traits can stack unless otherwise noted. Actions are sometimes named for their traits, e.g. an action with the Offence trait is called and Offence action.", 
	"Stamina": "Every combatant has a number of stamina points (SP), which is used to keep track of their current stamina as it increases and falls throughout a combat. Player characters start with 3 SP. Stamina can be increased and reduced by you or your opponent’s actions and special abilities.", 
	"Health": "Every combatant has a number of hit points (HP) that they must keep track of. Player characters start with 10 HP. Actions can deal damage to you to reduce your HP, or heal yourself to increase your HP (up to your max HP).", 
	"Momentum": "Momentum keeps track of who has taken the advantage in combat. It is suggested that momentum is tracked using one polyhedral die, but any even number can be used. Each combatant chooses either high or low numbers to be theirs. Any time a player is in their ‘half’ of the tracker, they have the momentum advantage, and can use offence actions in combat. Example: With a momentum of 8, player A chooses high numbers, so 5-8, and player B chooses low numbers, so 1-4. Whenever player A would gain momentum, through actions or special abilities, they would increase the number. Conversely, whenever player B would gain momentum, they would decrease the number. For example, if momentum is on 2, player B has the momentum advantage, and if the momentum was 1, player B would be able to choose their action after seeing their opponent’s action.", 
	"Order of Actions": "When you apply the traits from an action to yourself, please use the following rules: • Apply traits from your action to yourself before you apply traits from your opponent’s action to yourself • Apply traits that affect the momentum tracker from Offence actions first, then Defence actions."
}

const COMBAT_DEFS = {
	"Combat": "A combat is a 1v1 fight between two 'combatants'. These could be between player characters, non-player characters, or any combination of the two."
}

# We need the CardDisplay scene to spawn cards
var card_scene = preload("res://Scenes/CardDisplay.tscn")

var is_overlay: bool = false # Default is False (Main Menu Mode)

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	
	_populate_rules()
	_populate_combat()
	_populate_keywords()
	_populate_card_library()
	
	if is_overlay:
		back_button.text = "Resume Combat"

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

func _populate_rules():
	# Loop through the global dictionary
	for key in RULES_DEFS:
		var rules = RULES_DEFS[key]
		
		# Create a Label for each
		var l = RichTextLabel.new()
		l.bbcode_enabled = true
		l.text = "[b][color=yellow]" + key + ":[/color][/b] " + rules
		l.fit_content = true
		l.custom_minimum_size.y = 50 # Give it some space
		
		rules_container.add_child(l)
		
func _populate_combat():
	# Loop through the global dictionary
	for key in COMBAT_DEFS:
		var combat = COMBAT_DEFS[key]
		
		# Create a Label for each
		var l = RichTextLabel.new()
		l.bbcode_enabled = true
		l.text = "[b][color=yellow]" + key + ":[/color][/b] " + combat
		l.fit_content = true
		l.custom_minimum_size.y = 50 # Give it some space
		
		combat_container.add_child(l)

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
	if is_overlay:
		# Just close this window, don't restart the game!
		queue_free()
	else:
		# Go back to Main Menu
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
