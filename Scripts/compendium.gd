extends Control

@onready var keyword_container: VBoxContainer = $TabContainer/Traits/MarginContainer/VBoxContainer
@onready var combat_container: VBoxContainer = $TabContainer/Combat/MarginContainer/VBoxContainer
@onready var card_grid: GridContainer = $"TabContainer/Card Library/MarginContainer/GridContainer"
@onready var rules_container: VBoxContainer = $TabContainer/Rules/MarginContainer/VBoxContainer
@onready var modes_container: VBoxContainer = $TabContainer/Modes/MarginContainer/VBoxContainer
@onready var tab_container: TabContainer = $TabContainer
@onready var back_button: Button = $BackButton

# Controls which tab opens first
var initial_tab_index: int = 0

const RULES_DEFS: Dictionary = {
	"Actions": "An action is a move, technique or attack that is used in combat. Every action has a number of traits that convey how the action works.",
	"Passive Abilities": "Passive enhancements that affect all actions. Everyone gets a passive ability from their chosen class.",
	"Combo": "A combo is one or more Offence actions used in a row, without having to check the momentum advantage. If the player on offence runs out of stamina, their combo is over, and they must check the momentum advantage.",
	"Traits": "All actions have one or more traits. A trait is a keyword that conveys information about how an action interacts with other rules elements or traits. Traits can stack unless otherwise noted. Actions are sometimes named for their traits, e.g. an action with the Offence trait is called an Offence action.",
	"Stamina": "Every combatant has a number of stamina points (SP), which is used to keep track of their current stamina as it increases and falls throughout a combat. Stamina can be increased and reduced by you or your opponent’s actions and special abilities.",
	"Health": "Every combatant has a number of hit points (HP) that they must keep track of. Actions can deal damage to you to reduce your HP, or heal yourself to increase your HP (up to your max HP).",
	"Momentum": "Momentum keeps track of who has taken the advantage in combat. Each combatant is allocated either high or low numbers to be theirs. Any time a player is in their ‘half’ of the tracker, they have the momentum advantage, and can use offence actions in combat (once their opponent's combo has ended). Example: With a momentum of 8, player 1 is given low numbers, so 1-4, and player 2 is given high numbers, so 5-8. Whenever player 1 would gain momentum, through actions or special abilities, they would decrease the number. Conversely, whenever player 2 would gain momentum, they would increase the number. For example, if momentum is on 2, player 1 has the momentum advantage, and if the momentum was 1, player 2 would first take SP damage if they use fall back actions, or HP if they are out of SP.",
	"Order of Actions": "When you apply the traits from an action to yourself, please use the following rules:\n• Apply traits from your action to yourself before you apply traits from your opponent’s action to yourself\n• Apply traits that affect the momentum tracker from Offence actions first, then Defence actions."
}

const COMBAT_DEFS: Dictionary = {
	"Combat Rules": "A combat is a 1v1 fight between two 'combatants'. These could be between player characters, non-player characters, or any combination of the two.",
	"Structure": "A ‘Combat’ is played out in a series of ‘Clashes’.",
	"Clash": "Two combatants choose an action secretly, and resolve the results.",
	"Combat": "Combatants resolve clashes until one of them is defeated by losing all their health.",
	"Step 1: Set Stamina and Health": "At the start of every combat, each combatant normally has their maximum stamina and health, however this could be reduced by things like previous fights or environmental effects.",
	"Step 2: Choose Momentum": "The momentum tracker length is determined by the stage, with player 1 taking low numbers, and player 2 taking high numbers. A priority token is also awarded to the player whose class has the highest speed. If the speed is the same, it is awarded randomly.",
	"Step 3: Initial Clash": "The combatants then start with an initial clash, where both combatants secretly choose an action. As no one has a momentum advantage yet, both combatants can choose Offence (with the Opener trait) or Defence actions. The combatants then reveal their actions, and the momentum advantage is awarded as follows:\n• If one combatant chooses an action with the Offence trait, and one combatant chooses an action with the Defence trait, the combatant that chose the Offence action is awarded the momentum advantage.\n• If the traits are the same, the action with lower stamina interrupts the other, taking the momentum advantage.\n• If the stamina is also the same, the player with the priority token goes first, and the priority token switches to the other player.\nWhichever combatant is awarded the momentum advantage has the momentum tracker set to the number on their half closest to the center (e.g. on a tracker of 8, 4 for Low, 5 for High). The combatant with the momentum advantage is now on the attack, and can only use actions with the Offence trait, while the other combatant can only use actions with the Defence trait.",
	"Step 4: Resolve Initial Actions": "The combatants now resolve the effects of their actions, such as using stamina, but ignore any momentum gain or loss from their actions.",
	"Step 5: Clashes": "Now that the initial clash is resolved, combat can continue as normal. The combatant that is on the attack can continue their combo. When a combo is over, the momentum is checked. Whichever combatant has the momentum advantage is now on the offence, and the other combatant is now on the defence. Each clash, combatants secretly choose a move, and this repeats until a combatant loses all their health."
}

