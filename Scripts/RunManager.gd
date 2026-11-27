extends Node

const ResourceCatalogScript = preload("res://Scripts/Resources/ResourceCatalog.gd")
const RunSaveManagerScript = preload("res://Scripts/RunSaveManager.gd")
const MatchTelemetryScript = preload("res://Scripts/Meta/MatchTelemetry.gd")
const AchievementManagerScript = preload("res://Scripts/Meta/AchievementManager.gd")

var is_arcade_mode: bool = false
var current_level: int = 1
var player_run_data: CharacterData = null
var player_owned_tree_ids: Array[int] = []
var active_sponsor: SponsorData = null
var current_rerolls: int = 0

var active_gym_buff: String = ""

var pending_advancement: bool = false
var pending_reward: bool = false
var pending_league_victory: bool = false
var reward_tokens_granted: bool = false

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

# --- CONFIGURATION ---
const LEAGUE_LENGTH: int = 10
const MID_BOSS_INDEX: int = 4
var is_rival_match: bool = false
var is_boss_match: bool = false
var last_league_tokens_awarded: int = 0

# --- GLOBAL META DATA ---
const GLOBAL_SAVE_PATH: String = "user://global_save.tres"
var meta_data: GlobalSaveData
var telemetry: MatchTelemetry = null
var run_stats: Dictionary = {}
var last_match_summary: Dictionary = {}
var last_run_summary: Dictionary = {}
var last_unlocked_achievements: Array[Dictionary] = []
var return_to_carousel_slide: int = -1

var next_fight_statuses: Array[String] = []


func _ready() -> void:
	_init_global_save()
	telemetry = MatchTelemetryScript.new()
	telemetry.bind_signals()


func notify_match_started() -> void:
	last_unlocked_achievements.clear()
	if telemetry != null:
		var local_id: int = 1
		if GameManager.multiplayer.has_multiplayer_peer() and not GameManager.multiplayer.get_peers().is_empty():
			if GameManager.multiplayer.get_unique_id() == GameManager.p2_network_id:
				local_id = 2
		telemetry.reset_match_tracking(local_id)


func check_achievements(custom_fighter_count: int = -1) -> Array[Dictionary]:
	if meta_data == null:
		return []
	var unlocked: Array[Dictionary] = AchievementManagerScript.evaluate(self, meta_data, custom_fighter_count)
	if not unlocked.is_empty():
		last_unlocked_achievements.append_array(unlocked)
	return unlocked


func get_active_title() -> String:
	if meta_data == null:
		return ""
	return meta_data.active_title


func set_active_title(new_title: String) -> void:
	if meta_data == null:
		return
	meta_data.active_title = new_title
	_save_global_data()


#region Run Lifecycle & State Reset

## Clears all transient Circuit run globals so Trials, Tutorials, Quick Match, and PvP never inherit stale state.
func clear_active_run_state() -> void:
	is_arcade_mode = false
	player_run_data = null
	player_owned_tree_ids.clear()
	active_sponsor = null
	current_rerolls = 0
	active_gym_buff = ""
	pending_advancement = false
	pending_reward = false
	pending_league_victory = false
	reward_tokens_granted = false
	is_rival_match = false
	is_boss_match = false
	last_league_tokens_awarded = 0
	next_fight_statuses.clear()
	tournament_map.clear()
	current_map_index = 0
	leagues_completed = 0
	run_stats = MatchTelemetryScript.new_stats_bucket()
	GameManager.rival_intro_override = ""


## Starts a fresh Circuit roguelike run with the chosen class and optional sponsor.
func start_new_run(source_class: ClassDefinition, run_name: String = "New Run", sponsor: SponsorData = null) -> void:
	clear_active_run_state()

	current_run_name = run_name
	is_arcade_mode = true
	current_level = 1
	leagues_completed = 0
	active_sponsor = sponsor

	# Delegate fighter construction to ClassFactory so base_speed & all class passives stay in sync
	var p_data: CharacterData = ClassFactory.create_character(source_class.class_type, run_name, true)
	if p_data == null:
		printerr("RunManager: Failed to create character for class ", source_class.class_type)
		return

	p_data.deck.clear()

	# Note: Combat-only sponsor bonuses (starting_barrier, combo_sp_regen_bonus,
	# starting_sp_bonus, momentum_start_bonus, wall_crush_damage_bonus, etc.) apply in GameManager.
	if active_sponsor != null:
		p_data.max_hp += active_sponsor.bonus_max_hp
		p_data.max_sp += active_sponsor.bonus_max_sp
		current_rerolls = active_sponsor.starting_rerolls

		for eq: EquipmentData in active_sponsor.starting_equipment:
			if eq != null:
				grant_equipment(p_data, eq, false)

	p_data.max_hp = maxi(1, p_data.max_hp)
	p_data.max_sp = maxi(1, p_data.max_sp)
	p_data.current_hp = p_data.max_hp
	p_data.current_sp = p_data.max_sp

	if active_sponsor != null and active_sponsor.starting_cards.size() > 0:
		for c: ActionData in active_sponsor.starting_cards:
			if c != null:
				p_data.unlocked_actions.append(c.duplicate() as ActionData)

	_register_class_tree_root(p_data, source_class)

	for action: ActionData in p_data.unlocked_actions:
		if p_data.deck.size() < ClassFactory.HAND_LIMIT:
			p_data.deck.append(action)

	player_run_data = p_data
	generate_new_league()
	pending_advancement = false
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")


