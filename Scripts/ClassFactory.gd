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
	1:[12,5], 2:[6,7], 3:[8,15], 4:[11,12], 5:[1,6], 6:[2,5,13,73], 7:[2,14,8,73], 8:[7,3],
	9:[15,16], 10:[11,19], 11:[4,10,20], 12:[4,1,13,20], 13:[12,6,21], 14:[7,15,21],
	15:[3,14,9,22], 16:[9,22,17], 17:[16,23], 18:[19,25], 19:[10,18,20,28], 20:[19,11,12,29],
	21:[13,14,29,31,30], 22:[15,16,23,31], 23:[22,17,24,32], 24:[23,26], 25:[18,27], 26:[24,33],
	27:[34,28,25,74], 28:[27,19,35], 29:[20,21,35], 30:[21], 31:[21,22,38], 32:[23,38,33],
	33:[32,26,39,75], 34:[27,40], 35:[28,41,29,42,36], 36:[35], 37:[38], 38:[31,32,44,45,37],
	39:[33,46], 40:[34,41,47,74], 41:[40,50,35], 42:[35,51,52], 43:[52], 44:[52,38,53],
	45:[38,46,54], 46:[45,48,75], 47:[40,49], 48:[46,55], 49:[47,50], 50:[49,41,51,56],
	51:[50,42,58,57], 52:[42,43,44,59,60], 53:[44,54,61,62], 54:[53,45,55,63], 55:[48,54],
	56:[50,57], 57:[56,51,64], 58:[51,64,59,70], 59:[52,66,58], 60:[52,67,61], 61:[53,72,69],
	62:[53,63,69], 63:[54,62], 64:[57,58], 65:[70,66], 66:[59,65,71,76], 67:[68,60,71,76],
	68:[67,72], 69:[61,62], 70:[58,65], 71:[66,67], 72:[68,61], 73:[2,6,7], 74:[34,27,40], 75:[39,33,46], 76:[71,66,67]
}

# Also need the ID-to-Name mapping for the generator to find files
const ID_TO_NAME_MAP = {
	1:"Toppling Kick", 2:"Pummel", 3:"One Two", 4:"Evading Dance", 5:"Slip Behind",
	6:"Adept Dodge", 7:"Adept Light", 8:"100 Hand Slap", 9:"Precise Strike", 10:"Breakout",
	11:"Read Offence", 12:"Quick Dodge", 13:"Master Dodge", 14:"Master Light", 15:"Flying Kick",
	16:"Vital Strike", 17:"Unassailable Stance", 18:"Strike Back", 19:"Leg Sweep", 20:"Catch",
	21:"Drop Prone", 22:"Perfect Strike", 23:"Step Up", 24:"Go with the Flow", 25:"Prime",
	26:"Inner Peace", 27:"Adept Reversal", 28:"Master Reversal", 29:"Untouchable Dodge",
	30:"Ultimate Barrage", 31:"Advancing Parry", 32:"Master Positioning", 33:"Adept Positioning",
	34:"Grab", 35:"Wind Up", 36:"Vital Point Assault", 37:"Overwhelming Aura", 38:"Parry Follow up",
	39:"Adjust Stance", 40:"Adept Tech", 41:"Master Tech", 42:"Crushing Block", 43:"Final Strike",
	44:"Redirect", 45:"Master Parry", 46:"Adept Parry", 47:"Throw", 48:"Resounding Parry",
	49:"Push", 50:"Twist Arm", 51:"Suplex", 52:"Perfect Block", 53:"Active Block",
	54:"Retreating Defence", 55:"Resounding Counter", 56:"Read Defence", 57:"Headbutt", 58:"Lariat",
	59:"Master Heavy", 60:"Master Block", 61:"Draining Defence", 62:"Slapping Parry", 63:"Tiring Parry",
	64:"Roundhouse Kick", 65:"Uppercut", 66:"Adept Heavy", 67:"Adept Block", 68:"Push Kick",
	69:"Drop Punch", 70:"Knee Crush", 71:"Drop Kick", 72:"Immovable Stance",
	73:"Quick", 74:"Technical", 75:"Patient", 76:"Heavy"
}

