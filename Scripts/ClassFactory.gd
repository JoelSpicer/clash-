extends Node
# --- SHARED DATA: THE SKILL TREE MAP ---
# (Moved here so both the UI and the Enemy Generator can read it)
const TREE_CONNECTIONS = {
	1:[12,5], 2:[6,7], 3:[8,15], 4:[11,12], 5:[1,6], 6:[2,5,13], 7:[2,14,8], 8:[7,3],
	9:[15,16], 10:[11,19], 11:[4,10,20], 12:[4,1,13,20], 13:[12,6,21], 14:[7,15,21],
	15:[3,14,9,22], 16:[9,22,17], 17:[16,23], 18:[19,25], 19:[10,18,20,28], 20:[19,11,12,29],
	21:[13,14,29,31,30], 22:[15,16,23,31], 23:[22,17,24,32], 24:[23,26], 25:[18,27], 26:[24,33],
	27:[34,28,25], 28:[27,19,35], 29:[20,21,35], 30:[21], 31:[21,22,38], 32:[23,38,33],
	33:[32,26,39], 34:[27,40], 35:[28,41,29,42,36], 36:[35], 37:[38], 38:[31,32,44,45,37],
	39:[33,46], 40:[34,41,47], 41:[40,50,35], 42:[35,51,52], 43:[52], 44:[52,38,53],
	45:[38,46,54], 46:[45,48], 47:[40,49], 48:[46,55], 49:[47,50], 50:[49,41,51,56],
	51:[50,42,58,57], 52:[42,43,44,59,60], 53:[44,54,61,62], 54:[53,45,55,63], 55:[48,54],
	56:[50,57], 57:[56,51,64], 58:[51,64,59,70], 59:[52,66,58], 60:[52,67,61], 61:[53,72,69],
	62:[53,63,69], 63:[54,62], 64:[57,58], 65:[70,66], 66:[59,65,71], 67:[68,60,71],
	68:[67,72], 69:[61,62], 70:[58,65], 71:[66,67], 72:[68,61], 73:[2], 74:[34], 75:[39], 76:[71]
}

# Also need the ID-to-Name mapping for the generator to find files
const ID_TO_NAME_MAP = {
	1:"Toppling Kick", 2:"Pummel", 3:"One Two", 4:"Evading Dance", 5:"Slip Behind",
	6:"Adept Dodge", 7:"Adept Light", 8:"Hundred Hand Slap", 9:"Precise Strike", 10:"Breakout",
	11:"Read Offence", 12:"Quick Dodge", 13:"Master Dodge", 14:"Master Light", 15:"Flying Kick",
	16:"Vital Strike", 17:"Unassailable Stance", 18:"Strike Back", 19:"Leg Sweep", 20:"Catch",
	21:"Drop Prone", 22:"Perfect Strike", 23:"Step Up", 24:"Go with the Flow", 25:"Prime",
	26:"Inner Peace", 27:"Adept Reversal", 28:"Master Reversal", 29:"Untouchable Dodge",
	30:"Ultimate Barrage", 31:"Advancing Parry", 32:"Master Positioning", 33:"Adept Positioning",
	34:"Grab", 35:"Wind Up", 36:"Vital Point Assault", 37:"Overwhelming Aura", 38:"Parry FollowUp",
	39:"Adjust Stance", 40:"Adept Tech", 41:"Master Tech", 42:"Crushing Block", 43:"Final Strike",
	44:"Redirect", 45:"Master Parry", 46:"Adept Parry", 47:"Throw", 48:"Resounding Parry",
	49:"Push", 50:"Twist Arm", 51:"Suplex", 52:"Perfect Block", 53:"Active Block",
	54:"Retreating Defence", 55:"Resounding Counter", 56:"Read Defence", 57:"Headbutt", 58:"Lariat",
	59:"Master Heavy", 60:"Master Block", 61:"Draining Defence", 62:"Slapping Parry", 63:"Tiring Parry",
	64:"Roundhouse Kick", 65:"Uppercut", 66:"Adept Heavy", 67:"Adept Block", 68:"Push Kick",
	69:"Drop Punch", 70:"Knee Crush", 71:"Drop Kick", 72:"Immovable Stance",
	73:"Quick", 74:"Technical", 75:"Patient", 76:"Heavy"
}