func _register_class_tree_root(p_data: CharacterData, source_class: ClassDefinition = null) -> void:
	var root_id: int = 0
	if source_class != null:
		root_id = source_class.skill_tree_root_id

	if root_id == 0:
		match p_data.class_type:
			CharacterData.ClassType.HEAVY: root_id = 76
			CharacterData.ClassType.QUICK: root_id = 73
			CharacterData.ClassType.TECHNICAL: root_id = 74
			CharacterData.ClassType.PATIENT: root_id = 75

	if root_id != 0 and not player_owned_tree_ids.has(root_id):
		player_owned_tree_ids.append(root_id)


func handle_win() -> void:
	get_tree().paused = false
	AudioManager.reset_audio_state()
	print("Victory! Processing Level Up...")

	current_level += 1
	pending_reward = true
	reward_tokens_granted = false

	save_run()
	SceneLoader.change_scene("res://Scenes/RewardScreen.tscn")


func handle_loss() -> void:
	AudioManager.reset_audio_state()
	var safe_name: String = RunSaveManagerScript.sanitize_save_name(current_run_name) + ".tres"
	delete_save_file(safe_name)
	clear_active_run_state()

#endregion

#region Boss Modifiers, Equipment & Rewards

func get_all_boss_modifiers() -> Array[EquipmentData]:
	var list: Array[EquipmentData] = []
	for res: Resource in ResourceCatalogScript.load_dir(BOSS_MODIFIERS_DIR):
		if res is EquipmentData:
			list.append(res as EquipmentData)
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
	for res: Resource in ResourceCatalogScript.load_dir(EQUIPMENT_DIR):
		if res is EquipmentData:
			list.append(res as EquipmentData)
	return list


func get_unowned_equipment(character: CharacterData) -> Array[EquipmentData]:
	var unowned: Array[EquipmentData] = []
	var owned_names: Array[String] = []
	if character != null:
		for eq: EquipmentData in character.equipment:
			if eq != null:
				owned_names.append(eq.item_name)
	for item: EquipmentData in get_all_equipment():
		if item != null and item.item_name not in owned_names:
			unowned.append(item)
	return unowned


## Equips [param eq] on [param character] and applies its permanent max HP/SP modifiers consistently.
func grant_equipment(character: CharacterData, eq: EquipmentData, adjust_current: bool = true) -> void:
	if character == null or eq == null:
		return
	character.equipment.append(eq)
	character.max_hp = maxi(1, character.max_hp + eq.bonus_max_hp)
	character.max_sp = maxi(1, character.max_sp + eq.bonus_max_sp)
	if adjust_current:
		if eq.bonus_max_hp > 0:
			character.current_hp = mini(character.current_hp + eq.bonus_max_hp, character.max_hp)
		else:
			character.current_hp = mini(character.current_hp, character.max_hp)
		character.current_sp = character.max_sp


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
	if player_run_data == null:
		return

	if reward is ActionData:
		var action: ActionData = reward as ActionData
		var id: int = ClassFactory.get_id_by_name(action.display_name)
		if id != 0 and not player_owned_tree_ids.has(id):
			player_owned_tree_ids.append(id)
		player_run_data.unlocked_actions.append(action)
		if player_run_data.deck.size() < ClassFactory.HAND_LIMIT:
			player_run_data.deck.append(action)
		player_run_data.current_hp = mini(player_run_data.current_hp + 2, player_run_data.max_hp)
		print("Drafted Action: " + action.display_name + " (Healed 2 HP)")

	elif reward is EquipmentData:
		var eq: EquipmentData = reward as EquipmentData
		grant_equipment(player_run_data, eq, true)
		print("Drafted Item: " + eq.item_name)

	elif reward is Dictionary and (reward as Dictionary).has("func"):
		var dict_reward: Dictionary = reward as Dictionary
		(dict_reward["func"] as Callable).call(player_run_data)
		print("Drafted Upgrade: " + str(dict_reward["text"]))

	check_danger_state()
	handle_reward_complete()