const CLASS_ROOT_IDS: Array[int] = [73, 74, 75, 76]

const AI_PRESETS: Array[AIBehavior] = [
	preload("res://Data/AI/AIAggressive.tres"),
	preload("res://Data/AI/AIBalanced.tres"),
	preload("res://Data/AI/AIDefensive.tres"),
	preload("res://Data/AI/AITrickster.tres"),
]

const BASIC_ACTION_TEMPLATES: Array[ActionData] = [
	preload("res://Data/Actions/basic_light.tres"),
	preload("res://Data/Actions/basic_heavy.tres"),
	preload("res://Data/Actions/basic_technical.tres"),
	preload("res://Data/Actions/basic_positioning.tres"),
	preload("res://Data/Actions/basic_block.tres"),
	preload("res://Data/Actions/basic_dodge.tres"),
	preload("res://Data/Actions/basic_parry.tres"),
	preload("res://Data/Actions/basic_reversal.tres"),
]

const HAND_LIMIT: int = 8

var bot_names: Array[String] = []

func _ready() -> void:
	_load_bot_names()

## Picks a random AI resource preset for a generated run enemy.
func pick_random_ai_profile() -> AIBehavior:
	if AI_PRESETS.is_empty():
		return null
	return AI_PRESETS.pick_random()

func _load_bot_names() -> void:
	var file_path: String = "res://Data/enemy_names.txt"
	if FileAccess.file_exists(file_path):
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		while not file.eof_reached():
			var line: String = file.get_line().strip_edges() # Remove extra spaces/newlines
			if line != "":
				bot_names.append(line)
		file.close()
	else:
		push_warning("Could not find enemy_names.txt! Using fallbacks.")
		bot_names = ["Fighter A", "Fighter B", "Challenger"]

## Creates a procedurally leveled fighter of a specific class (shared by Circuit enemy generation and balance runners).
func create_leveled_fighter(
	selected_class: CharacterData.ClassType,
	level: int,
	full_library: bool = false,
	label: String = ""
) -> CharacterData:
	var display_name: String = label
	if display_name == "":
		display_name = bot_names.pick_random() if bot_names.size() > 0 else "Challenger"

	var bot_data: CharacterData = create_character(selected_class, display_name, full_library)
	bot_data.ai_profile = pick_random_ai_profile()

	# 1. Draft extra cards from the class's skill tree (respecting Counter X -> Create Opening >= X)
	var cards_to_draft: int = maxi(0, level + 1) if level > 1 or not full_library else 0
	if level > 1 or not full_library:
		var owned_ids: Array[int] = []
		var unlockable_options: Array[int] = []
		var root_id: int = 76
		match selected_class:
			CharacterData.ClassType.QUICK: root_id = 73
			CharacterData.ClassType.TECHNICAL: root_id = 74
			CharacterData.ClassType.PATIENT: root_id = 75
			CharacterData.ClassType.HEAVY: root_id = 76

		owned_ids.append(root_id)
		if root_id in TREE_CONNECTIONS:
			for neighbor: int in TREE_CONNECTIONS[root_id]:
				unlockable_options.append(neighbor)

		for _i: int in range(cards_to_draft):
			var eligible_ids: Array[int] = []
			for cand_id: int in unlockable_options:
				var cand_name: Variant = ID_TO_NAME_MAP.get(cand_id)
				if cand_name != null:
					var cand_card: ActionData = find_action_resource(str(cand_name))
					if cand_card and can_draft_action(cand_card, bot_data.unlocked_actions):
						eligible_ids.append(cand_id)
			if eligible_ids.is_empty():
				break

			var picked_id: int = eligible_ids.pick_random()
			var card_name: Variant = ID_TO_NAME_MAP.get(picked_id)
			if card_name != null:
				var new_card: ActionData = find_action_resource(str(card_name))
				if new_card and not _has_card(bot_data.unlocked_actions, new_card):
					bot_data.unlocked_actions.append(new_card)

			owned_ids.append(picked_id)
			unlockable_options.erase(picked_id)

			if picked_id in TREE_CONNECTIONS:
				for neighbor: int in TREE_CONNECTIONS[picked_id]:
					if neighbor not in owned_ids and neighbor not in unlockable_options:
						unlockable_options.append(neighbor)

	# 2. Build active hand
	if full_library:
		bot_data.deck = bot_data.unlocked_actions.duplicate()
	else:
		bot_data.deck = _select_smart_hand(bot_data.unlocked_actions)

	# 3. Linear stat scaling (skipping zero)
	var stat_bonus: int = (level - 1) if level > 0 else level
	if stat_bonus > 0:
		var hp_gain: int = randi_range(0, stat_bonus)
		var sp_gain: int = stat_bonus - hp_gain
		bot_data.max_hp += hp_gain
		bot_data.max_sp += sp_gain
	elif stat_bonus < 0:
		var hp_loss: int = randi_range(stat_bonus, 0)
		var sp_loss: int = stat_bonus - hp_loss
		bot_data.max_hp = maxi(1, bot_data.max_hp + hp_loss)
		bot_data.max_sp = maxi(1, bot_data.max_sp + sp_loss)

	bot_data.max_hp = maxi(1, bot_data.max_hp)
	bot_data.max_sp = maxi(1, bot_data.max_sp)
	bot_data.current_hp = bot_data.max_hp
	bot_data.current_sp = bot_data.max_sp
	return bot_data


