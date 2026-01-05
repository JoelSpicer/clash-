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
	char_data.deck = get_starting_deck(class_type)
	
	# 3. Reset Runtime state
	char_data.reset_stats()
	return char_data

func get_starting_deck(type: CharacterData.ClassType) -> Array[ActionData]:
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

func create_from_preset(preset: PresetCharacter) -> CharacterData:
	# 1. Start with the Base Class (Starters + Basic Actions)
	var char_data = create_character(preset.class_type, preset.character_name)
	
	# 2. Add the Extra Skills defined in the preset
	for skill_name in preset.extra_skills:
		var card = _find_action_resource(skill_name)
		if card:
			# Avoid duplicates if necessary, or allow multiples if that's your game design
			char_data.deck.append(card)
		else:
			printerr("Warning: Preset '" + preset.character_name + "' could not find skill: " + skill_name)

	# 3. Auto-Calculate Stats based on Class Rules
	_recalculate_stats(char_data)
	
	return char_data

# --- HELPER: Stat Calculation Logic (Same rules as ActionTree) ---
# ClassFactory.gd

func _recalculate_stats(char_data: CharacterData):
	# Reset to base
	var hp = 10
	var sp = 3
	
	# 1. IDENTIFY CARDS TO IGNORE
	# We get the list of cards this class starts with automatically.
	# We shouldn't get stats for cards we didn't "unlock".
	var starter_deck = get_starting_deck(char_data.class_type)
	var ignore_list: Array[String] = []
	
	for c in starter_deck:
		ignore_list.append(c.display_name)
	
	# 2. CALCULATE STATS
	for card in char_data.deck:
		# SKIP STARTING CARDS (Basics + Class Starters)
		if card.display_name in ignore_list: 
			continue
		
		# Apply Growth Rules
		match char_data.class_type:
			CharacterData.ClassType.QUICK:
				if card.type == ActionData.Type.OFFENCE: hp += 1
				elif card.type == ActionData.Type.DEFENCE: sp += 2
				
			CharacterData.ClassType.TECHNICAL:
				if card.type == ActionData.Type.OFFENCE: 
					hp += 1; sp += 1
				elif card.type == ActionData.Type.DEFENCE: 
					sp += 1
					
			CharacterData.ClassType.PATIENT:
				if card.type == ActionData.Type.OFFENCE: hp += 1
				elif card.type == ActionData.Type.DEFENCE:
					hp += 1; sp += 1
					
			CharacterData.ClassType.HEAVY:
				if card.type == ActionData.Type.OFFENCE: sp += 1
				elif card.type == ActionData.Type.DEFENCE: hp += 2
	
	char_data.max_hp = hp
	char_data.max_sp = sp
	char_data.current_hp = hp
	char_data.current_sp = sp

# --- HELPER: Find Resource (Moved from ActionTree) ---
func _find_action_resource(action_name: String) -> ActionData:
	var clean_name = action_name.to_lower().replace(" ", "_")
	var filename = clean_name + ".tres"
	
	# Check Common folder
	var common_path = "res://Data/Actions/" + filename
	if ResourceLoader.exists(common_path): return load(common_path)
		
	# Check Class folders
	var class_folders = ["Heavy", "Patient", "Quick", "Technical"]
	for folder in class_folders:
		var class_path = "res://Data/Actions/Class/" + folder + "/" + filename
		if ResourceLoader.exists(class_path): return load(class_path)
			
	return null
