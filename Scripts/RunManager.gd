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

var current_run_name: String = "Test Run"
const SAVE_DIR: String = "user://saves/"

# --- RUN MODIFIERS ---
var maintain_hp_enabled: bool = true
const EQUIPMENT_DIR: String = "res://Data/Equipment/"
const BOSS_MODIFIERS_DIR: String = "res://Data/BossModifiers/"

# --- MAP STATE ---
var tournament_map: Array[MapNodeData] = []
var current_map_index: int = 0
var leagues_completed: int = 0
var current_enemy_data: CharacterData

# --- CONFIGURATION ---
const LEAGUE_LENGTH: int = 10
const MID_BOSS_INDEX: int = 4
var is_rival_match: bool = false
var is_boss_match: bool = false
var last_league_tokens_awarded: int = 0

# --- GLOBAL META DATA ---
const GLOBAL_SAVE_PATH: String = "user://global_save.tres"
var meta_data: GlobalSaveData

var next_fight_statuses: Array[String] = []


func _ready() -> void:
	_init_global_save()


#region Run Start Paths

# OPTION A: STANDARD RUN (Level 1, Drafting)
func start_run(starting_class: CharacterData.ClassType) -> void:
	is_arcade_mode = true
	current_level = 1
	player_run_data = ClassFactory.create_character(starting_class, "You")
	_init_tree_root(starting_class)
	free_unlocks_remaining = 1
	SceneLoader.change_scene("res://Scenes/ActionTree.tscn")


# OPTION B: PRESET RUN
func start_run_from_preset(preset_data: CharacterData) -> void:
	player_run_data = preset_data.duplicate(true) as CharacterData
	current_level = 1
	player_owned_tree_ids.clear()
	_unlock_class_starters(player_run_data)
	print("Starting Preset Run. Loading Deck Editor...")
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")


# OPTION C: CIRCUIT RUN (Class + Sponsor + Tournament Map)
func start_new_run(source_class: ClassDefinition, run_name: String = "New Run", sponsor: SponsorData = null) -> void:
	current_run_name = run_name
	is_arcade_mode = true

	current_level = 1
	player_owned_tree_ids.clear()
	free_unlocks_remaining = 0
	leagues_completed = 0
	active_sponsor = sponsor

	var p_data: CharacterData = CharacterData.new()
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

	p_data.max_hp = source_class.base_hp
	p_data.max_sp = source_class.base_sp

	# Note: Combat-only sponsor bonuses (bonus_speed, starting_barrier, combo_sp_regen_bonus,
	# starting_sp_bonus, momentum_start_bonus, etc.) are applied dynamically in GameManager.
	if active_sponsor != null:
		p_data.max_hp += active_sponsor.bonus_max_hp
		p_data.max_sp += active_sponsor.bonus_max_sp
		current_rerolls = active_sponsor.starting_rerolls

		for eq: EquipmentData in active_sponsor.starting_equipment:
			if eq == null:
				continue
			p_data.equipment.append(eq)
			p_data.max_hp += eq.bonus_max_hp
			p_data.max_sp += eq.bonus_max_sp

	p_data.max_hp = maxi(1, p_data.max_hp)
	p_data.max_sp = maxi(1, p_data.max_sp)
	p_data.current_hp = p_data.max_hp
	p_data.current_sp = p_data.max_sp

	p_data.unlocked_actions = ClassFactory.get_starting_deck(source_class.class_type)
	if active_sponsor != null and active_sponsor.starting_cards.size() > 0:
		p_data.unlocked_actions.append_array(active_sponsor.starting_cards)

	_unlock_class_starters(p_data, source_class)

	for action: ActionData in p_data.unlocked_actions:
		if p_data.deck.size() < ClassFactory.HAND_LIMIT:
			p_data.deck.append(action)

	player_run_data = p_data
	generate_new_league()
	pending_advancement = false
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")


func _init_tree_root(class_type: CharacterData.ClassType) -> void:
	player_owned_tree_ids.clear()
	if ClassFactory.class_registry.has(class_type):
		var def: ClassDefinition = ClassFactory.class_registry[class_type] as ClassDefinition
		if def and def.skill_tree_root_id != 0:
			player_owned_tree_ids.append(def.skill_tree_root_id)
			return
	player_owned_tree_ids.append(76)


