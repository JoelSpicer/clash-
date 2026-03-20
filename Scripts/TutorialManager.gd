extends Node

var is_tutorial_active: bool = false
var current_step: int = 0
var active_script: Array = []

# --- THE SYLLABUS ---
const SCRIPTS = {
	"basic": {
		# --- NEW: TUTORIAL CONFIGURATION ---
		"config": {
			"environment": "Dojo",
			"p1_name": "Student",
			"p1_hp": 10,
			"p1_sp": 5,
			# Replace with your actual enum like CharacterData.ClassType.QUICK if needed
			"p1_class": CharacterData.ClassType.NONE, 
			"p1_deck": "basic",
			
			"p2_name": "Sensei",
			"p2_hp": 25,
			"p2_sp": 10,
			"p2_class": CharacterData.ClassType.NONE,
			"p2_deck": "basic"
		},
		# -----------------------------------
		"steps": [
			{
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
				"sensei_text": "I blocked that attack and took no damage, but you pushed me back still, gaining momentum, look at the bar above, it's on your side now! I am on the ropes, but watch closely! I am playing a card with the [color=yellow]Reversal[/color] trait. If my Reversal pushes the momentum back to your side (such as you using a card with the Fall Back trait), I steal the Offence!",
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
			},
			{
				# TURN 5: Parry
				"sensei_text": "You totally dodged the attack, but dodging is very stamina intensive, so save it for actions with the Guard Break trait, which ignore the Block trait. \n Now I'm going to throw a Heavy attack, with high momentum, so you should try and use this to your advantage and Parry!",
				"bot_card": "Basic Heavy",
				"player_card": "Basic Parry",
				"highlight": "card:Basic Parry"
			},
			{
				# TURN 6: Reversal 2
				"sensei_text": "You Parried the heavy attack, negating the damage, and forcing me to use an action with the Opener trait next. But watch out! If you use an action with the Fall Back trait, and you're already at minimum momentum, you'll take SP, and the HP damage! Now, I need to recover some stamina, so try using a reversal on me, to take the offence once again!",
				"bot_card": "Basic Positioning",
				"player_card": "Basic Reversal",
				"highlight": "card:Basic Reversal"
			},
			{
				# TURN 7: Finale 1
				"sensei_text": "And now you're on the offence again, ready for a combo! Most fights run on these 4 basic interations: \n Block beats Light, low damage actions, and generally helps recover stamina.\nDodge is best against actions of the same cost, with advanced traits, like Guard Break.\nParry negates high momentum, heavy actions, but only if the momentum trait is higher than your fall back trait.\nReversal beats actions with the fall back trait, and allows the defender to become the attacker.",
				"bot_card": "Basic Dodge",
				"player_card": "Basic Technical",
				"highlight": "card:Basic Technical"
			},
			{
				# TURN 8: Finale 2
				"sensei_text": "Most actions are variations and combinations of these traits, however there are some more advanced traits too! You can view every action and trait in the compendium, accessable by going left from The Circuit menu, or by clicking the '?' button in the bottom right of the screen during a combat.",
				"bot_card": "Basic Block",
				"player_card": "Basic Light",
				"highlight": "card:Basic Technical"
			}
		]
	},
	
	"begin": {
		"config": {
			"environment": "Street",
			"p1_name": "Nobody",
			"p1_hp": 2,
			"p1_sp": 8,
			"p1_class": CharacterData.ClassType.NONE, 
			"p1_deck": "toobasic",
			
			"p2_name": "Bad Kid",
			"p2_hp": 5,
			"p2_sp": 2,
			"p2_class": CharacterData.ClassType.NONE,
			"p2_deck": "basic"
		},
		"steps": [
			{
				"sensei_text": "Who do you think you are kid? Some kind of fighter? Just try and hit me, see how that works out!",
				"bot_card": "Basic Dodge",
				"player_card": "Basic Light",
				"highlight": "card:Basic Light"
			},
			{
				"sensei_text": "Nice try, think you got a combo going huh? Go on, I won't even dodge this time.",
				"bot_card": "Basic Block",
				"player_card": "Basic Light",
				"highlight": "card:Basic Light"
			},
			{
				"sensei_text": "Heh, didn't feel a thing. In fact I feel better than ever. You don't even have a technique, just flailing away!",
				"bot_card": "Basic Block",
				"player_card": "Basic Technical",
				"highlight": "card:Basic Technical"
			},
			{
				"sensei_text": "Damn, broke through huh? [i]Better dodge this little runt instead, if he's just gonna keep tossing out light attacks...[/i]",
				"bot_card": "Basic Dodge",
				"player_card": "Basic Heavy",
				"highlight": "card:Basic Heavy"
			},
			{
				"sensei_text": "[b]WOAH,[/b] okay kid, I get it, I'll tell you where the circuit starts, just don't hit me like that again, catch your breath!",
				"bot_card": "Basic Block",
				"player_card": "Basic Positioning",
				"highlight": "card:Basic Positioning"
			},
		]
	}
}

