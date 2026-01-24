extends Node

# Map Enum -> Resource Path
var class_registry = {
	CharacterData.ClassType.HEAVY: preload("res://Data/Classes/HeavyClass.tres"),
	CharacterData.ClassType.PATIENT: preload("res://Data/Classes/PatientClass.tres"),
	CharacterData.ClassType.QUICK: preload("res://Data/Classes/QuickClass.tres"),
	CharacterData.ClassType.TECHNICAL: preload("res://Data/Classes/TechnicalClass.tres")
}
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

const RANK_TITLES = [
	"Foolish",      # Level 1
	"Weak",         # Level 2
	"Clumsy",       # Level 3
	"Novice",       # Level 4
	"Beginner",     # Level 5
	"Rookie",       # Level 6
	"Apprentice",   # Level 7
	"Capable",      # Level 8
	"Competent",    # Level 9
	"Adept",        # Level 10
	"Seasoned",     # Level 11
	"Expert",       # Level 12
	"Veteran",      # Level 13
	"Elite",        # Level 14
	"Master",       # Level 15
	"Grandmaster",  # Level 16
	"Legendary",    # Level 17
	"Mythic",       # Level 18
	"Transcendent", # Level 19
	"Godly"         # Level 20+
]

var art_heavy = preload("res://Art/Portraits/Heavy.png") 
var art_patient = preload("res://Art/Portraits/Patient.png")
var art_quick = preload("res://Art/Portraits/Quick.png")
var art_technical = preload("res://Art/Portraits/Technical.png")

const HAND_LIMIT = 8

# --- NEW: ENEMY GENERATOR ---
func create_random_enemy(level: int, _difficulty: GameManager.Difficulty) -> CharacterData:
	# 1. Pick a Random Class
	var types = [
		CharacterData.ClassType.HEAVY, 
		CharacterData.ClassType.QUICK, 
		CharacterData.ClassType.TECHNICAL, 
		CharacterData.ClassType.PATIENT
	]
	var selected_class = types.pick_random()
	
	# 2. Create the Base Character (Starter Library)
	# Note: This assumes create_character() correctly populates unlocked_actions
	var bot_data = create_character(selected_class, "Lv." + str(level) + " Bot")
	
	# --- ASSIGN RANDOM PERSONALITY ---
	var personalities = CharacterData.AIArchetype.values()
	bot_data.ai_archetype = personalities.pick_random()
	
	# A. Get Rank Title based on Level
	var title_index = clampi(level - 1, 0, RANK_TITLES.size() - 1)
	var rank_title = RANK_TITLES[title_index]
	
	# Flavor: Rename the bot based on its brain
	var prefix = ""
	match bot_data.ai_archetype:
		CharacterData.AIArchetype.AGGRESSIVE: prefix = "Furious "
		CharacterData.AIArchetype.DEFENSIVE: prefix = "Guarded "
		CharacterData.AIArchetype.TRICKSTER: prefix = "Tricky "
		CharacterData.AIArchetype.BALANCED: prefix = "Steady "
	
	bot_data.character_name = rank_title + " " + prefix + class_enum_to_string(selected_class)
	
	# 3. Calculate how many extra cards they get (Library expansion)
	var cards_to_draft = level + 1
	
	# 4. "Draft" cards legally by walking the tree
	var owned_ids = []
	var unlockable_options = []
	
	# Identify the starting Root Node for this class
	var root_id = 0
	match selected_class:
		CharacterData.ClassType.QUICK: root_id = 73
		CharacterData.ClassType.TECHNICAL: root_id = 74
		CharacterData.ClassType.PATIENT: root_id = 75
		CharacterData.ClassType.HEAVY: root_id = 76
	
	# Initialize the 'shop' with the root's neighbors
	owned_ids.append(root_id)
	if root_id in TREE_CONNECTIONS:
		for neighbor in TREE_CONNECTIONS[root_id]:
			unlockable_options.append(neighbor)
			
	# Draft Loop
	for i in range(cards_to_draft):
		if unlockable_options.is_empty():
			break 
			
		# Pick a random valid card
		var picked_id = unlockable_options.pick_random()
		
		# "Buy" it -> Add to LIBRARY (unlocked_actions), NOT Deck
		var card_name = ID_TO_NAME_MAP.get(picked_id)
		if card_name:
			var new_card = find_action_resource(card_name)
			# Ensure we don't add duplicates to the library
			if new_card and not _has_card(bot_data.unlocked_actions, new_card):
				bot_data.unlocked_actions.append(new_card)
		
		# Update the tree state for the next pick
		owned_ids.append(picked_id)
		unlockable_options.erase(picked_id)
		
		# Add new neighbors to the pool
		if picked_id in TREE_CONNECTIONS:
			for neighbor in TREE_CONNECTIONS[picked_id]:
				if neighbor not in owned_ids and neighbor not in unlockable_options:
					unlockable_options.append(neighbor)
	
	# 5. CUT DOWN TO 8 (The Smart Selection)
	# Select the best hand from the large library we just built
	bot_data.deck = _select_smart_hand(bot_data.unlocked_actions, bot_data.ai_archetype)
	
	# 6. Recalculate stats based on the ACTIVE deck
	_recalculate_stats(bot_data)
	
	# Debug Print to verify
	print("\n=== ENEMY GENERATED (" + str(selected_class) + ") ===")
	print("Level: " + str(level) + " | Drafted: " + str(cards_to_draft))
	print("Library Size: " + str(bot_data.unlocked_actions.size()))
	print("Active Deck: " + str(bot_data.deck.size()))
	print("HP: " + str(bot_data.max_hp) + " | SP: " + str(bot_data.max_sp))
	print("==============================\n")
	
	return bot_data

