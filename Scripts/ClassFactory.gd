extends Node

# Generates a fully playable CharacterData resource based on the chosen class
func create_character(class_type: CharacterData.ClassType, player_name: String) -> CharacterData:
	var char_data = CharacterData.new()
	char_data.character_name = player_name
	char_data.class_type = class_type
	
	# 1. Set Base Stats & Passives
	match class_type:
		CharacterData.ClassType.HEAVY:
			char_data.max_hp = 10
			char_data.max_sp = 10
			char_data.speed = 1
			char_data.passive_desc = "RAGE: Pay HP instead of SP if stamina is low."
			
		CharacterData.ClassType.PATIENT:
			char_data.max_hp = 10
			char_data.max_sp = 10
			char_data.speed = 2
			char_data.passive_desc = "KEEP-UP: Spend SP to prevent Falling Back."
			
		CharacterData.ClassType.QUICK:
			char_data.max_hp = 10
			char_data.max_sp = 10
			char_data.speed = 4
			char_data.passive_desc = "RELENTLESS: Every 3rd combo hit recovers 1 SP."
			
		CharacterData.ClassType.TECHNICAL:
			char_data.max_hp = 10
			char_data.max_sp = 10
			char_data.speed = 3
			char_data.passive_desc = "TECHNIQUE: Versatile playstyle."

	# 2. Build the Deck (Basic Cards + Class Exclusives)
	char_data.deck = _get_starting_deck(class_type)
	
	# 3. Reset Runtime state
	char_data.reset_stats()
	return char_data

func _get_starting_deck(type: CharacterData.ClassType) -> Array[ActionData]:
	var deck: Array[ActionData] = []
	
	# --- ADD BASIC CARDS (Common to all) ---
	# We use load() to turn the file path into a usable Object
	deck.append(load("res://Data/Actions/basic_light.tres"))
	deck.append(load("res://Data/Actions/basic_heavy.tres"))
	deck.append(load("res://Data/Actions/basic_technical.tres"))
	deck.append(load("res://Data/Actions/basic_positioning.tres"))
	deck.append(load("res://Data/Actions/basic_block.tres"))
	deck.append(load("res://Data/Actions/basic_dodge.tres")) # This fixes line 41
	deck.append(load("res://Data/Actions/basic_parry.tres"))
	deck.append(load("res://Data/Actions/basic_reversal.tres"))
	
	# --- ADD CLASS EXCLUSIVES ---
	match type:
		CharacterData.ClassType.HEAVY:
			deck.append(load("res://Data/Actions/haymaker.tres"))
			deck.append(load("res://Data/Actions/elbow_block.tres"))
			
		CharacterData.ClassType.PATIENT:
			deck.append(load("res://Data/Actions/preparation.tres"))
			deck.append(load("res://Data/Actions/counter_strike.tres"))
			
		CharacterData.ClassType.QUICK:
			deck.append(load("res://Data/Actions/roll_punch.tres"))
			deck.append(load("res://Data/Actions/weave.tres"))
			
		CharacterData.ClassType.TECHNICAL:
			deck.append(load("res://Data/Actions/discombobulate.tres"))
			deck.append(load("res://Data/Actions/hand_catch.tres"))
			
	return deck