func create_random_enemy(level: int, _difficulty: GameManager.Difficulty) -> CharacterData:
	var types: Array[CharacterData.ClassType] = [
		CharacterData.ClassType.HEAVY,
		CharacterData.ClassType.QUICK,
		CharacterData.ClassType.TECHNICAL,
		CharacterData.ClassType.PATIENT,
	]
	var selected_class: CharacterData.ClassType = types.pick_random()
	var bot_data: CharacterData = create_leveled_fighter(selected_class, level, false)
	print("\n=== ENEMY GENERATED (" + str(selected_class) + ") ===")
	print("Level: " + str(level) + " | Name: " + bot_data.character_name)
	print("HP: " + str(bot_data.max_hp) + " | SP: " + str(bot_data.max_sp))
	print("==============================\n")
	return bot_data

## Returns the signature Super card for a given fighting class.
func get_class_super(type: CharacterData.ClassType) -> ActionData:
	match type:
		CharacterData.ClassType.QUICK:
			return find_action_resource("Ultimate Barrage")
		CharacterData.ClassType.TECHNICAL:
			return find_action_resource("Vital Point Assault")
		CharacterData.ClassType.PATIENT:
			return find_action_resource("Overwhelming Aura")
		CharacterData.ClassType.HEAVY:
			return find_action_resource("Final Strike")
	return null

## Procedurally generates a scaling boss fighter with one or more BossModifierData traits.
func create_boss_enemy(level: int, difficulty: GameManager.Difficulty, modifiers: Array[EquipmentData]) -> CharacterData:
	var boss: CharacterData = create_random_enemy(level, difficulty)
	var ai_assigned: bool = false
	var should_grant_super: bool = false

	for mod: EquipmentData in modifiers:
		if mod == null:
			continue
		var mod_copy: EquipmentData = mod.duplicate(true) as EquipmentData
		boss.equipment.append(mod_copy)
		boss.max_hp = max(1, boss.max_hp + mod_copy.bonus_max_hp)
		boss.max_sp = max(1, boss.max_sp + mod_copy.bonus_max_sp)

		if not ai_assigned:
			var pref_ai: Variant = mod_copy.get("preferred_ai_profile")
			if pref_ai is AIBehavior:
				boss.ai_profile = pref_ai
				ai_assigned = true

		if mod_copy.get("grant_super") == true:
			should_grant_super = true

	if should_grant_super:
		var super_card: ActionData = get_class_super(boss.class_type)
		if super_card != null:
			var super_copy: ActionData = super_card.duplicate() as ActionData
			if not _has_card(boss.unlocked_actions, super_copy):
				boss.unlocked_actions.append(super_copy)
			if not _has_card(boss.deck, super_copy):
				if boss.deck.size() >= HAND_LIMIT:
					var replace_idx: int = -1
					for idx in range(boss.deck.size() - 1, -1, -1):
						var existing: ActionData = boss.deck[idx]
						if existing.is_basic and not existing.is_opener:
							replace_idx = idx
							break
					if replace_idx == -1:
						replace_idx = boss.deck.size() - 1
					boss.deck[replace_idx] = super_copy
				else:
					boss.deck.append(super_copy)

	boss.current_hp = boss.max_hp
	boss.current_sp = boss.max_sp
	return boss

