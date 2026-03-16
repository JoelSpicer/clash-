extends Node

var is_arcade_mode: bool = false
var current_level: int = 1
var player_run_data: CharacterData
var player_owned_tree_ids: Array[int] = [] 
var free_unlocks_remaining: int = 0
var active_sponsor: SponsorData = null
var current_rerolls: int = 0

var active_gym_buff: String = ""

var pending_advancement: bool = false
var pending_reward: bool = false

var current_run_name: String = "Test Run" # <--- NEW
const SAVE_DIR = "user://saves/"

# --- NEW: RUN MODIFIERS ---
var maintain_hp_enabled: bool = false
const EQUIPMENT_DIR = "res://Data/Equipment/"
const BOSS_DIR = "res://Data/Presets/Bosses/"

# --- MAP STATE ---
var tournament_map: Array[MapNodeData] = []
var current_map_index: int = 0
var leagues_completed: int = 0
var current_enemy_data: CharacterData # The enemy we are currently fighting

# --- CONFIGURATION ---
# A standard "Cup" might be 8 steps long
const LEAGUE_LENGTH = 20
var is_rival_match: bool = false

# --- GLOBAL META DATA ---
const GLOBAL_SAVE_PATH = "user://global_save.tres"
var meta_data: GlobalSaveData

const BOSS_SCHEDULE = {
	#5: "juggernaut_boss.tres",
	#10: "grandmaster_boss.tres"
}

# ... (start_run and start_run_from_preset remain exactly the same) ...
var next_fight_statuses: Array[String] = []

# --- ADD THIS RIGHT HERE ---
func _ready():
	_init_global_save()
# -------------------------

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
	# 1. Setup Player Data
	GameManager.next_match_p1_data = player_run_data
	
	# --- NEW: RANDOMIZE ENVIRONMENT ---
	var envs = ["Ring", "Dojo", "Street"]
	var selected_env = envs.pick_random()
	GameManager.apply_environment_rules(selected_env)
	
	# --- NEW: TRIGGER ENVIRONMENT MUSIC ---
	# We call this AFTER we pick the environment so the manager knows which one to play
	if AudioManager.has_method("play_location_music"):
		AudioManager.play_location_music(selected_env)
	else:
		# Fallback if you haven't updated AudioManager yet
		AudioManager.play_music("battle_theme")
	# -----------------------------------
	
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
	get_tree().paused = false 
	AudioManager.reset_audio_state()
	print("Victory! Processing Level Up...")
	
	current_level += 1
	pending_reward = true # <--- Tell the game we are owed a reward!
	
	save_run() # Save progress AFTER setting the flag
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
	AudioManager.reset_audio_state()
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
		{ "type": "stat", "text": "MAX HEALTH UP", "desc": "Gain +2 Max HP.", "icon": "heart", "func": func(p): p.max_hp += 2; p.current_hp += 2 },
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
func start_new_run(source_class: ClassDefinition, run_name: String = "New Run", sponsor: SponsorData = null):
	current_run_name = run_name 
	is_arcade_mode = true 
	
	# 1. Reset Run State
	current_level = 1
	player_owned_tree_ids.clear()
	free_unlocks_remaining = 0
	leagues_completed = 0 
	
	# --- NEW: SET ACTIVE SPONSOR ---
	active_sponsor = sponsor
	
	# 2. Create Character Data
	var p_data = CharacterData.new()
	
	p_data.class_type = source_class.class_type 
	p_data.character_name = run_name
	p_data.portrait = source_class.portrait
	p_data.passive_desc = source_class.passive_description
	
	p_data.can_pay_with_hp = source_class.can_pay_with_hp
	p_data.tiring_drains_hp = source_class.tiring_drains_hp
	p_data.combo_sp_recovery_rate = source_class.combo_sp_recovery_rate
	p_data.has_bide_mechanic = source_class.has_bide_mechanic
	p_data.has_keep_up_toggle = source_class.has_keep_up_toggle
	p_data.has_technique_dropdown = source_class.has_technique_dropdown
	
	# Set Base Stats [cite: 25]
	p_data.max_hp = 5
	p_data.current_hp = 5
	p_data.max_sp = 4
	p_data.current_sp = 4
	
	# --- APPLY SPONSOR MODIFIERS ---
	if active_sponsor != null:
		# Apply Base Stats
		p_data.max_hp += active_sponsor.bonus_max_hp
		p_data.max_sp += active_sponsor.bonus_max_sp
		
		# Apply Missing Stats
		p_data.speed += active_sponsor.bonus_speed
		
		# If combo SP regen is 3, a bonus of 1 makes it 2 (faster regen)
		if p_data.combo_sp_recovery_rate > 0:
			p_data.combo_sp_recovery_rate = max(1, p_data.combo_sp_recovery_rate - active_sponsor.combo_sp_regen_bonus)
		
		# Ensure current HP/SP matches the newly buffed max
		p_data.current_hp = p_data.max_hp
		p_data.current_sp = p_data.max_sp
		
		# Apply Barrier (Temporary HP added ON TOP of max)
		if active_sponsor.starting_barrier > 0:
			p_data.current_hp += active_sponsor.starting_barrier
			
		# Grant Reroll Tokens
		current_rerolls = active_sponsor.starting_rerolls
		
		# Give Starting Equipment
		if active_sponsor.starting_equipment.size() > 0:
			p_data.equipment.append_array(active_sponsor.starting_equipment)

	# 3. LOAD STARTING DECK 
	p_data.unlocked_actions = ClassFactory.get_starting_deck(source_class.class_type)
	
	# --- NEW: ADD SPONSOR CARDS TO DECK ---
	if active_sponsor != null and active_sponsor.starting_cards.size() > 0:
		p_data.unlocked_actions.append_array(active_sponsor.starting_cards)
	
	# 4. Auto-Unlock Class Starter Node
	_unlock_class_starters(p_data, source_class)
	
	# 5. Fill Initial Hand
	for action in p_data.unlocked_actions:
		if p_data.deck.size() < ClassFactory.HAND_LIMIT:
			p_data.deck.append(action)
	
	# 6. Save & Route
	player_run_data = p_data
	
	generate_new_league()
	pending_advancement = false 
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
	print("Reward Claimed. Going to Deck Editor...")
	
	pending_reward = false       # <--- We got our reward
	pending_advancement = true   # <--- Now we need to advance the map
	
	save_run() # Save AFTER the flags are updated!
	
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")

