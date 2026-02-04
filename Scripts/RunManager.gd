extends Node

var is_arcade_mode: bool = false
var current_level: int = 1
var player_run_data: CharacterData
var player_owned_tree_ids: Array[int] = [] 
var free_unlocks_remaining: int = 0

# --- NEW: RUN MODIFIERS ---
var maintain_hp_enabled: bool = false
const EQUIPMENT_DIR = "res://Data/Equipment/"
const BOSS_DIR = "res://Data/Presets/Bosses/"

const BOSS_SCHEDULE = {
	5: "juggernaut_boss.tres",
	10: "grandmaster_boss.tres"
}

# ... (start_run and start_run_from_preset remain exactly the same) ...
var next_fight_statuses: Array[String] = []

# OPTION A: STANDARD RUN (Level 1, Drafting)
func start_run(starting_class: CharacterData.ClassType):
	is_arcade_mode = true
	current_level = 1
	player_run_data = ClassFactory.create_character(starting_class, "You")
	_init_tree_root(starting_class)
	free_unlocks_remaining = 1
	#player_run_data.equipment.append(load("res://Data/Equipment/EnergyDrink.tres"))
	SceneLoader.change_scene("res://Scenes/ActionTree.tscn")

# OPTION B: PRESET RUN
# 2. Preset Start (If you use Presets)
func start_run_from_preset(preset_data: CharacterData):
	# A. Deep Copy the preset so we don't modify the original resource
	player_run_data = preset_data.duplicate(true)
	
	# B. Reset Loop State
	current_level = 1
	player_owned_tree_ids.clear() # Presets might need manual ID setup if you want them to use the tree later
	
	# C. Ensure Class Root is unlocked (so Draft works later)
	_unlock_class_starters(player_run_data)
	
	# D. Route
	print("Starting Preset Run. Loading Deck Editor...")
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")

# Helper
func _init_tree_root(class_type: CharacterData.ClassType):
	#player_owned_tree_ids.clear()
	#match class_type:
		#CharacterData.ClassType.QUICK: player_owned_tree_ids.append(73)
		#CharacterData.ClassType.TECHNICAL: player_owned_tree_ids.append(74)
		#CharacterData.ClassType.PATIENT: player_owned_tree_ids.append(75)
		#CharacterData.ClassType.HEAVY: player_owned_tree_ids.append(76)
		
	player_owned_tree_ids.clear()
	
	# 1. Look up the Resource
	if ClassFactory.class_registry.has(class_type):
		var def = ClassFactory.class_registry[class_type]
		
		# 2. Read the Start Node from the File
		if def.skill_tree_root_id != 0:
			player_owned_tree_ids.append(def.skill_tree_root_id)
			return

	# Fallback (Safety)
	player_owned_tree_ids.append(76)

# --- UPDATED FIGHT GENERATION LOGIC ---
func start_next_fight():
	
	# --- NEW: APPLY EVENT STATUSES ---
	#for status in next_fight_statuses:
		#player_run_data.statuses[status] = 1
	#next_fight_statuses.clear() # Reset for the future
	# ---------------------------------
	
	# 1. Setup Player
	GameManager.next_match_p1_data = player_run_data
	AudioManager.play_music("battle_theme")
	# --- NEW: RANDOMIZE ENVIRONMENT ---
	var envs = ["Ring", "Dojo", "Street"]
	var selected_env = envs.pick_random()
	GameManager.apply_environment_rules(selected_env)
	# ----------------------------------
	
	# 2. CALCULATE TARGET LEVEL
	var raw_level = current_level
	
	# Apply Difficulty Modifier
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: raw_level -= 2
		GameManager.Difficulty.EASY:      raw_level -= 1
		GameManager.Difficulty.MEDIUM:    pass 
		GameManager.Difficulty.HARD:      raw_level += 1
	
	# 3. DETERMINE ACTUAL LEVEL & PENALTIES
	var final_enemy_level = raw_level
	var stat_penalty = 0
	
	if raw_level < 1:
		# If we dip below Level 1, stick to Level 1 but apply penalty.
		# Example: Level 1 on Very Easy (-2) = Raw -1. 
		# Penalty = 1 - (-1) = 2.
		stat_penalty = 1 - raw_level
		final_enemy_level = 1
		
	print("Generating Arcade Opponent: Difficulty ", GameManager.ai_difficulty, " -> Enemy Lv.", final_enemy_level)
	if stat_penalty > 0:
		print(">> UNDER-LEVEL PENALTY APPLIED: -", stat_penalty, " HP/SP")
	
