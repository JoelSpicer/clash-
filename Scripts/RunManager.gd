extends Node

var is_arcade_mode: bool = false
var current_level: int = 1
var player_run_data: CharacterData
var player_owned_tree_ids: Array[int] = [] 
var free_unlocks_remaining: int = 0

# ... (start_run and start_run_from_preset remain exactly the same) ...

# OPTION A: STANDARD RUN (Level 1, Drafting)
func start_run(starting_class: CharacterData.ClassType):
	is_arcade_mode = true
	current_level = 1
	player_run_data = ClassFactory.create_character(starting_class, "You")
	_init_tree_root(starting_class)
	free_unlocks_remaining = 2
	get_tree().change_scene_to_file("res://Scenes/ActionTree.tscn")

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
	
	# 4. Generate Enemy
	var enemy = ClassFactory.create_random_enemy(final_enemy_level, GameManager.ai_difficulty)
	
	# 5. Apply Stats Penalty (if any)
	if stat_penalty > 0:
		# Reduce Max Stats (but clamp to minimum 1 so they don't die instantly)
		enemy.max_hp = max(1, enemy.max_hp - stat_penalty)
		enemy.max_sp = max(1, enemy.max_sp - stat_penalty)
		
		# Reset Current Stats to match new Max
		enemy.reset_stats()
		
		# Flavor: Add a status tag so the player knows why they are weak
		enemy.character_name += " (Weakened)"
	
	GameManager.next_match_p2_data = enemy
	
	# 6. Launch
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func handle_win():
	current_level += 1
	# FIX: Grant 1 Unlock so the ActionTree allows exactly one draft pick
	free_unlocks_remaining = 1 
	get_tree().change_scene_to_file("res://Scenes/ActionTree.tscn")

func handle_loss():
	is_arcade_mode = false