# --- SAVE SYSTEM ---

func save_run():
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
	
	# 1. Create our Save Resource
	var save_data = RunSaveData.new()
	save_data.run_name = current_run_name
	save_data.current_level = current_level
	save_data.current_map_index = current_map_index
	save_data.difficulty = GameManager.ai_difficulty
	save_data.maintain_hp = maintain_hp_enabled
	save_data.pending_advancement = pending_advancement
	save_data.pending_reward = pending_reward
	save_data.tree_ids = player_owned_tree_ids.duplicate()
	save_data.player_data = player_run_data
	
	# We duplicate the array so we aren't saving by reference accidentally
	save_data.map_data = tournament_map.duplicate() 
	save_data.timestamp = Time.get_datetime_string_from_system()
	
	# 2. Save it as a .tres file!
	var safe_name = current_run_name.validate_filename()
	var file_path = SAVE_DIR + safe_name + ".tres"
	
	ResourceSaver.save(save_data, file_path)
	
	_show_save_notification()
	print("Run saved to: " + file_path)

func load_run(filename: String):
	var path = SAVE_DIR + filename
	if not FileAccess.file_exists(path): return

	var save_data = ResourceLoader.load(path) as RunSaveData
	if not save_data:
		print("Error loading save file.")
		return
	
	current_run_name = save_data.run_name
	current_level = save_data.current_level
	current_map_index = save_data.current_map_index
	GameManager.ai_difficulty = save_data.difficulty as GameManager.Difficulty
	maintain_hp_enabled = save_data.maintain_hp
	player_owned_tree_ids.assign(save_data.tree_ids)
	
	player_run_data = save_data.player_data
	player_run_data.character_name = current_run_name
	
	tournament_map.assign(save_data.map_data)
	is_arcade_mode = true
	
	# --- NEW: SAFELY FETCH FLAGS ---
	# We use .get() here so that old save files from before you added 
	# these variables don't crash the game!
	pending_advancement = save_data.get("pending_advancement") if save_data.get("pending_advancement") != null else false
	pending_reward = save_data.get("pending_reward") if save_data.get("pending_reward") != null else false
	# -------------------------------
	
	# --- NEW: SMART ROUTING ---
	if pending_reward:
		# They won the fight but quit before picking loot!
		SceneLoader.change_scene("res://Scenes/RewardScreen.tscn")
	elif pending_advancement:
		# They picked loot, but haven't advanced the map yet!
		SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")
	else:
		# Default fallback: Put them on the map
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")

func get_save_files() -> Array:
	var files = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"): # Changed to .tres
				files.append(file_name)
			file_name = dir.get_next()
	return files

func peek_save_file(filename: String) -> RunSaveData:
	var path = SAVE_DIR + filename
	if not FileAccess.file_exists(path): return null
	return ResourceLoader.load(path) as RunSaveData

func delete_save_file(filename: String):
	var path = SAVE_DIR + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Deleted save: " + filename)
		