func handle_reward_complete() -> void:
	print("Reward Claimed. Going to Deck Editor...")
	pending_reward = false
	reward_tokens_granted = false
	is_boss_match = false
	is_rival_match = false
	pending_advancement = true
	save_run()
	SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")

#endregion

#region Save & Load Delegation (RunSaveManager)

func save_run() -> void:
	RunSaveManagerScript.save_run(self)


func load_run(filename: String) -> void:
	var save_data: RunSaveData = RunSaveManagerScript.load_run_data(filename)
	if save_data == null or save_data.player_data == null:
		printerr("RunManager: Error loading save file: ", filename)
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
	var raw_lv: Variant = save_data.get("pending_league_victory")
	var raw_tok: Variant = save_data.get("reward_tokens_granted")
	pending_advancement = bool(raw_adv) if raw_adv != null else false
	pending_reward = bool(raw_rew) if raw_rew != null else false
	pending_league_victory = bool(raw_lv) if raw_lv != null else (current_map_index >= tournament_map.size() and tournament_map.size() > 0)
	reward_tokens_granted = bool(raw_tok) if raw_tok != null else false

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
	var raw_run_stats: Variant = save_data.get("run_stats")
	if raw_run_stats is Dictionary and not (raw_run_stats as Dictionary).is_empty():
		run_stats = (raw_run_stats as Dictionary).duplicate(true)
	else:
		run_stats = MatchTelemetryScript.new_stats_bucket()

	if pending_league_victory:
		SceneLoader.change_scene("res://Scenes/LeagueVictoryScreen.tscn")
	elif pending_reward:
		SceneLoader.change_scene("res://Scenes/RewardScreen.tscn")
	elif pending_advancement:
		SceneLoader.change_scene("res://Scenes/DeckEditScreen.tscn")
	else:
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")


func get_save_files() -> Array[String]:
	return RunSaveManagerScript.get_save_files()


func peek_save_file(filename: String) -> RunSaveData:
	return RunSaveManagerScript.load_run_data(filename)


func delete_save_file(filename: String) -> void:
	RunSaveManagerScript.delete_save_file(filename)


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
	pending_league_victory = false
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


## Marks the current non-combat node (Event) completed and unlocks the next node immediately before saving,
## preventing save/reload reward farming on Event outcome screens.
func complete_current_node_and_save() -> void:
	if current_map_index < tournament_map.size():
		tournament_map[current_map_index].is_completed = true
	current_map_index += 1
	if current_map_index >= tournament_map.size():
		pending_league_victory = true
	else:
		tournament_map[current_map_index].is_locked = false
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
	pending_league_victory = true
	print("League %d Complete! Entering Victory Lap..." % leagues_completed)

	var base_bonus: int = 5 + ((leagues_completed - 1) * 2)
	var prev_tokens: int = meta_data.circuit_tokens if meta_data else 0
	add_circuit_tokens(base_bonus)
	last_league_tokens_awarded = (meta_data.circuit_tokens - prev_tokens) if meta_data else base_bonus

	# Record career league milestones & evaluate league achievements
	if meta_data != null:
		if meta_data.career_stats.is_empty():
			meta_data.career_stats = MatchTelemetryScript.new_stats_bucket()
		var cs: Dictionary = meta_data.career_stats
		cs["highest_league"] = maxi(int(cs.get("highest_league", 0)), leagues_completed)
		cs["leagues_won"] = int(cs.get("leagues_won", 0)) + 1
		if int(run_stats.get("wall_crushes_suffered", 0)) == 0:
			cs["clean_wall_leagues"] = int(cs.get("clean_wall_leagues", 0)) + 1
		if player_run_data != null:
			var cname: String = ClassFactory.class_enum_to_string(player_run_data.class_type)
			if not (cs.get("league_wins_by_class") is Dictionary):
				cs["league_wins_by_class"] = {}
			var lwc: Dictionary = cs["league_wins_by_class"] as Dictionary
			lwc[cname] = int(lwc.get(cname, 0)) + 1
		_save_global_data()
		last_unlocked_achievements = AchievementManagerScript.evaluate(self, meta_data)

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
	var safe_name: String = RunSaveManagerScript.sanitize_save_name(current_run_name)
	delete_save_file(safe_name + ".tres")
	clear_active_run_state()
	_save_global_data()
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")


func exit_deck_editor() -> void:
	if pending_advancement:
		pending_advancement = false
		advance_map()
	else:
		save_run()
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
	meta_data = RunSaveManagerScript.load_global_save()


func _save_global_data() -> void:
	RunSaveManagerScript.save_global_save(meta_data)


func add_circuit_tokens(amount: int) -> void:
	if meta_data == null:
		_init_global_save()
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