func _unlock_class_starters(p_data: CharacterData, source_class: ClassDefinition = null) -> void:
	var root_id: int = 0
	if source_class:
		root_id = source_class.skill_tree_root_id

	if root_id == 0:
		match p_data.class_type:
			CharacterData.ClassType.HEAVY: root_id = 76
			CharacterData.ClassType.QUICK: root_id = 73
			CharacterData.ClassType.TECHNICAL: root_id = 74
			CharacterData.ClassType.PATIENT: root_id = 75

	if root_id != 0:
		if not player_owned_tree_ids.has(root_id):
			player_owned_tree_ids.append(root_id)

		var c_name: Variant = ClassFactory.ID_TO_NAME_MAP.get(root_id)
		if c_name != null:
			var card: ActionData = ClassFactory.find_action_resource(str(c_name))
			if card != null:
				var already_has: bool = false
				for c: ActionData in p_data.unlocked_actions:
					if c and c.display_name == card.display_name:
						already_has = true
						break
				if not already_has:
					p_data.unlocked_actions.append(card)
			else:
				print("ERROR: Could not find Starter Card resource for name: " + str(c_name))

#endregion

#region Legacy Arcade Fight & Win/Loss Handlers

func start_next_fight() -> void:
	GameManager.next_match_p1_data = player_run_data

	var envs: Array[String] = ["Ring", "Dojo", "Street"]
	var selected_env: String = envs.pick_random()
	GameManager.apply_environment_rules(selected_env)

	if AudioManager.has_method("play_location_music"):
		AudioManager.play_location_music(selected_env)
	else:
		AudioManager.play_music("battle_theme")

	var raw_level: int = current_level
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: raw_level -= 2
		GameManager.Difficulty.EASY: raw_level -= 1
		GameManager.Difficulty.MEDIUM: pass
		GameManager.Difficulty.HARD: raw_level += 1

	var final_enemy_level: int = raw_level
	var stat_penalty: int = 0
	if raw_level < 1:
		stat_penalty = 1 - raw_level
		final_enemy_level = 1

	print("Generating Arcade Opponent: Difficulty ", GameManager.ai_difficulty, " -> Enemy Lv.", final_enemy_level)
	if stat_penalty > 0:
		print(">> UNDER-LEVEL PENALTY APPLIED: -", stat_penalty, " HP/SP")

	var enemy: CharacterData
	is_boss_match = false
	GameManager.rival_intro_override = ""

	if current_level > 0 and (current_level % 10 == 0 or current_level % 5 == 0):
		is_boss_match = true
		var is_finals: bool = (current_level % 10 == 0)
		var level_bump: int = 2 if is_finals else 1
		var mod_count: int = 2 if (is_finals and current_level >= 20) else 1
		var boss_mods: Array[EquipmentData] = pick_boss_modifiers(mod_count)
		enemy = ClassFactory.create_boss_enemy(final_enemy_level + level_bump, GameManager.ai_difficulty, boss_mods)
		if is_finals:
			enemy.character_name = "CHAMPION " + enemy.character_name
		if not boss_mods.is_empty():
			var intro_line: Variant = boss_mods[0].get("boss_intro_line")
			if intro_line != null and str(intro_line) != "":
				GameManager.rival_intro_override = str(intro_line)
		print(">> PROCEDURAL BOSS GENERATED: " + enemy.character_name)
	else:
		enemy = ClassFactory.create_random_enemy(final_enemy_level, GameManager.ai_difficulty)
		if stat_penalty > 0:
			enemy.max_hp = maxi(1, enemy.max_hp - stat_penalty)
			enemy.max_sp = maxi(1, enemy.max_sp - stat_penalty)
			enemy.reset_stats()
			enemy.character_name += " (Weakened)"

	GameManager.next_match_p2_data = enemy
	SceneLoader.change_scene("res://Scenes/VsScreen.tscn")


func handle_win() -> void:
	get_tree().paused = false
	AudioManager.reset_audio_state()
	print("Victory! Processing Level Up...")

	current_level += 1
	pending_reward = true

	save_run()
	SceneLoader.change_scene("res://Scenes/RewardScreen.tscn")


func handle_loss() -> void:
	AudioManager.reset_audio_state()
	is_arcade_mode = false

	var safe_name: String = current_run_name.validate_filename() + ".tres"
	delete_save_file(safe_name)
	player_run_data = null

#endregion

#region Boss Modifiers, Equipment & Rewards