func _show_save_notification():
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	
	var panel = PanelContainer.new()
	layer.add_child(panel)
	
	# 1. Anchor to Top-Left
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	# 2. Set Grow Directions (Expand Right and Down from the corner)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	
	# 3. Position offsets (20 pixels from the top and left edges)
	panel.offset_left = 20
	panel.offset_top = 20
	
	# --- CUSTOM THEME OVERRIDE ---
	var custom_style = StyleBoxFlat.new()
	custom_style.bg_color = Color(0, 0, 0, 0.8) 
	custom_style.corner_radius_top_left = 6
	custom_style.corner_radius_top_right = 6
	custom_style.corner_radius_bottom_right = 6
	custom_style.corner_radius_bottom_left = 6
	custom_style.content_margin_left = 15
	custom_style.content_margin_right = 15
	custom_style.content_margin_top = 8
	custom_style.content_margin_bottom = 8
	
	panel.add_theme_stylebox_override("panel", custom_style)
	
	# --- STYLING & TEXT ---
	panel.modulate.a = 0.0
	
	var label = Label.new()
	label.text = " GAME SAVED "
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	
	# --- ANIMATION ---
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)

# Call this whenever Player HP changes (Heal or Damage)
func check_danger_state():
	if not player_run_data: return
	
	var hp_percent = float(player_run_data.current_hp) / float(player_run_data.max_hp)
	
	# If HP is 25% or lower (and alive), trigger danger
	if player_run_data.current_hp > 0 and hp_percent <= 0.25:
		AudioManager.set_danger_mode(true)
	else:
		AudioManager.set_danger_mode(false)

# --- GENERATION LOGIC ---
# --- GENERATION LOGIC ---
# --- GENERATION LOGIC ---
# --- GENERATION LOGIC ---
func generate_new_league():
	tournament_map.clear()
	current_map_index = 0
	
	print("Generating League " + str(leagues_completed + 1) + "...")
	
	var diff_offset = 0
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: diff_offset = -2
		GameManager.Difficulty.EASY:      diff_offset = -1
		GameManager.Difficulty.MEDIUM:    diff_offset = 0
		GameManager.Difficulty.HARD:      diff_offset = 1
		
	var fight_counter = 0 
	
	# --- NEW: PICK A RIVAL AMBUSH NODE ---
	# Pick a random node in the middle of the run (e.g., between node 5 and 15)
	var rival_node_index = -1
	if active_sponsor != null and active_sponsor.rival_character_name != "":
		rival_node_index = randi_range(5, LEAGUE_LENGTH - 4)
		rival_node_index = 0
	# -------------------------------------
	
	for i in range(LEAGUE_LENGTH):
		var node = MapNodeData.new()
		var step_number = i + 1
		var actual_progress_level = current_level + fight_counter 
		var raw_rank = actual_progress_level + diff_offset
		var fight_level = raw_rank if raw_rank > 0 else raw_rank - 1
		
		# 1. CHECK BOSS SCHEDULE
		if BOSS_SCHEDULE.has(actual_progress_level):
			node.type = MapNodeData.Type.BOSS
			node.title = "RIVAL"
			
			var boss_path = BOSS_DIR + BOSS_SCHEDULE[actual_progress_level]
			if ResourceLoader.exists(boss_path):
				var boss_preset = load(boss_path) as PresetCharacter
				node.enemy_data = ClassFactory.create_from_preset(boss_preset)
				node.enemy_data.max_hp = max(1, node.enemy_data.max_hp + diff_offset)
				node.enemy_data.max_sp = max(1, node.enemy_data.max_sp + diff_offset)
				node.enemy_data.reset_stats()
				node.enemy_data.character_name = "RIVAL: " + node.enemy_data.character_name
			else:
				node.enemy_data = ClassFactory.create_random_enemy(fight_level + 2, GameManager.ai_difficulty)
			fight_counter += 1
			
		# 2. LEAGUE FINALS
		elif i == LEAGUE_LENGTH - 1:
			node.type = MapNodeData.Type.BOSS
			node.title = "FINALS"
			node.enemy_data = ClassFactory.create_random_enemy(fight_level + 2, GameManager.ai_difficulty)
			node.enemy_data.character_name = "CHAMPION " + node.enemy_data.character_name
			fight_counter += 1
			
		# --- NEW: 3. RIVAL GRUDGE MATCH INJECTION ---
		elif i == rival_node_index:
			node.type = MapNodeData.Type.BOSS # Treat them as a boss so the node is tinted
			node.title = "HATER"
			# Give them a slight +1 level bump before the massive Sponsor Buffs apply
			#node.enemy_data = ClassFactory.create_random_enemy(fight_level + 1, GameManager.ai_difficulty)
			# Overwrite their name so the Grudge Match logic detects them!
			node.enemy_data.character_name = active_sponsor.rival_character_name
			fight_counter += 1
		# --------------------------------------------
			
		# 4. FIXED REST SPOTS (GYM)
		elif randf() < 0.2 and i > 0:
			node.type = MapNodeData.Type.GYM
			node.title = "Training"
			
		# 5. STANDARD FIGHT
		else:
			node.type = MapNodeData.Type.FIGHT
			node.title = "Round " + str(step_number)
			node.enemy_data = ClassFactory.create_random_enemy(fight_level, GameManager.ai_difficulty)
			fight_counter += 1
			
		node.is_locked = (i != 0)
		tournament_map.append(node)
	
	save_run()

