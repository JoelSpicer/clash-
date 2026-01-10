extends Node

var is_arcade_mode: bool = false
var current_level: int = 1
var player_run_data: CharacterData
var player_owned_tree_ids: Array[int] = [] # Track which nodes we own across fights

func start_run(starting_class: CharacterData.ClassType):
	is_arcade_mode = true
	current_level = 1
	
	# 1. Create fresh Level 1 Character
	player_run_data = ClassFactory.create_character(starting_class, "You")
	
	# 2. Initialize Tree State (Starting Node)
	player_owned_tree_ids.clear()
	match starting_class:
		CharacterData.ClassType.QUICK: player_owned_tree_ids.append(73)
		CharacterData.ClassType.TECHNICAL: player_owned_tree_ids.append(74)
		CharacterData.ClassType.PATIENT: player_owned_tree_ids.append(75)
		CharacterData.ClassType.HEAVY: player_owned_tree_ids.append(76)
		
	start_next_fight()

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