## Loads all BossModifierData resources from BOSS_MODIFIERS_DIR.
func get_all_boss_modifiers() -> Array[EquipmentData]:
	var list: Array[EquipmentData] = []
	var dir: DirAccess = DirAccess.open(BOSS_MODIFIERS_DIR)
	if dir:
		dir.list_dir_begin()
		var file: String = dir.get_next()
		while file != "":
			if not dir.current_is_dir() and file.ends_with(".tres"):
				var res: Resource = load(BOSS_MODIFIERS_DIR + file)
				if res is EquipmentData:
					list.append(res as EquipmentData)
			file = dir.get_next()
		dir.list_dir_end()
	return list


## Picks [param count] distinct boss modifiers, excluding any names already in [param exclude].
func pick_boss_modifiers(count: int, exclude: Array[EquipmentData] = []) -> Array[EquipmentData]:
	var all_mods: Array[EquipmentData] = get_all_boss_modifiers()
	var pool: Array[EquipmentData] = []
	var excluded_names: Array[String] = []
	for ex: EquipmentData in exclude:
		if ex:
			excluded_names.append(ex.item_name)
	for mod: EquipmentData in all_mods:
		if mod.item_name not in excluded_names:
			pool.append(mod)
	if pool.size() < count:
		pool = all_mods.duplicate()
	pool.shuffle()
	var picked: Array[EquipmentData] = []
	for i: int in range(mini(count, pool.size())):
		picked.append(pool[i])
	return picked


func get_all_equipment() -> Array[EquipmentData]:
	var list: Array[EquipmentData] = []
	var dir: DirAccess = DirAccess.open(EQUIPMENT_DIR)
	if dir:
		dir.list_dir_begin()
		var file: String = dir.get_next()
		while file != "":
			if file.ends_with(".tres") or file.ends_with(".res"):
				var res: Resource = load(EQUIPMENT_DIR + file)
				if res is EquipmentData:
					list.append(res as EquipmentData)
			file = dir.get_next()
		dir.list_dir_end()
	return list


func get_valid_action_rewards() -> Array[ActionData]:
	var valid_actions: Array[ActionData] = []
	var neighbor_ids: Array[int] = []

	for owned_id: int in player_owned_tree_ids:
		if ClassFactory.TREE_CONNECTIONS.has(owned_id):
			for neighbor: int in ClassFactory.TREE_CONNECTIONS[owned_id]:
				if neighbor not in player_owned_tree_ids and neighbor not in neighbor_ids:
					neighbor_ids.append(neighbor)

	var owned_pool: Array[ActionData] = player_run_data.unlocked_actions if player_run_data != null else []
	for id: int in neighbor_ids:
		var c_name: Variant = ClassFactory.ID_TO_NAME_MAP.get(id)
		if c_name != null:
			var card: ActionData = ClassFactory.find_action_resource(str(c_name))
			if card and ClassFactory.can_draft_action(card, owned_pool):
				valid_actions.append(card)

	return valid_actions


func get_stat_upgrades() -> Array[Dictionary]:
	return [
		{ "type": "stat", "text": "MAX HEALTH UP", "desc": "Gain +2 Max HP.", "icon": "heart", "func": func(p: CharacterData) -> void: p.max_hp += 2; p.current_hp += 2 },
		{ "type": "stat", "text": "STAMINA UP", "desc": "Gain +1 Max SP.", "icon": "stamina", "func": func(p: CharacterData) -> void: p.max_sp += 1; p.current_sp += 1 },
		{ "type": "stat", "text": "FULL RESTORE", "desc": "Heal to Full HP.", "icon": "heal", "func": func(p: CharacterData) -> void: p.current_hp = p.max_hp }
	]


func apply_reward(reward: Variant) -> void:
	if reward is ActionData:
		var action: ActionData = reward as ActionData
		var id: int = ClassFactory.get_id_by_name(action.display_name)
		if id != 0:
			player_owned_tree_ids.append(id)
		player_run_data.unlocked_actions.append(action)
		if player_run_data.deck.size() < ClassFactory.HAND_LIMIT:
			player_run_data.deck.append(action)
		player_run_data.current_hp = mini(player_run_data.current_hp + 2, player_run_data.max_hp)
		print("Drafted Action: " + action.display_name + " (Healed 2 HP)")

	elif reward is EquipmentData:
		var eq: EquipmentData = reward as EquipmentData
		player_run_data.equipment.append(eq)
		player_run_data.max_hp = maxi(1, player_run_data.max_hp + eq.bonus_max_hp)
		player_run_data.max_sp = maxi(1, player_run_data.max_sp + eq.bonus_max_sp)
		if eq.bonus_max_hp > 0:
			player_run_data.current_hp = mini(player_run_data.current_hp + eq.bonus_max_hp, player_run_data.max_hp)
		else:
			player_run_data.current_hp = mini(player_run_data.current_hp, player_run_data.max_hp)
		player_run_data.current_sp = player_run_data.max_sp
		print("Drafted Item: " + eq.item_name)

	elif reward is Dictionary and (reward as Dictionary).has("func"):
		var dict_reward: Dictionary = reward as Dictionary
		(dict_reward["func"] as Callable).call(player_run_data)
		print("Drafted Upgrade: " + str(dict_reward["text"]))

	handle_reward_complete()