# 4. Generate Enemy (MODIFIED FOR BOSSES)
	var enemy: CharacterData
	
	# Check if the CURRENT level has a scheduled boss
	if BOSS_SCHEDULE.has(current_level):
		var boss_path = BOSS_DIR + BOSS_SCHEDULE[current_level]
		var boss_preset = load(boss_path) as PresetCharacter
		
		# Generate the boss exactly as designed in the editor
		enemy = ClassFactory.create_from_preset(boss_preset)
		
		# Bosses scale slightly with difficulty
		if GameManager.ai_difficulty == GameManager.Difficulty.HARD:
			enemy.max_hp += 5
			enemy.max_sp += 1
		elif GameManager.ai_difficulty <= GameManager.Difficulty.EASY:
			enemy.max_hp = max(1, enemy.max_hp - 3)
			
		enemy.reset_stats()
		print(">> BOSS ENCOUNTER LOADED: " + enemy.character_name)
		
	else:
		# Standard Random Enemy
		enemy = ClassFactory.create_random_enemy(final_enemy_level, GameManager.ai_difficulty)
		
		# 5. Apply Stats Penalty (Only for standard enemies)
		if stat_penalty > 0:
			enemy.max_hp = max(1, enemy.max_hp - stat_penalty)
			enemy.max_sp = max(1, enemy.max_sp - stat_penalty)
			enemy.reset_stats()
			enemy.character_name += " (Weakened)"
	
	GameManager.next_match_p2_data = enemy
	
	# 6. Launch
	SceneLoader.change_scene("res://Scenes/VsScreen.tscn")

func handle_win():
	# --- FIX: UNPAUSE THE GAME ---
	# If we don't do this, the scene change might get stuck 
	# or the next scene will start frozen.
	get_tree().paused = false 
	# -----------------------------
	
	print("Victory! Processing Level Up...")
	current_level += 1
	SceneLoader.change_scene("res://Scenes/RewardScreen.tscn")

# Helper to fetch all equipment for the draft
func get_all_equipment() -> Array[EquipmentData]:
	var list: Array[EquipmentData] = []
	var dir = DirAccess.open(EQUIPMENT_DIR)
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres") or file.ends_with(".res"):
				var res = load(EQUIPMENT_DIR + file)
				if res is EquipmentData:
					list.append(res)
			file = dir.get_next()
	return list

func handle_loss():
	is_arcade_mode = false

# --- REWARD POOL LOGIC ---

# 1. Fetch Valid Actions (The "Invisible Tree" Logic)
func get_valid_action_rewards() -> Array[ActionData]:
	var valid_actions: Array[ActionData] = []
	var neighbor_ids = []
	
	# Look at every node we currently own
	for owned_id in player_owned_tree_ids:
		# Check its connections in the static Tree Map
		if ClassFactory.TREE_CONNECTIONS.has(owned_id):
			for neighbor in ClassFactory.TREE_CONNECTIONS[owned_id]:
				# If we don't own it yet, it's a valid reward
				if neighbor not in player_owned_tree_ids and neighbor not in neighbor_ids:
					neighbor_ids.append(neighbor)
	
	# Convert IDs to actual Resources
	for id in neighbor_ids:
		var c_name = ClassFactory.ID_TO_NAME_MAP.get(id)
		if c_name:
			var card = ClassFactory.find_action_resource(c_name)
			if card: valid_actions.append(card)
			
	return valid_actions

# 2. Fetch Stat Upgrades (Generated on the fly)
func get_stat_upgrades() -> Array[Dictionary]:
	return [
		{ "type": "stat", "text": "MAX HEALTH UP", "desc": "Gain +4 Max HP.", "icon": "heart", "func": func(p): p.max_hp += 4; p.current_hp += 4 },
		{ "type": "stat", "text": "STAMINA UP", "desc": "Gain +1 Max SP.", "icon": "stamina", "func": func(p): p.max_sp += 1; p.current_sp += 1 },
		{ "type": "stat", "text": "FULL RESTORE", "desc": "Heal to Full HP.", "icon": "heal", "func": func(p): p.current_hp = p.max_hp }
	]

