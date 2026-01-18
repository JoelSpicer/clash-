extends Node

var is_arcade_mode: bool = false
var current_level: int = 1
var player_run_data: CharacterData
var player_owned_tree_ids: Array[int] = [] # Track which nodes we own across fights
var free_unlocks_remaining: int = 0


# OPTION A: STANDARD RUN (Level 1, Drafting)
func start_run(starting_class: CharacterData.ClassType):
	is_arcade_mode = true
	current_level = 1
	
	# 1. Create fresh Level 1 Character
	player_run_data = ClassFactory.create_character(starting_class, "You")
	
	# 2. Initialize Tree (Root Node only)
	_init_tree_root(starting_class)
	
	# 3. Go to Draft Mode
	free_unlocks_remaining = 2
	get_tree().change_scene_to_file("res://Scenes/ActionTree.tscn")

# OPTION B: PRESET RUN (Higher Level, Skip Draft)
func start_run_from_preset(preset: PresetCharacter):
	is_arcade_mode = true
	
	# 1. Load Level from Preset (Default to 1 if missing)
	current_level = max(1, preset.level)
	print("Starting Arcade Run with Preset: " + preset.character_name + " (Lv. " + str(current_level) + ")")
	
	# 2. Create Character Data
	player_run_data = ClassFactory.create_from_preset(preset)
	# Override name to be "You" or keep preset name? Let's keep preset name for flavor.
	
	# 3. Reconstruct Tree Ownership
	# We must tell the system that we "Bought" these skills already
	_init_tree_root(preset.class_type)
	
	for skill_name in preset.extra_skills:
		var id = ClassFactory.get_id_by_name(skill_name)
		if id != 0:
			if id not in player_owned_tree_ids:
				player_owned_tree_ids.append(id)
	
	# 4. Skip Draft, go straight to Fight
	free_unlocks_remaining = 0
	start_next_fight()

# Helper to avoid duplicate code
func _init_tree_root(class_type: CharacterData.ClassType):
	player_owned_tree_ids.clear()
	match class_type:
		CharacterData.ClassType.QUICK: player_owned_tree_ids.append(73)
		CharacterData.ClassType.TECHNICAL: player_owned_tree_ids.append(74)
		CharacterData.ClassType.PATIENT: player_owned_tree_ids.append(75)
		CharacterData.ClassType.HEAVY: player_owned_tree_ids.append(76)

func start_next_fight():
	# 1. Setup Player
	GameManager.next_match_p1_data = player_run_data
	
	# 2. Generate Enemy (Same Level)
	var enemy = ClassFactory.create_random_enemy(current_level, GameManager.ai_difficulty)
	GameManager.next_match_p2_data = enemy
	
	# 3. Launch
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func handle_win():
	current_level += 1
	# Go to Skill Tree to pick reward
	get_tree().change_scene_to_file("res://Scenes/ActionTree.tscn")

func handle_loss():
	is_arcade_mode = false
	# Go to Game Over or Menu
	# (The GameOverScreen already handles this via buttons)