# -------------------------------------------------------------------------
# NEW HELPERS (Needed for the above code)
# -------------------------------------------------------------------------

func _has_card(list: Array, card: ActionData) -> bool:
	for c in list:
		if c.display_name == card.display_name: return true
	return false

## Returns true if [param card] can be drafted/equipped given [param owned_actions].
## Counter X cards require an owned action with Create Opening >= X.
func can_draft_action(card: ActionData, owned_actions: Array[ActionData]) -> bool:
	if card == null:
		return false
	if card.counter_value <= 0:
		return true
	var max_opening: int = 0
	for owned: ActionData in owned_actions:
		if owned and owned.create_opening > max_opening:
			max_opening = owned.create_opening
	return max_opening >= card.counter_value

func _pop_first_eligible(list: Array[ActionData], chosen: Array[ActionData]) -> ActionData:
	for i in range(list.size()):
		if can_draft_action(list[i], chosen):
			var picked: ActionData = list[i]
			list.remove_at(i)
			return picked
	return null

func _select_smart_hand(pool: Array[ActionData]) -> Array[ActionData]:
	# If we have 8 or fewer, just take them all
	if pool.size() <= HAND_LIMIT:
		return pool.duplicate()

	var chosen: Array[ActionData] = []
	var off_special: Array[ActionData] = []
	var off_basic: Array[ActionData] = []
	var def_special: Array[ActionData] = []
	var def_basic: Array[ActionData] = []

	for card: ActionData in pool:
		if card.type == ActionData.Type.OFFENCE:
			if card.is_basic:
				off_basic.append(card)
			else:
				off_special.append(card)
		else:
			if card.is_basic:
				def_basic.append(card)
			else:
				def_special.append(card)

	# Shuffle each bucket so bots with overlapping pools get distinct, varied hands
	off_special.shuffle()
	off_basic.shuffle()
	def_special.shuffle()
	def_basic.shuffle()

	var off_ordered: Array[ActionData] = []
	off_ordered.append_array(off_special)
	off_ordered.append_array(off_basic)

	var def_ordered: Array[ActionData] = []
	def_ordered.append_array(def_special)
	def_ordered.append_array(def_basic)

	# 1. Guarantee at least 1 affordable Opener (cost <= 2) so the deck can enter Neutral/combos
	for i in range(off_ordered.size()):
		if off_ordered[i].is_opener and off_ordered[i].cost <= 2 and can_draft_action(off_ordered[i], chosen):
			chosen.append(off_ordered[i])
			off_ordered.remove_at(i)
			break

	# 1b. Guarantee at least 1 low-cost (0-1 SP) Offence card so bots always have an affordable attack/follow-up
	var has_cheap_off: bool = false
	for c: ActionData in chosen:
		if c.type == ActionData.Type.OFFENCE and c.cost <= 1:
			has_cheap_off = true
			break
	if not has_cheap_off:
		for i in range(off_ordered.size()):
			if off_ordered[i].cost <= 1 and can_draft_action(off_ordered[i], chosen):
				chosen.append(off_ordered[i])
				off_ordered.remove_at(i)
				break

	# 2. Guarantee at least 1 low-cost (0-1 SP) Defence card so the deck can recover SP cleanly
	for i in range(def_ordered.size()):
		if def_ordered[i].cost <= 1 and can_draft_action(def_ordered[i], chosen):
			chosen.append(def_ordered[i])
			def_ordered.remove_at(i)
			break

	# 3. Guarantee a balanced structural core (at least 3 Offence and 3 Defence total)
	#    Counter X cards are only added if a Create Opening >= X card is already in the hand!
	var off_count: int = 0
	var def_count: int = 0
	for c: ActionData in chosen:
		if c.type == ActionData.Type.OFFENCE:
			off_count += 1
		else:
			def_count += 1

	while off_count < 3 and chosen.size() < HAND_LIMIT:
		var next_off: ActionData = _pop_first_eligible(off_ordered, chosen)
		if next_off == null:
			break
		chosen.append(next_off)
		off_count += 1

	while def_count < 3 and chosen.size() < HAND_LIMIT:
		var next_def: ActionData = _pop_first_eligible(def_ordered, chosen)
		if next_def == null:
			break
		chosen.append(next_def)
		def_count += 1

	# 4. Fill remaining 2 flex slots randomly (preferring drafted specials, then basics)
	#    while still enforcing the Counter X -> Create Opening >= X hand requirement
	var flex_special: Array[ActionData] = []
	var flex_basic: Array[ActionData] = []
	for c: ActionData in off_ordered:
		if c.is_basic: flex_basic.append(c)
		else: flex_special.append(c)
	for c: ActionData in def_ordered:
		if c.is_basic: flex_basic.append(c)
		else: flex_special.append(c)

	flex_special.shuffle()
	flex_basic.shuffle()

	while chosen.size() < HAND_LIMIT:
		var next_flex: ActionData = _pop_first_eligible(flex_special, chosen)
		if next_flex == null:
			next_flex = _pop_first_eligible(flex_basic, chosen)
		if next_flex == null:
			break
		chosen.append(next_flex)

	return chosen

