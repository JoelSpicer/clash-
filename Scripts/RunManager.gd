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
func start_run_from_preset(preset: PresetCharacter):
	is_arcade_mode = true
	current_level = max(1, preset.level)
	print("Starting Arcade Run with Preset: " + preset.character_name + " (Lv. " + str(current_level) + ")")
	
	player_run_data = ClassFactory.create_from_preset(preset)
	
	_init_tree_root(preset.class_type)
	for skill_name in preset.extra_skills:
		var id = ClassFactory.get_id_by_name(skill_name)
		if id != 0 and id not in player_owned_tree_ids:
			player_owned_tree_ids.append(id)
	
	free_unlocks_remaining = 0
	start_next_fight()

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
	SceneLoader.change_scene("res://Scenes/MainScene.tscn")

func handle_win():
	current_level += 1
	free_unlocks_remaining = 1 
	
	var level_beaten = current_level - 1
	
	# 1. Guaranteed Equipment (Every 3rd Win)
	if level_beaten > 0 and level_beaten % 3 == 0:
		print("Milestone Reached! Loading Equipment Draft...")
		SceneLoader.change_scene("res://Scenes/equipmentdraft.tscn")
		
	# 2. Random Event (35% Chance on normal wins)
	elif level_beaten > 0 and randf() < 0.35:
		print("Random Event Triggered!")
		SceneLoader.change_scene("res://Scenes/EventRoom.tscn")
		
	# 3. Standard Action Tree
	else:
		SceneLoader.change_scene("res://Scenes/ActionTree.tscn")

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