# -------------------------------------------------------------------------
# NEW HELPERS (Needed for the above code)
# -------------------------------------------------------------------------

func _has_card(list: Array, card: ActionData) -> bool:
	for c in list:
		if c.display_name == card.display_name: return true
	return false

func _select_smart_hand(pool: Array[ActionData], _archetype: CharacterData.AIArchetype) -> Array[ActionData]:
	# If we have 8 or fewer, just take them all
	if pool.size() <= HAND_LIMIT:
		return pool.duplicate()
		
	var chosen: Array[ActionData] = []
	var remaining = pool.duplicate()
	
	# 1. PRIORITY: Always take Class Signatures (Non-Basic)
	# We prioritize "cool" cards over "Basic" ones
	for i in range(remaining.size() - 1, -1, -1):
		var c = remaining[i]
		if not c.display_name.begins_with("Basic"):
			chosen.append(c)
			remaining.remove_at(i)
			
	# 2. PRIORITY: Fill remaining slots with Basics
	remaining.shuffle()
	
	while chosen.size() < HAND_LIMIT and remaining.size() > 0:
		chosen.append(remaining.pop_back())
		
	# 3. SAFETY: Ensure at least 1 Opener
	# If we drafted a hand full of "Finishers" or "Cost 3" cards, the bot will break.
	var has_opener = false
	for c in chosen:
		if c.is_opener or c.cost == 0: has_opener = true
	
	if not has_opener:
		# Search the remaining pile for an opener
		for c in remaining:
			if c.is_opener or c.cost == 0:
				# Swap a random card out for this opener
				if chosen.size() > 0:
					chosen.pop_back() 
				chosen.append(c)
				break

	# 4. Trim if we somehow exceeded (though logic prevents it)
	if chosen.size() > HAND_LIMIT:
		chosen.resize(HAND_LIMIT)
		
	return chosen

func _add_neighbors_to_list(node_id: int, owned: Array, available: Array):
	if node_id in TREE_CONNECTIONS:
		for neighbor in TREE_CONNECTIONS[node_id]:
			if neighbor not in owned and neighbor not in available:
				available.append(neighbor)

# Helper for string names
func class_enum_to_string(type: int) -> String:
	match type:
		CharacterData.ClassType.HEAVY: return "Heavy"
		CharacterData.ClassType.PATIENT: return "Patient"
		CharacterData.ClassType.QUICK: return "Quick"
		CharacterData.ClassType.TECHNICAL: return "Technical"
	return "Enemy"
