extends Node

var is_tutorial_active: bool = false
var current_step: int = 0
var active_script: Array = []

# --- THE SYLLABUS ---
const SCRIPTS = {
	"basic":[{
		# TURN 1: The Opening Clash
		"sensei_text": "Welcome to the Dojo. Every combat starts with an Initial Clash. As no one has a momentum advantage yet, both combatants can choose Offence actions with the Opener Trait, or Defence actions. The combatants then reveal their actions, and the momentum advantage is awarded to whoever chooses an offence action, or to the action with the lowest cost if both actions are the same type. If the stamina is also the same, the player with the priority token goes first, and the priority token switches to the other player.\n\nPlay your [color=cyan]Basic Light (1 SP)[/color] to beat my Basic Heavy.",
		"bot_card": "Basic Heavy", 
		"player_card": "Basic Light",
		"highlight": "card:Basic Light"
	},
	{
		# TURN 2: Offence
		"sensei_text": "Good! Although you took some damage, you won priority and took the [color=red]Offence[/color]. You have now started a combo. Try using another Basic Light, and I will defend!",
		"bot_card": "Basic Block",
		"player_card": "Basic Light",
		"highlight": "card:Basic Light"
	},
	{
		# TURN 3: The Reversal
		"sensei_text": "I blocked that attack and took no damage, but you pushed me back still, gaining momentun! I am on the ropes, but watch closely! I am playing a card with the [color=yellow]Reversal[/color] trait. If my Reversal pushes the momentum back to your side (such as you using a card with the Fall Back trait), I steal the Offence!",
		"bot_card": "Basic Reversal", 
		"player_card": "Basic Positioning",
		"highlight": "card:Basic Positioning"
	},
	{
		# TURN 4: Defence & Wall Crush
		"sensei_text": "I have stolen the offence, and you now can only use defence actions. I'm going to use a technical action, which can have unusual effects, so it may be safer to dodge the action entirely",
		"bot_card": "Basic Technical",
		"player_card": "Basic Dodge",
		"highlight": "card:Basic Dodge"
	}],
	
	#NEXT TUTORIAL
	"advanced": [{
		# TURN 4: Defence & Wall Crush
		"sensei_text": "This is the advanced tutorial which doesn't exist yet",
		"bot_card": "Basic Technical",
		"player_card": "Basic Dodge",
		"highlight": "card:Basic Dodge"
	}]
}

# --- NEW: THE SETUP MASTER FUNCTION ---
func setup_and_start_tutorial(tutorial_id: String):
	if not SCRIPTS.has(tutorial_id):
		printerr("Tutorial ID not found: ", tutorial_id)
		return

	# 1. Set the Active Script
	active_script = SCRIPTS[tutorial_id]
	is_tutorial_active = true
	current_step = 0

	# 2. Create Fighters (You can customize these based on tutorial_id if needed)
	var p1 = CharacterData.new()
	p1.character_name = "Student"
	p1.deck = _generate_basic_deck()
	p1.reset_stats(false)

	var p2 = CharacterData.new()
	p2.character_name = "Sensei"
	p2.deck = _generate_basic_deck()
	p2.reset_stats(false)

	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2

	# 3. Settings
	RunManager.is_arcade_mode = false
	GameManager.p2_is_custom = false
	GameManager.ai_difficulty = GameManager.Difficulty.MEDIUM

	print("--- TUTORIAL STARTED: ", tutorial_id, " ---")
	SceneLoader.change_scene("res://Scenes/MainScene.tscn")

# --- NEW: DECK GENERATOR ---
# This builds a perfectly balanced basic deck in memory for the tutorial.
func _generate_basic_deck() -> Array[ActionData]:
	var d: Array[ActionData] = []
	
	# OFFENCE
	d.append(load("res://Data/Actions/basic_light.tres").duplicate(true))
	d.append(load("res://Data/Actions/basic_technical.tres").duplicate(true))
	d.append(load("res://Data/Actions/basic_heavy.tres").duplicate(true))
	d.append(load("res://Data/Actions/basic_positioning.tres").duplicate(true))

	# DEFENCE
	d.append(load("res://Data/Actions/basic_block.tres").duplicate(true))
	d.append(load("res://Data/Actions/basic_dodge.tres").duplicate(true))
	d.append(load("res://Data/Actions/basic_parry.tres").duplicate(true))
	d.append(load("res://Data/Actions/basic_reversal.tres").duplicate(true))

	return d

# --- UPDATED HELPERS ---
func get_current_data() -> Dictionary:
	if current_step < active_script.size():
		return active_script[current_step]
	return {}

func advance_step():
	current_step += 1
	if current_step >= active_script.size():
		end_tutorial()

func end_tutorial():
	is_tutorial_active = false
	current_step = 0
	active_script = []