func handle_reward_complete() -> void:
	print("Reward Claimed. Going to Deck Editor...")
	pending_reward = false
	pending_advancement = true
	save_run()
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")

#endregion

#region Save & Load System

func save_run() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

	var save_data: RunSaveData = RunSaveData.new()
	save_data.run_name = current_run_name
	save_data.current_level = current_level
	save_data.current_map_index = current_map_index
	save_data.difficulty = GameManager.ai_difficulty
	save_data.maintain_hp = maintain_hp_enabled
	save_data.pending_advancement = pending_advancement
	save_data.pending_reward = pending_reward
	save_data.tree_ids = player_owned_tree_ids.duplicate()
	save_data.player_data = player_run_data
	save_data.map_data = tournament_map.duplicate()
	save_data.timestamp = Time.get_datetime_string_from_system()
	save_data.active_sponsor = active_sponsor
	save_data.leagues_completed = leagues_completed
	save_data.current_rerolls = current_rerolls
	save_data.active_gym_buff = active_gym_buff
	save_data.next_fight_statuses = next_fight_statuses.duplicate()
	save_data.is_boss_match = is_boss_match
	save_data.is_rival_match = is_rival_match

	var safe_name: String = current_run_name.validate_filename()
	var file_path: String = SAVE_DIR + safe_name + ".tres"
	ResourceSaver.save(save_data, file_path)

	_show_save_notification()
	print("Run saved to: " + file_path)


func load_run(filename: String) -> void:
	var path: String = SAVE_DIR + filename
	if not FileAccess.file_exists(path):
		return

	var save_data: RunSaveData = ResourceLoader.load(path) as RunSaveData
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

	var raw_adv: Variant = save_data.get("pending_advancement")
	var raw_rew: Variant = save_data.get("pending_reward")
	pending_advancement = bool(raw_adv) if raw_adv != null else false
	pending_reward = bool(raw_rew) if raw_rew != null else false

	var raw_sponsor: Variant = save_data.get("active_sponsor")
	active_sponsor = raw_sponsor as SponsorData if raw_sponsor is SponsorData else null
	var raw_leagues: Variant = save_data.get("leagues_completed")
	leagues_completed = int(raw_leagues) if raw_leagues != null else 0
	var raw_rerolls: Variant = save_data.get("current_rerolls")
	current_rerolls = int(raw_rerolls) if raw_rerolls != null else 0
	var raw_gym: Variant = save_data.get("active_gym_buff")
	active_gym_buff = str(raw_gym) if raw_gym != null else ""
	var raw_statuses: Variant = save_data.get("next_fight_statuses")
	next_fight_statuses.clear()
	if raw_statuses is Array:
		for s: Variant in raw_statuses:
			next_fight_statuses.append(str(s))
	var raw_boss: Variant = save_data.get("is_boss_match")
	is_boss_match = bool(raw_boss) if raw_boss != null else false
	var raw_rival: Variant = save_data.get("is_rival_match")
	is_rival_match = bool(raw_rival) if raw_rival != null else false

	if pending_reward:
		SceneLoader.change_scene("res://Scenes/RewardScreen.tscn")
	elif pending_advancement:
		SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")
	else:
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")


func get_save_files() -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files


func peek_save_file(filename: String) -> RunSaveData:
	var path: String = SAVE_DIR + filename
	if not FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path) as RunSaveData


func delete_save_file(filename: String) -> void:
	var path: String = SAVE_DIR + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Deleted save: " + filename)