# Generates a fully playable CharacterData resource based on the chosen class
func create_character(type: CharacterData.ClassType, player_name: String) -> CharacterData:
	if not class_registry.has(type): return null
	
	var def: ClassDefinition = class_registry[type]
	var char_data = CharacterData.new()
	
	char_data.character_name = player_name
	char_data.class_type = type
	
	# 1. Base Stats from Resource
	char_data.max_hp = def.base_hp
	char_data.max_sp = def.base_sp
	char_data.speed = def.base_speed
	char_data.passive_desc = def.passive_description
	char_data.portrait = def.portrait
	
	# 2. Library (Duplicate the array so we don't modify the Resource)
	char_data.unlocked_actions = def.starting_deck.duplicate()
	
	# 3. Select Hand
	char_data.deck = _select_smart_hand(char_data.unlocked_actions, char_data.ai_archetype)
	
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
		var card = find_action_resource(skill_name)
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
	# 1. Snapshot old stats before we change them
	var old_max_hp = char_data.max_hp
	
	# 2. Calculate new stats
	var result = calculate_stats_for_deck(char_data.class_type, char_data.unlocked_actions)
	
	char_data.max_hp = result["hp"]
	char_data.max_sp = result["sp"]
	
	# --- 3. ROGUELIKE HP LOGIC ---
	if RunManager.is_arcade_mode and RunManager.maintain_hp_enabled:
		# Only heal them by the AMOUNT they grew (e.g., Max HP 5 -> 6 means heal 1 HP)
		var hp_growth = char_data.max_hp - old_max_hp
		char_data.current_hp += hp_growth
		char_data.current_sp = char_data.max_sp # SP always resets per fight
	else:
		# Standard Mode: Full Heal
		char_data.current_hp = char_data.max_hp
		char_data.current_sp = char_data.max_sp


# --- HELPER: Find Resource (Moved from ActionTree) ---
func find_action_resource(action_name: String) -> ActionData:
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
func calculate_stats_for_deck(type: CharacterData.ClassType, deck: Array[ActionData]) -> Dictionary:
	if not class_registry.has(type): return {"hp": 5, "sp": 4}
	
	var def: ClassDefinition = class_registry[type]
	var final_hp = def.base_hp
	var final_sp = def.base_sp
	
	# 1. Get Ignore List from the definition
	var ignore_names = []
	for c in def.starting_deck:
		ignore_names.append(c.display_name)
		
	# 2. Calculate
	for card in deck:
		if card == null: continue
		if card.display_name in ignore_names or card.display_name.begins_with("Basic"):
			continue
			
		# 3. GENERIC MATH (Reads from Resource)
		if card.type == ActionData.Type.OFFENCE:
			final_hp += def.offence_hp_growth
			final_sp += def.offence_sp_growth
		elif card.type == ActionData.Type.DEFENCE:
			final_hp += def.defence_hp_growth
			final_sp += def.defence_sp_growth
			
	return {"hp": final_hp, "sp": final_sp}

# NEW HELPER: Reverse lookup for Presets -> Tree Nodes
func get_id_by_name(card_name: String) -> int:
	for id in ID_TO_NAME_MAP:
		if ID_TO_NAME_MAP[id] == card_name:
			return id
	return 0 # Not found

func _simulate_draft_ids(class_type, count) -> Array:
	var root_id = 76 # Heavy
	match class_type:
		CharacterData.ClassType.QUICK: root_id = 73
		CharacterData.ClassType.TECHNICAL: root_id = 74
		CharacterData.ClassType.PATIENT: root_id = 75
	
	var owned = [root_id]
	var available = []
	_add_neighbors_to_list(root_id, owned, available)
	
	var results = []
	for i in range(count):
		if available.is_empty(): break
		var pick = available.pick_random()
		results.append(pick)
		owned.append(pick)
		available.erase(pick)
		_add_neighbors_to_list(pick, owned, available)
		
	return results