# --- NEW: THE SETUP MASTER FUNCTION ---
func setup_and_start_tutorial(tutorial_id: String):
	if not SCRIPTS.has(tutorial_id):
		printerr("Tutorial ID not found: ", tutorial_id)
		return

	var tutorial_data = SCRIPTS[tutorial_id]
	var config = tutorial_data["config"]

	# 1. Set the Active Script
	active_script = tutorial_data["steps"]
	is_tutorial_active = true
	current_step = 0

	# 2. Create Fighters with Configured Stats
	var p1 = CharacterData.new()
	p1.character_name = config.get("p1_name", "Student")
	p1.max_hp = config.get("p1_hp", 10)
	p1.max_sp = config.get("p1_sp", 5)
	p1.class_type = config.get("p1_class", 0) as CharacterData.ClassType
	var p1_deck_type = config.get("p1_deck", "basic")
	p1.deck = _generate_deck(p1_deck_type)
	p1.reset_stats(false)

	var p2 = CharacterData.new()
	p2.character_name = config.get("p2_name", "Sensei")
	p2.max_hp = config.get("p2_hp", 10)
	p2.max_sp = config.get("p2_sp", 5)
	p2.class_type = config.get("p2_class", 0) as CharacterData.ClassType
	var p2_deck_type = config.get("p2_deck", "basic")
	p2.deck = _generate_deck(p2_deck_type)
	p2.reset_stats(false)

	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2

	# 3. Apply Environment Rules
	var env = config.get("environment", "Dojo")
	GameManager.apply_environment_rules(env)
	
	if AudioManager.has_method("play_location_music"):
		AudioManager.play_location_music(env)

	# 4. Settings
	RunManager.is_arcade_mode = false
	GameManager.p2_is_custom = false
	GameManager.ai_difficulty = GameManager.Difficulty.MEDIUM

	print("--- TUTORIAL STARTED: ", tutorial_id, " ---")
	SceneLoader.change_scene("res://Scenes/MainScene.tscn")

# --- NEW: DECK GENERATOR ---
# This builds a perfectly balanced basic deck in memory for the tutorial.
# Replace your old _generate_basic_deck() with this:
func _generate_deck(deck_name: String) -> Array[ActionData]:
	var d: Array[ActionData] = []
	
	match deck_name:
		"basic":
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
			
		"advanced":
			# Put whatever specific cards you want to teach here!
			d.append(load("res://Data/Actions/haymaker.tres").duplicate(true))
			d.append(load("res://Data/Actions/elbow_block.tres").duplicate(true))
			# Add as many as you need for the advanced tutorial...
		
		"toobasic":
			# OFFENCE
			d.append(load("res://Data/Actions/basic_light.tres").duplicate(true))
			d.append(load("res://Data/Actions/basic_technical.tres").duplicate(true))
			d.append(load("res://Data/Actions/basic_heavy.tres").duplicate(true))
			d.append(load("res://Data/Actions/basic_positioning.tres").duplicate(true))
			# DEFENCE
			#d.append(load("res://Data/Actions/basic_block.tres").duplicate(true))
			#d.append(load("res://Data/Actions/basic_dodge.tres").duplicate(true))
			#d.append(load("res://Data/Actions/basic_parry.tres").duplicate(true))
			#d.append(load("res://Data/Actions/basic_reversal.tres").duplicate(true))
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

# --- UPDATED: END TUTORIAL ---
func end_tutorial():
	print("--- TUTORIAL COMPLETE ---")
	
	# 1. Reset variables
	is_tutorial_active = false
	current_step = 0
	active_script = []
	
	# 2. Reset Audio State
	AudioManager.reset_audio_state()
	AudioManager.play_music("menu_theme")
	
	# 3. Route the player back to the Menu
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