# Helper for string names
func class_enum_to_string(type: int) -> String:
	# --- NEW: MANUAL OVERRIDE FOR THE TUTORIAL CLASS ---
	if type == CharacterData.ClassType.NONE:
		return "Trainee"
	# ---------------------------------------------------

	var keys = CharacterData.ClassType.keys()
	
	# Safety check to make sure the integer is within the Enum's bounds
	if type >= 0 and type < keys.size():
		# .keys() returns an array of strings like ["HEAVY", "PATIENT", "QUICK", "TECHNICAL"]
		# .capitalize() turns "HEAVY" into "Heavy"
		return keys[type].capitalize()
		
	return "Enemy"
	
# Generates a fully playable CharacterData resource based on the chosen class
func create_character(type: CharacterData.ClassType, player_name: String, bypass_deck_limit: bool = false) -> CharacterData:
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
	
	# --- COPY PASSIVES ---
	char_data.can_pay_with_hp = def.can_pay_with_hp
	char_data.tiring_drains_hp = def.tiring_drains_hp
	char_data.combo_sp_recovery_rate = def.combo_sp_recovery_rate
	char_data.has_bide_mechanic = def.has_bide_mechanic
	char_data.has_keep_up_toggle = def.has_keep_up_toggle
	char_data.has_technique_dropdown = def.has_technique_dropdown
	
	# 2. Library (Duplicate the array so we don't modify the Resource)
	char_data.unlocked_actions = get_starting_deck(type)
	
	# --- 3. SELECT HAND (WITH MULTIPLAYER OVERRIDE) ---
	if bypass_deck_limit:
		# Give them absolutely everything in their library
		char_data.deck = char_data.unlocked_actions.duplicate()
	else:
		# Standard 8-card cull for Bots/Arcade enemies
		char_data.deck = _select_smart_hand(char_data.unlocked_actions)
	
	# Assign a random modular AI profile by default (can be overridden by bosses/presets)
	if char_data.ai_profile == null:
		char_data.ai_profile = pick_random_ai_profile()
	
	char_data.reset_stats()
	return char_data