# 3. Handle Reward Selection
func apply_reward(reward):
	# A. If it's an Action (Resource)
	if reward is ActionData:
		# 1. Unlock in Tree
		var id = ClassFactory.get_id_by_name(reward.display_name)
		if id != 0: player_owned_tree_ids.append(id)
		
		# 2. Add to Deck/Library
		player_run_data.unlocked_actions.append(reward)
		if player_run_data.deck.size() < ClassFactory.HAND_LIMIT:
			player_run_data.deck.append(reward)
		
		# 3. The "Draft Heal" (Action is its own reward + tiny sustain)
		player_run_data.current_hp = min(player_run_data.current_hp + 2, player_run_data.max_hp)
		print("Drafted Action: " + reward.display_name + " (Healed 2 HP)")

	# B. If it's Equipment (Resource)
	elif reward is EquipmentData:
		player_run_data.equipment.append(reward)
		# Recalculate stats immediately to apply bonuses
		ClassFactory._recalculate_stats(player_run_data)
		print("Drafted Item: " + reward.display_name)

	# C. If it's a Stat Upgrade (Dictionary)
	elif reward is Dictionary and reward.has("func"):
		reward["func"].call(player_run_data)
		print("Drafted Upgrade: " + reward.text)

	# Save/Continue
	handle_reward_complete()

# --- NEW: CENTRALIZED RUN START ---
# 1. Standard Start (From Class Selection)
# CHANGED: Accept the Resource (ClassStats) instead of just an int
# Update this function
func start_new_run(source_class: ClassDefinition):
	# 1. Reset Run State
	current_level = 1
	player_owned_tree_ids.clear()
	free_unlocks_remaining = 0
	
	# 2. Create Character Data
	var p_data = CharacterData.new()
	
	# --- FIX START: COPY IDENTITY FROM RESOURCE ---
	p_data.class_type = source_class.class_type # Crucial: Sets the Enum (Heavy/Quick/etc)
	p_data.character_name = source_class.class_named
	p_data.portrait = source_class.portrait
	p_data.passive_desc = source_class.passive_description
	
	# Copy Stats (Optional: if your resource has custom start stats)
	p_data.max_hp = 5
	p_data.current_hp = 5
	p_data.max_sp = 4
	p_data.current_sp = 4
	# --- FIX END ---
	
	#print("Starting Run: " + p_data.display_name + " (" + str(p_data.class_type) + ")")
	
	# 3. LOAD STARTING DECK
	if source_class.starting_deck.size() > 0:
		for card_res in source_class.starting_deck:
			if card_res:
				p_data.unlocked_actions.append(card_res.duplicate())
	else:
		p_data.unlocked_actions.append_array(ClassFactory.get_basic_actions())
	
	# 4. Auto-Unlock Class Starter Node
	_unlock_class_starters(p_data, source_class)
	
	# 5. Fill Initial Hand
	for action in p_data.unlocked_actions:
		if p_data.deck.size() < ClassFactory.HAND_LIMIT:
			p_data.deck.append(action)
	
	# 6. Save & Route
	player_run_data = p_data
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")

# --- HELPER: Unlock the first node so the Draft System has "Neighbors" to find ---
# CHANGED: Added '= null' to make the second argument optional
func _unlock_class_starters(p_data: CharacterData, source_class: ClassDefinition = null):
	var root_id = 0
	
	# Priority 1: Read from the Resource (The new, flexible way)
	if source_class:
		root_id = source_class.skill_tree_root_id
	
	# Priority 2: Fallback to defaults if Resource is missing (Safety net for Presets)
	if root_id == 0:
		match p_data.class_type:
			ClassFactory.ClassType.HEAVY: root_id = 76
			ClassFactory.ClassType.QUICK: root_id = 73
			ClassFactory.ClassType.TECHNICAL:  root_id = 74
			ClassFactory.ClassType.PATIENT: root_id = 75
	
	# --- UNLOCK LOGIC ---
	if root_id != 0:
		if not player_owned_tree_ids.has(root_id):
			player_owned_tree_ids.append(root_id)
		
		var c_name = ClassFactory.ID_TO_NAME_MAP.get(root_id)
		if c_name:
			var card = ClassFactory.find_action_resource(c_name)
			
			# --- FIX: CHECK IF CARD EXISTS BEFORE USING IT ---
			if card:
				# Now it is safe to check for duplicates
				var already_has = false
				for c in p_data.unlocked_actions:
					# Check c is valid too, just to be super safe
					if c and c.display_name == card.display_name: 
						already_has = true
						break
				
				if not already_has:
					p_data.unlocked_actions.append(card)
			else:
				print("ERROR: Could not find Starter Card resource for name: " + str(c_name))

# --- UPDATE: REWARD ROUTING ---
func handle_reward_complete():
	# Loop back to Deck Editor after picking a reward
	print("Reward Claimed. Going to Deck Editor...")
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")