const MODES_DEFS: Dictionary = {
	"The Circuit": "A roguelike tournament ladder with an 8-card active hand limit. Draft new actions, stat boosts, and equipment after each win as you climb through 10 nodes per League. Lose a match and the run ends — conquer the Finals to earn Circuit Tokens and advance to the next League or retire as Champion.\n• [b]Bosses & Boss Traits:[/b] Every League features a Mid-Bracket Mini-Boss (Node 5) and a Finals Champion (Node 10) with procedural Boss Traits — such as Juggernaut, Iron Wall, Blitz Champion, Grandmaster, Berserker, or Tactician — that alter their stats, starting momentum/opportunity, and AI style. Scout them on the map or click Inspect during combat to read their active traits.\n• [b]Sponsors & Rival Matches:[/b] Sign a Corporate Sponsor in the Shop Terminal to start runs with unique perks and passive bonuses — at the cost of a corporate downside or a Rival Grudge Match waiting on the tournament bracket. Defeating your Rival awards bonus Circuit Tokens.\n• [b]Training Gyms & Event Rooms:[/b] Branch off the main combat path on the Circuit Map to visit Training Gyms (spend recovery turns for healing or temporary next-fight buffs) and Event Rooms (risk-reward encounters that can grant stats, actions, healing, or momentum edges).",
	"Quick Match (CPU & Local 2P)": "Jump straight into a standalone one-and-done fight using premade fighters. Pick any preset matchup, choose your Arena, and battle either the CPU (at Easy, Medium, or Hard difficulty) or a second player locally on the same device in Pass-and-Play Hotseat mode.",
	"Online Multiplayer": "Connect to the CLASH multiplayer server to face another player online with premade fighters. Clashes are resolved simultaneously by the authoritative server so both players lock in secretly before reveal."
}

# We need the CardDisplay scene to spawn cards
const CARD_SCENE: PackedScene = preload("res://Scenes/CardDisplay.tscn")

var is_overlay: bool = false # Default is False (Main Menu Mode)

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	# Consolidated calls
	_populate_section(keyword_container, GameManager.KEYWORD_DEFS)
	_populate_section(rules_container, RULES_DEFS)
	_populate_section(combat_container, COMBAT_DEFS)
	_populate_section(modes_container, MODES_DEFS)

	_populate_card_library()

	if is_overlay:
		back_button.text = "Close Help"
		$Background.visible = true
	else:
		$BackButton.visible = false
	tab_container.current_tab = initial_tab_index

func _populate_card_library() -> void:
	var cards_to_display: Array[ActionData] = []
	var seen_names: Dictionary = {}

	# 1. All 8 Basic Actions
	for basic_card: ActionData in ClassFactory.get_basic_actions():
		_append_unique_card(cards_to_display, seen_names, basic_card)

	# 2. All Class Starter Actions (Heavy, Patient, Quick, Technical)
	var class_order: Array[CharacterData.ClassType] = [
		CharacterData.ClassType.HEAVY,
		CharacterData.ClassType.PATIENT,
		CharacterData.ClassType.QUICK,
		CharacterData.ClassType.TECHNICAL,
	]
	for ctype: CharacterData.ClassType in class_order:
		if not ClassFactory.class_registry.has(ctype):
			continue
		var class_def: ClassDefinition = ClassFactory.class_registry[ctype]
		if class_def == null:
			continue
		for starter_card: ActionData in class_def.starting_deck:
			_append_unique_card(cards_to_display, seen_names, starter_card)

	# 3. All Skill Tree Actions
	var all_ids: Array = ClassFactory.ID_TO_NAME_MAP.keys()
	all_ids.sort()
	for id: int in all_ids:
		if id in ClassFactory.CLASS_ROOT_IDS:
			continue
		var card_name: String = ClassFactory.ID_TO_NAME_MAP[id]
		var card_data: ActionData = ClassFactory.find_action_resource(card_name)
		_append_unique_card(cards_to_display, seen_names, card_data)

	for card_data: ActionData in cards_to_display:
		var display: Control = CARD_SCENE.instantiate() as Control
		card_grid.add_child(display)
		display.set_card_data(card_data)
		display.custom_minimum_size = Vector2(200, 280)
		display.scale = Vector2(0.8, 0.8)

func _append_unique_card(target: Array[ActionData], seen: Dictionary, card: ActionData) -> void:
	if card == null:
		return
	var key: String = card.display_name.to_lower()
	if seen.has(key):
		return
	seen[key] = true
	target.append(card)

func _on_back_pressed() -> void:
	if is_overlay:
		# Just close this window, don't restart the game!
		queue_free()
	else:
		# Go back to Main Menu
		SceneLoader.change_scene("res://Scenes/MainMenu.tscn")

func _populate_section(container: Control, data: Dictionary) -> void:
	for key: String in data:
		var text_value: String = str(data[key])

		var l: RichTextLabel = RichTextLabel.new()
		l.bbcode_enabled = true
		l.text = "[b][color=yellow]" + key + ":[/color][/b] " + text_value
		l.fit_content = true
		l.custom_minimum_size.y = 50

		container.add_child(l)