# --- NAVIGATION ---
func advance_map():
	# Mark current node complete
	if current_map_index < tournament_map.size():
		tournament_map[current_map_index].is_completed = true
		
	current_map_index += 1
	
	# Check for League Victory
	if current_map_index >= tournament_map.size():
		handle_league_victory()
	else:
		# Unlock next node
		tournament_map[current_map_index].is_locked = false
		save_run()
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")

func handle_league_victory():
	leagues_completed += 1
	print("League Complete! Starting next tier...")
	# For now, just generate the next one immediately
	# Later, we can add a "Victory Lap" screen
	generate_new_league()
	SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")

# Call this from the Deck Editor "Continue" button
func exit_deck_editor():
	if pending_advancement:
		# Case: We just won a fight and grabbed rewards.
		# Mark previous node complete and unlock the next one.
		pending_advancement = false
		advance_map()
	else:
		# Case: We just started a run, or loaded a save.
		# The map is already ready, just go there.
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")

# Call this from your TournamentMap script when a node is clicked!
# Inside RunManager.gd

# Inside RunManager.gd

func start_map_fight(node_data: MapNodeData):
	# 1. TRACK LOCATION
	current_map_index = RunManager.tournament_map.find(node_data)
	
	# 2. DUPLICATE ENEMY DATA (Critical so buffs don't permanently alter the base resource file)
	var enemy_copy = node_data.enemy_data.duplicate(true)
	is_rival_match = false # Reset the flag for this specific fight
	
	# 3. RIVALRY SYSTEM (Check for Grudge Match)
	if active_sponsor != null and enemy_copy.character_name == active_sponsor.rival_character_name:
		is_rival_match = true
		
		# Apply Grudge Match Buffs
		enemy_copy.max_hp += active_sponsor.rival_boss_hp_buff
		enemy_copy.current_hp = enemy_copy.max_hp
		enemy_copy.max_sp += active_sponsor.rival_boss_sp_buff
		enemy_copy.current_sp = enemy_copy.max_sp
		
		print("!!! GRUDGE MATCH INITIATED against " + enemy_copy.character_name + " !!!")
		
		# Apply the custom intro text if the sponsor has one
		# Pass the custom intro to our new override variable!
		if active_sponsor.rival_custom_intro != "":
			GameManager.rival_intro_override = active_sponsor.rival_custom_intro
	else:
		GameManager.rival_intro_override = ""

	# 4. SETUP PLAYER & ENEMY (CRITICAL! DO NOT REMOVE)
	GameManager.next_match_p1_data = player_run_data
	GameManager.next_match_p2_data = enemy_copy
	
	# 5. RANDOMIZE ENVIRONMENT
	var envs = ["Ring", "Dojo", "Street"]
	var selected_env = envs.pick_random()
	GameManager.apply_environment_rules(selected_env)
	
	# 6. START MUSIC (VS SCREEN MODE)
	if AudioManager.has_method("play_location_music"):
		AudioManager.play_location_music(selected_env)
		
		# Set to Intensity 1 (Calm/Intro) for the VS Screen
		AudioManager.set_music_intensity(0.0, 0.0)

	# 7. LAUNCH VS SCREEN
	SceneLoader.change_scene("res://Scenes/VsScreen.tscn")


# Call this inside RunManager's _ready() function!
func _init_global_save():
	if ResourceLoader.exists(GLOBAL_SAVE_PATH):
		meta_data = load(GLOBAL_SAVE_PATH) as GlobalSaveData
	else:
		meta_data = GlobalSaveData.new()
		_save_global_data()

func _save_global_data():
	ResourceSaver.save(meta_data, GLOBAL_SAVE_PATH)

func add_circuit_tokens(amount: int):
	var final_amount = amount
	
	# Apply Sponsor Multiplier if they have one!
	if active_sponsor != null:
		final_amount = roundi(final_amount * active_sponsor.meta_currency_multiplier)
		
	meta_data.circuit_tokens += final_amount
	print(">>> GAINED %d CIRCUIT TOKENS! (Total Bank: %d) <<<" % [final_amount, meta_data.circuit_tokens])
	
	_save_global_data()