func _show_save_notification() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var panel: PanelContainer = PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_left = 20.0
	panel.offset_top = 20.0

	var custom_style: StyleBoxFlat = StyleBoxFlat.new()
	custom_style.bg_color = Color(0, 0, 0, 0.8)
	custom_style.set_corner_radius_all(6)
	custom_style.content_margin_left = 15.0
	custom_style.content_margin_right = 15.0
	custom_style.content_margin_top = 8.0
	custom_style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", custom_style)

	panel.modulate.a = 0.0
	var label: Label = Label.new()
	label.text = " GAME SAVED "
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)


func check_danger_state() -> void:
	if not player_run_data:
		return
	var hp_percent: float = float(player_run_data.current_hp) / float(maxi(1, player_run_data.max_hp))
	AudioManager.set_danger_mode(player_run_data.current_hp > 0 and hp_percent <= 0.25)

#endregion

#region Tournament Map Generation & Navigation

func generate_new_league() -> void:
	tournament_map.clear()
	current_map_index = 0
	print("Generating League " + str(leagues_completed + 1) + "...")

	var diff_offset: int = 0
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: diff_offset = -2
		GameManager.Difficulty.EASY: diff_offset = -1
		GameManager.Difficulty.MEDIUM: diff_offset = 0
		GameManager.Difficulty.HARD: diff_offset = 1

	var fight_counter: int = 0
	var used_league_boss_mods: Array[EquipmentData] = []

	var rival_node_index: int = -1
	if active_sponsor != null and active_sponsor.rival_character_name != "":
		rival_node_index = randi_range(MID_BOSS_INDEX + 1, LEAGUE_LENGTH - 4)

	for i: int in range(LEAGUE_LENGTH):
		var node: MapNodeData = MapNodeData.new()
		var step_number: int = i + 1
		var actual_progress_level: int = current_level + fight_counter
		var raw_rank: int = actual_progress_level + diff_offset
		var fight_level: int = raw_rank if raw_rank > 0 else raw_rank - 1

		# 1. Mid-League Mini-Boss (+1 Level + 1 Boss Modifier)
		if i == MID_BOSS_INDEX:
			node.type = MapNodeData.Type.BOSS
			node.title = "MINI-BOSS"
			var mid_mods: Array[EquipmentData] = pick_boss_modifiers(1, used_league_boss_mods)
			used_league_boss_mods.append_array(mid_mods)
			node.enemy_data = ClassFactory.create_boss_enemy(fight_level + 1, GameManager.ai_difficulty, mid_mods)
			fight_counter += 1

		# 2. League Finals (+2 Levels + 1 Boss Modifier, or 2 in League 2+)
		elif i == LEAGUE_LENGTH - 1:
			node.type = MapNodeData.Type.BOSS
			node.title = "FINALS"
			var finals_mod_count: int = 2 if leagues_completed >= 1 else 1
			var finals_mods: Array[EquipmentData] = pick_boss_modifiers(finals_mod_count, used_league_boss_mods)
			used_league_boss_mods.append_array(finals_mods)
			node.enemy_data = ClassFactory.create_boss_enemy(fight_level + 2, GameManager.ai_difficulty, finals_mods)
			node.enemy_data.character_name = "CHAMPION " + node.enemy_data.character_name
			fight_counter += 1

		# 3. Rival Grudge Match
		elif i == rival_node_index:
			node.type = MapNodeData.Type.BOSS
			node.title = "HATER"
			node.enemy_data = ClassFactory.create_random_enemy(fight_level + 1, GameManager.ai_difficulty)
			node.enemy_data.character_name = active_sponsor.rival_character_name
			fight_counter += 1

		# 4. Rest Spots (Gym) & Random Events
		elif i > 0 and randf() < 0.35:
			if randf() < 0.57:
				node.type = MapNodeData.Type.GYM
				node.title = "Training"
			else:
				node.type = MapNodeData.Type.EVENT
				node.title = "Event"

		# 5. Standard Fight
		else:
			node.type = MapNodeData.Type.FIGHT
			node.title = "Round " + str(step_number)
			node.enemy_data = ClassFactory.create_random_enemy(fight_level, GameManager.ai_difficulty)
			fight_counter += 1

		node.is_locked = (i != 0)
		tournament_map.append(node)

	save_run()


func advance_map() -> void:
	if current_map_index < tournament_map.size():
		tournament_map[current_map_index].is_completed = true

	current_map_index += 1

	if current_map_index >= tournament_map.size():
		handle_league_victory()
	else:
		tournament_map[current_map_index].is_locked = false
		save_run()
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")