# In ClassFactory.gd

func get_starting_deck(type: CharacterData.ClassType) -> Array[ActionData]:
	var deck: Array[ActionData] = []
	
	# 1. AUTO-ADD BASICS (Code handles this)
	deck.append_array(get_basic_actions()) 
	
	# 2. ADD CLASS SPECIFICS (Resource handles this)
	if class_registry.has(type):
		var def = class_registry[type]
		for card in def.starting_deck:
			# Duplicate to ensure unique runtime instances
			if card: deck.append(card.duplicate())
			
	return deck

func create_from_preset(preset: PresetCharacter, bypass_deck_limit: bool = false) -> CharacterData:
	# 1. Start with the Base Class, passing our limit override!
	var char_data = create_character(preset.class_type, preset.character_name, bypass_deck_limit)
	
	# 2. Add the Extra Skills defined in the preset
	for skill_name in preset.extra_skills:
		var card = find_action_resource(skill_name)
		if card:
			# Safety check: Only append it if they don't already have it
			if not _has_card(char_data.deck, card):
				char_data.deck.append(card)
			if not _has_card(char_data.unlocked_actions, card):
				char_data.unlocked_actions.append(card)
		else:
			printerr("Warning: Preset '" + preset.character_name + "' could not find skill: " + skill_name)

	# 3. Always full-heal preset fighters (never affected by RunManager.is_arcade_mode)
	var result: Dictionary = calculate_stats_for_deck(char_data.class_type, char_data.unlocked_actions, char_data.equipment)
	char_data.max_hp = int(result["hp"])
	char_data.max_sp = int(result["sp"])
	char_data.current_hp = char_data.max_hp
	char_data.current_sp = char_data.max_sp
	
	return char_data

func _recalculate_stats(char_data: CharacterData) -> void:
	var old_max_hp: int = char_data.max_hp
	var result: Dictionary = calculate_stats_for_deck(char_data.class_type, char_data.unlocked_actions, char_data.equipment)
	char_data.max_hp = int(result["hp"])
	char_data.max_sp = int(result["sp"])
	
	if RunManager.is_arcade_mode and RunManager.maintain_hp_enabled:
		var hp_growth: int = char_data.max_hp - old_max_hp
		char_data.current_hp += hp_growth
		char_data.current_sp = char_data.max_sp
	else:
		char_data.current_hp = char_data.max_hp
		char_data.current_sp = char_data.max_sp


func find_action_resource(action_name: String) -> ActionData:
	var clean_name: String = action_name.to_lower().replace(" ", "_")
	var common_path: String = "res://Data/Actions/" + clean_name + ".tres"
	if ResourceLoader.exists(common_path):
		return load(common_path) as ActionData
	return null


func calculate_stats_for_deck(type: CharacterData.ClassType, _deck: Array[ActionData], equipment: Array[EquipmentData] = []) -> Dictionary:
	if not class_registry.has(type): return {"hp": 5, "sp": 4}
	
	var def: ClassDefinition = class_registry[type]
	var final_hp: int = def.base_hp
	var final_sp: int = def.base_sp
	
	for item: EquipmentData in equipment:
		final_hp += item.bonus_max_hp
		final_sp += item.bonus_max_sp
			
	return {"hp": maxi(1, final_hp), "sp": maxi(1, final_sp)}


## Case-insensitive reverse lookup for skill-tree reward IDs (fixes "Step up" / "Wind up" casing).
func get_id_by_name(card_name: String) -> int:
	var target: String = card_name.strip_edges().to_lower()
	for id: int in ID_TO_NAME_MAP:
		if str(ID_TO_NAME_MAP[id]).to_lower() == target:
			return id
	return 0


func get_basic_actions() -> Array[ActionData]:
	var basics: Array[ActionData] = []
	for tmpl: ActionData in BASIC_ACTION_TEMPLATES:
		basics.append(tmpl.duplicate() as ActionData)
	return basics
