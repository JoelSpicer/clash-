extends Control

@onready var keyword_container = $TabContainer/Traits/MarginContainer/VBoxContainer
@onready var combat_container = $TabContainer/Combat/MarginContainer/VBoxContainer
@onready var card_grid = $"TabContainer/Card Library/MarginContainer/GridContainer"
@onready var rules_container = $"TabContainer/Rules/MarginContainer/VBoxContainer"
@onready var modes_container = $TabContainer/Modes/MarginContainer/VBoxContainer
@onready var tab_container = $TabContainer # <--- NEW
@onready var back_button = $BackButton

# New variable to control which tab opens first
var initial_tab_index: int = 0

const RULES_DEFS = {
	"Actions": "An action is a move, technique or attack that is used in combat. Every action has a number of traits that convey how the action works.",
	"Passive Abilities": "Passive enhancements that affect all actions. Everyone gets a passive ability from their chosen class.",
	"Combo": "A combo is one or more Offence actions used in a row, without having to check the momentum advantage.",
	"Traits": "All actions have one or more traits. A trait is a keyword that conveys information about how an action interacts with other rules elements or traits. Traits can stack unless otherwise noted. Actions are sometimes named for their traits, e.g. an action with the Offence trait is called and Offence action.", 
	"Stamina": "Every combatant has a number of stamina points (SP), which is used to keep track of their current stamina as it increases and falls throughout a combat. Player characters start with 3 SP. Stamina can be increased and reduced by you or your opponent’s actions and special abilities.", 
	"Health": "Every combatant has a number of hit points (HP) that they must keep track of. Player characters start with 10 HP. Actions can deal damage to you to reduce your HP, or heal yourself to increase your HP (up to your max HP).", 
	"Momentum": "Momentum keeps track of who has taken the advantage in combat. It is suggested that momentum is tracked using one polyhedral die, but any even number can be used. Each combatant chooses either high or low numbers to be theirs. Any time a player is in their ‘half’ of the tracker, they have the momentum advantage, and can use offence actions in combat (once their opponent's combo has ended). Example: With a momentum of 8, player A chooses high numbers, so 5-8, and player B chooses low numbers, so 1-4. Whenever player A would gain momentum, through actions or special abilities, they would increase the number. Conversely, whenever player B would gain momentum, they would decrease the number. For example, if momentum is on 2, player B has the momentum advantage, and if the momentum was 1, player A would first take SP damage if they use fall back actions, or HP if they are out of SP.", 
	"Order of Actions": "When you apply the traits from an action to yourself, please use the following rules: • Apply traits from your action to yourself before you apply traits from your opponent’s action to yourself • Apply traits that affect the momentum tracker from Offence actions first, then Defence actions."
}

const COMBAT_DEFS = {
	"Combat Rules": "A combat is a 1v1 fight between two 'combatants'. These could be between player characters, non-player characters, or any combination of the two.",
	"Structure": "A ‘Combat’ is played out in a series of ‘Clashes’.",
	"Clash": "Two combatants choose an action secretly, and resolve the results.",
	"Combat": "Combatants resolve clashes until one of them is defeated by losing all their health.",
	"Step 1: Set Stamina and Health": "At the start of every combat, each combatant normally has their maximum stamina and health, however this could be reduced by things like previous fights or environmental effects.",
	"Step 2: Choose Momentum": "The momentum tracker is chosen by the referee, and each combatant chooses which half of the tracker they wish to use, high or low. A priority token is also awarded to the player whose class has the highest speed. If the classes are the same, decide randomly, such as with a coin flip.",
	"Step 3: Initial Clash ": "The combatants then start with an initial clash, where both combatants secretly choose an action. As no one has a momentum advantage yet, both combatants can choose Offence or Defence actions. The combatants then reveal their actions, and the momentum advantage is awarded as follows: •	If one combatant chooses an action with the Offence trait, and one combatant chooses and action with the Defense trait, the combatant that chose the Offence action is awarded the momentum advantage. •	If the traits are the same, the action with lower stamina interrupts the other, taking the momentum advantage. If the stamina is also the same, the player with the priority token goes first, and the priority token switches to the other player. Whichever combatant is awarded the momentum advantage sets the momentum tracker to the number on their half closest to the center (e.g. 4 for Low, 5 for High).. The combatant with the momentum advantage is now on the attack, and can only use actions with the Offence trait, while the other combatant can only use actions with the Defence trait.",
	"Step 4: Resolve Initial Actions ": "The combatants now resolve the effects of their actions, such as using stamina, but ignore any momentum gain or loss from their actions.",
	"Step 5: Clashes ": "Now that the initial clash is resolved, combat can continue as normal. The combatant that is on the attack can continue their combo. When a combo is over, the momentum is checked. A combatant can choose to end their own combo at any time. Whichever combatant has the momentum advantage is now on the offence, and the other combatant is now on the defence. Each clash, combatants secretly choose a move, a his repeats until a combatant loses all their health."
}

var MODES_DEFS = {
		"Quick Match": "A single battle against an AI opponent. You choose a basic class loadout or a preset deck. Great for testing mechanics or a quick fight. \n\n- Simply choose a character for you and your opponent, toggle between CPU and Human for player 2, choose a CPU difficulty, then select Quick CLASH! to get right into the action",
		"Quick Match (build action list)": "Just like regular Quick Match, except you create an action loadout for P1, and P2 if they are human!",
		"Arcade Mode": "Continuous battles against random opponents with a hand limit of 8, where you unlock a new action after each victory. If you lose a match, the run ends. \n\n- Choose a basic class to start from scratch or a premade character to start at a higher level, choose the NPC difficulty, then select Start Arcade Run!."
	}

# We need the CardDisplay scene to spawn cards
var card_scene = preload("res://Scenes/CardDisplay.tscn")

var is_overlay: bool = false # Default is False (Main Menu Mode)

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	
	# Consolidated calls
	_populate_section(keyword_container, GameManager.KEYWORD_DEFS)
	_populate_section(rules_container, RULES_DEFS)
	_populate_section(combat_container, COMBAT_DEFS)
	_populate_section(modes_container, MODES_DEFS)
	
	_populate_card_library()
	
	if is_overlay:
		back_button.text = "Close Help"
	
	tab_container.current_tab = initial_tab_index

func _populate_card_library():
	# We use the ID map from ClassFactory to find every card
	var all_ids = ClassFactory.ID_TO_NAME_MAP.keys()
	all_ids.sort() # Keep them in order
	
	for id in all_ids:
		# skip class nodes
		if id >= 73: continue 
		
		var card_name = ClassFactory.ID_TO_NAME_MAP[id]
		var card_data = ClassFactory.find_action_resource(card_name)
		
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

func _populate_section(container: Control, data: Dictionary):
	for key in data:
		var text_value = data[key]
		
		var l = RichTextLabel.new()
		l.bbcode_enabled = true
		l.text = "[b][color=yellow]" + key + ":[/color][/b] " + text_value
		l.fit_content = true
		l.custom_minimum_size.y = 50 
		
		container.add_child(l)