func handle_league_victory() -> void:
	leagues_completed += 1
	print("League %d Complete! Entering Victory Lap..." % leagues_completed)

	var base_bonus: int = 5 + ((leagues_completed - 1) * 2)
	var prev_tokens: int = meta_data.circuit_tokens if meta_data else 0
	add_circuit_tokens(base_bonus)
	last_league_tokens_awarded = (meta_data.circuit_tokens - prev_tokens) if meta_data else base_bonus

	if player_run_data != null:
		player_run_data.current_hp = player_run_data.max_hp
		player_run_data.current_sp = player_run_data.max_sp
		check_danger_state()

	save_run()
	SceneLoader.change_scene("res://Scenes/LeagueVictoryScreen.tscn")


func continue_to_next_league() -> void:
	generate_new_league()
	SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")


func retire_champion() -> void:
	var safe_name: String = current_run_name.validate_filename()
	delete_save_file(safe_name + ".tres")
	is_arcade_mode = false
	is_boss_match = false
	is_rival_match = false
	pending_advancement = false
	pending_reward = false
	_save_global_data()
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")


func exit_deck_editor() -> void:
	if pending_advancement:
		pending_advancement = false
		advance_map()
	else:
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")


func start_map_fight(node_data: MapNodeData) -> void:
	current_map_index = tournament_map.find(node_data)

	var enemy_copy: CharacterData = node_data.enemy_data.duplicate(true) as CharacterData
	if enemy_copy.ai_profile == null:
		enemy_copy.ai_profile = ClassFactory.pick_random_ai_profile()
	is_rival_match = false
	is_boss_match = false

	if active_sponsor != null and enemy_copy.character_name == active_sponsor.rival_character_name:
		is_rival_match = true
		enemy_copy.max_hp += active_sponsor.rival_boss_hp_buff
		enemy_copy.current_hp = enemy_copy.max_hp
		enemy_copy.max_sp += active_sponsor.rival_boss_sp_buff
		enemy_copy.current_sp = enemy_copy.max_sp
		print("!!! GRUDGE MATCH INITIATED against " + enemy_copy.character_name + " !!!")
		if active_sponsor.rival_custom_intro != "":
			GameManager.rival_intro_override = active_sponsor.rival_custom_intro
	else:
		GameManager.rival_intro_override = ""
		if node_data.type == MapNodeData.Type.BOSS:
			is_boss_match = true
			for eq: EquipmentData in enemy_copy.equipment:
				if eq == null:
					continue
				var intro_line: Variant = eq.get("boss_intro_line")
				if intro_line != null and str(intro_line) != "":
					GameManager.rival_intro_override = str(intro_line)
					break

	GameManager.next_match_p1_data = player_run_data
	GameManager.next_match_p2_data = enemy_copy

	var envs: Array[String] = ["Ring", "Dojo", "Street"]
	var selected_env: String = envs.pick_random()
	GameManager.apply_environment_rules(selected_env)

	if AudioManager.has_method("play_location_music"):
		AudioManager.play_location_music(selected_env)
		AudioManager.set_music_intensity(0.0, 0.0)

	SceneLoader.change_scene("res://Scenes/VsScreen.tscn")

#endregion

#region Global Meta Save & Synergies

func _init_global_save() -> void:
	if ResourceLoader.exists(GLOBAL_SAVE_PATH):
		meta_data = load(GLOBAL_SAVE_PATH) as GlobalSaveData
	else:
		meta_data = GlobalSaveData.new()
		_save_global_data()


func _save_global_data() -> void:
	ResourceSaver.save(meta_data, GLOBAL_SAVE_PATH)


func add_circuit_tokens(amount: int) -> void:
	var final_amount: int = amount
	if active_sponsor != null:
		final_amount = roundi(final_amount * active_sponsor.meta_currency_multiplier)
	meta_data.circuit_tokens += final_amount
	print(">>> GAINED %d CIRCUIT TOKENS! (Total Bank: %d) <<<" % [final_amount, meta_data.circuit_tokens])
	_save_global_data()


func wipe_global_save() -> void:
	meta_data = GlobalSaveData.new()
	_save_global_data()
	print(">>> GLOBAL SAVE COMPLETELY WIPED <<<")


func get_active_synergies() -> Array[String]:
	var active_keywords: Array[String] = []
	if active_sponsor:
		active_keywords.append_array(active_sponsor.synergy_keywords)
	if player_run_data:
		for equip: EquipmentData in player_run_data.equipment:
			if equip:
				active_keywords.append_array(equip.synergy_keywords)
	return active_keywords

#endregion