# --- NEW: ENEMY GENERATOR ---
func create_random_enemy(level: int, difficulty: GameManager.Difficulty) -> CharacterData:
	# 1. Pick a Random Class
	var classes = [CharacterData.ClassType.HEAVY, CharacterData.ClassType.QUICK, CharacterData.ClassType.TECHNICAL, CharacterData.ClassType.PATIENT]
	var selected_class = classes.pick_random()
	var bot_name = "Lv." + str(level) + " " + _class_enum_to_string(selected_class)
	
	var bot_data = create_character(selected_class, bot_name)
	
	# 2. Identify Starting Node
	var start_node = 76 # Heavy
	match selected_class:
		CharacterData.ClassType.QUICK: start_node = 73
		CharacterData.ClassType.TECHNICAL: start_node = 74
		CharacterData.ClassType.PATIENT: start_node = 75
		CharacterData.ClassType.HEAVY: start_node = 76
	# 3. Walk the tree to simulate leveling up
	# Level 1 = 0 extra cards. Level 5 = 4 extra cards.
	var extra_cards_count = max(0, level - 1)
	
	var owned_ids = [start_node]
	var available_ids = []
	
	# Initial unlock
	_add_neighbors_to_list(start_node, owned_ids, available_ids)
	
	for i in range(extra_cards_count):
		if available_ids.is_empty(): break
		
		# Pick a random valid neighbor
		var new_id = available_ids.pick_random()
		
		# Add to bot
		owned_ids.append(new_id)
		
		# Update available pool
		available_ids.erase(new_id)
		_add_neighbors_to_list(new_id, owned_ids, available_ids)
		
		# Actually add the card resource to the deck
		var card_name = ID_TO_NAME_MAP.get(new_id)
		if card_name:
			var card = _find_action_resource(card_name)
			if card: bot_data.deck.append(card)
	
	# 4. Recalculate stats based on the new deck
	_recalculate_stats(bot_data)
	
	# --- NEW: DEBUG PRINT ---
	print("\n=== ARCADE ENEMY GENERATED ===")
	print("Name: " + bot_data.character_name)
	print("Stats: HP " + str(bot_data.max_hp) + " | SP " + str(bot_data.max_sp))
	print("Deck List (" + str(bot_data.deck.size()) + " Actions):")
	
	for card in bot_data.deck:
		print(" - " + card.display_name + " (" + ("Offence" if card.type == 0 else "Defence") + ")")
		
	print("==============================\n")
	# ------------------------
	
	return bot_data

func _add_neighbors_to_list(node_id: int, owned: Array, available: Array):
	if node_id in TREE_CONNECTIONS:
		for neighbor in TREE_CONNECTIONS[node_id]:
			if neighbor not in owned and neighbor not in available:
				available.append(neighbor)

# Helper for string names
func _class_enum_to_string(type: int) -> String:
	match type:
		CharacterData.ClassType.HEAVY: return "Bruiser"
		CharacterData.ClassType.PATIENT: return "Defender"
		CharacterData.ClassType.QUICK: return "Speedster"
		CharacterData.ClassType.TECHNICAL: return "Tactician"
	return "Enemy"
# Generates a fully playable CharacterData resource based on the chosen class
func create_character(class_type: CharacterData.ClassType, player_name: String) -> CharacterData:
	var char_data = CharacterData.new()
	char_data.character_name = player_name
	char_data.class_type = class_type
	
	# 1. Set Base Stats & Passives
	match class_type:
		CharacterData.ClassType.HEAVY:
			char_data.max_hp = 10
			char_data.max_sp = 3
			char_data.speed = 1
			char_data.passive_desc = "RAGE: Pay HP instead of SP if stamina is low."
			
		CharacterData.ClassType.PATIENT:
			char_data.max_hp = 10
			char_data.max_sp = 3
			char_data.speed = 2
			char_data.passive_desc = "KEEP-UP: Spend SP to prevent Falling Back."
			
		CharacterData.ClassType.QUICK:
			char_data.max_hp = 10
			char_data.max_sp = 3
			char_data.speed = 4
			char_data.passive_desc = "RELENTLESS: Every 3rd combo hit recovers 1 SP."
			
		CharacterData.ClassType.TECHNICAL:
			char_data.max_hp = 10
			char_data.max_sp = 3
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
	# Ask the master calculator for the numbers
	var result = calculate_stats_for_deck(char_data.class_type, char_data.deck)
	
	# Apply them
	char_data.max_hp = result["hp"]
	char_data.max_sp = result["sp"]
	char_data.current_hp = result["hp"]
	char_data.current_sp = result["sp"]


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

# New Helper Function: Accepts a Class Type and a List of Cards -> Returns Stats
func calculate_stats_for_deck(class_type: CharacterData.ClassType, deck: Array[ActionData]) -> Dictionary:
	var final_hp = 10
	var final_sp = 3
	
	# 1. Get the list of "Free" cards to ignore (Starters + Basic)
	# We reuse your existing logic here to ensure consistency
	var starter_deck = get_starting_deck(class_type)
	var ignore_names: Array[String] = []
	for c in starter_deck:
		ignore_names.append(c.display_name)
		
	# 2. Iterate through the provided deck
	for card in deck:
		# Safety Check
		if card == null: continue
		
		# Skip cards that shouldn't give stats (Starters or explicitly "Basic")
		if card.display_name in ignore_names or card.display_name.begins_with("Basic"):
			continue
			
		# 3. Apply the Class Growth Rules (The "One True Logic")
		match class_type:
			CharacterData.ClassType.QUICK:
				if card.type == ActionData.Type.OFFENCE: final_hp += 1
				elif card.type == ActionData.Type.DEFENCE: final_sp += 2
				
			CharacterData.ClassType.TECHNICAL:
				if card.type == ActionData.Type.OFFENCE: 
					final_hp += 1; final_sp += 1
				elif card.type == ActionData.Type.DEFENCE: 
					final_sp += 1
					
			CharacterData.ClassType.PATIENT:
				if card.type == ActionData.Type.OFFENCE: final_hp += 1
				elif card.type == ActionData.Type.DEFENCE:
					final_hp += 1; final_sp += 1
					
			CharacterData.ClassType.HEAVY:
				if card.type == ActionData.Type.OFFENCE: final_sp += 1
				elif card.type == ActionData.Type.DEFENCE: final_hp += 2
				
	return {"hp": final_hp, "sp": final_sp}
