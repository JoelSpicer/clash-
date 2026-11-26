extends Node

const MAX_TURNS: int = 80
const REPORT_OUTPUT_PATH: String = "res://class_balance_report.json"

const CLASS_DEFS: Array[Dictionary] = [
	{ "name": "Heavy", "type": CharacterData.ClassType.HEAVY, "advertised_speed": 1 },
	{ "name": "Patient", "type": CharacterData.ClassType.PATIENT, "advertised_speed": 2 },
	{ "name": "Quick", "type": CharacterData.ClassType.QUICK, "advertised_speed": 4 },
	{ "name": "Technical", "type": CharacterData.ClassType.TECHNICAL, "advertised_speed": 3 },
]

const ENVIRONMENTS: Array[String] = ["Ring", "Dojo", "Street"]

const EQUIPMENT_DEFS: Array[Dictionary] = [
	{ "name": "WeightedKnuckles", "path": "res://Data/Equipment/WeightedKnuckles.tres" },
	{ "name": "BodyArmour", "path": "res://Data/Equipment/BodyArmour.tres" },
	{ "name": "EnergyDrink", "path": "res://Data/Equipment/EnergyDrink.tres" },
	{ "name": "SpikedJacket", "path": "res://Data/Equipment/SpikedJacket.tres" },
]

const PRESET_DEFS: Array[Dictionary] = [
	{ "name": "Basic_Bob_Heavy", "path": "res://Data/Presets/Basic_Bob_Heavy.tres" },
	{ "name": "Basic_Bob_Patient", "path": "res://Data/Presets/Basic_Bob_Patient.tres" },
	{ "name": "Basic_Bob_Quick", "path": "res://Data/Presets/Basic_Bob_Quick.tres" },
	{ "name": "Basic_Bob_Technical", "path": "res://Data/Presets/Basic_Bob_Technical.tres" },
	{ "name": "Crash_Johnson_Lv6", "path": "res://Data/Presets/Crash_Johnson_Lv6.tres" },
	{ "name": "Kaiji_Akagi_Lv6", "path": "res://Data/Presets/Kaiji_Akagi_Lv6.tres" },
]

var _match_winner: int = 0
var _active_p1: CharacterData
var _active_p2: CharacterData
var _wall_crushes_p1: int = 0
var _wall_crushes_p2: int = 0


func _ready() -> void:
	seed(777888)

	RunManager.is_arcade_mode = false
	RunManager.player_run_data = null
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""

	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)
	if not GameManager.wall_crush_occurred.is_connected(_on_wall_crush):
		GameManager.wall_crush_occurred.connect(_on_wall_crush)

	var t0: int = Time.get_ticks_msec()

	var report: Dictionary = {
		"seed": 777888,
		"godot_version": Engine.get_version_info().string,
		"suites": {}
	}

	# Suite 1: Level Progression (Lv.1, Lv.3, Lv.6, Lv.10 — 8-card culled, Dojo 8-slot)
	GameManager.apply_environment_rules("Dojo")
	var levels_out: Dictionary = {}
	for lvl: int in [1, 3, 6, 10]:
		levels_out["lv_" + str(lvl)] = _run_class_round_robin(10, lvl, false, false)
	report["suites"]["level_progression_culled"] = levels_out

	# Suite 2: Full Unlocked Library Loadouts (bypass_deck_limit = true, Multiplayer/Custom style)
	GameManager.apply_environment_rules("Dojo")
	var full_lib_out: Dictionary = {}
	for lvl: int in [1, 6]:
		full_lib_out["lv_" + str(lvl)] = _run_class_round_robin(10, lvl, true, false)
	report["suites"]["full_library_loadouts"] = full_lib_out

	# Suite 3: Momentum Track Sizes (Ring=6, Dojo=8, Street=10 at Lv.3)
	var env_out: Dictionary = {}
	for env_name: String in ENVIRONMENTS:
		GameManager.apply_environment_rules(env_name)
		env_out[env_name + "_" + str(GameManager.TOTAL_MOMENTUM_SLOTS) + "slots"] = _run_class_round_robin(10, 3, false, false)
	report["suites"]["momentum_tracks_lv3"] = env_out

	# Suite 4: Equipment Loadout Impact (Lv.6 character + 1 item vs unequipped Lv.6 random class)
	GameManager.apply_environment_rules("Dojo")
	report["suites"]["equipment_loadouts_lv6"] = _run_equipment_suite(15, 6)

	# Suite 5: What-If Speed Diagnostic (Lv.1 with advertised Speeds 1/2/3/4 instead of all-1)
	GameManager.apply_environment_rules("Dojo")
	report["suites"]["lv1_with_advertised_speeds"] = _run_class_round_robin(10, 1, false, true)

	# Suite 6: Authored Presets Showdown (full library = true, matching multiplayer)
	GameManager.apply_environment_rules("Dojo")
	report["suites"]["presets_showdown"] = _run_presets_suite(4)

	var elapsed_ms: int = Time.get_ticks_msec() - t0
	report["elapsed_ms"] = elapsed_ms

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("CLASS_BALANCE_DONE elapsed_ms=", elapsed_ms, " path=", REPORT_OUTPUT_PATH)
	else:
		printerr("CLASS_BALANCE_ERROR failed to write report")

	get_tree().quit()


func _on_game_over(winner_id: int) -> void:
	if _match_winner == 0:
		_match_winner = winner_id


func _on_wall_crush(player_id: int, _dmg: int) -> void:
	if player_id == 1:
		_wall_crushes_p1 += 1
	else:
		_wall_crushes_p2 += 1


# ==============================================================================
# CHARACTER FACTORY HELPER FOR SPECIFIC CLASS + LEVEL + LOADOUT MODE
# ==============================================================================

func _build_fighter(ctype: CharacterData.ClassType, level: int, full_library: bool, use_advertised_speed: bool, label: String) -> CharacterData:
	var c: CharacterData = ClassFactory.create_character(ctype, label, full_library)
	c.ai_profile = ClassFactory.pick_random_ai_profile()

	if use_advertised_speed:
		for cdef in CLASS_DEFS:
			if cdef["type"] == ctype:
				c.speed = cdef["advertised_speed"]
				break

	if level > 1:
		# Draft extra cards from the class's real skill tree (identical to ClassFactory.create_random_enemy)
		var cards_to_draft: int = level + 1
		var owned_ids: Array[int] = []
		var unlockable: Array[int] = []
		var root_id: int = 76
		match ctype:
			CharacterData.ClassType.QUICK: root_id = 73
			CharacterData.ClassType.TECHNICAL: root_id = 74
			CharacterData.ClassType.PATIENT: root_id = 75
			CharacterData.ClassType.HEAVY: root_id = 76

		owned_ids.append(root_id)
		if root_id in ClassFactory.TREE_CONNECTIONS:
			for neighbor: int in ClassFactory.TREE_CONNECTIONS[root_id]:
				unlockable.append(neighbor)

		for _i in range(cards_to_draft):
			var eligible_ids: Array[int] = []
			for cand_id: int in unlockable:
				var cand_name: Variant = ClassFactory.ID_TO_NAME_MAP.get(cand_id)
				if cand_name != null:
					var cand_card: ActionData = ClassFactory.find_action_resource(str(cand_name))
					if cand_card and ClassFactory.can_draft_action(cand_card, c.unlocked_actions):
						eligible_ids.append(cand_id)
			if eligible_ids.is_empty():
				break
			var picked_id: int = eligible_ids.pick_random()
			var card_name: Variant = ClassFactory.ID_TO_NAME_MAP.get(picked_id)
			if card_name != null:
				var new_card: ActionData = ClassFactory.find_action_resource(str(card_name))
				if new_card and not ClassFactory._has_card(c.unlocked_actions, new_card):
					c.unlocked_actions.append(new_card)
			owned_ids.append(picked_id)
			unlockable.erase(picked_id)
			if picked_id in ClassFactory.TREE_CONNECTIONS:
				for neighbor: int in ClassFactory.TREE_CONNECTIONS[picked_id]:
					if neighbor not in owned_ids and neighbor not in unlockable:
						unlockable.append(neighbor)

		if full_library:
			c.deck = c.unlocked_actions.duplicate()
		else:
			c.deck = ClassFactory._select_smart_hand(c.unlocked_actions)

		# Apply the same level stat scaling as ClassFactory.create_random_enemy
		var stat_bonus: int = level - 1
		var hp_gain: int = randi_range(0, stat_bonus)
		var sp_gain: int = stat_bonus - hp_gain
		c.max_hp += hp_gain
		c.max_sp += sp_gain
		c.current_hp = c.max_hp
		c.current_sp = c.max_sp

	return c


# ==============================================================================
# SUITES
# ==============================================================================

func _run_class_round_robin(games_per_pair: int, level: int, full_library: bool, use_advertised_speed: bool) -> Dictionary:
	var matrix: Dictionary = {}
	var stats: Dictionary = {}
	var total_matches: int = 0
	var total_turns: int = 0
	var total_stalls: int = 0
	var total_wall_crushes: int = 0
	var total_supers: int = 0

	for cdef in CLASS_DEFS:
		var cname: String = cdef["name"]
		matrix[cname] = {}
		stats[cname] = _new_class_bucket()
		for odef in CLASS_DEFS:
			matrix[cname][odef["name"]] = { "wins": 0, "losses": 0, "stalls": 0 }

	for c1_def in CLASS_DEFS:
		var c1_name: String = c1_def["name"]
		for c2_def in CLASS_DEFS:
			var c2_name: String = c2_def["name"]
			for _g in range(games_per_pair):
				var p1: CharacterData = _build_fighter(c1_def["type"], level, full_library, use_advertised_speed, "P1_" + c1_name)
				var p2: CharacterData = _build_fighter(c2_def["type"], level, full_library, use_advertised_speed, "P2_" + c2_name)

				var res: Dictionary = _simulate_match(p1, p2, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD)
				total_matches += 1
				total_turns += res["turns"]
				total_wall_crushes += res["wc_p1"] + res["wc_p2"]
				total_supers += res["supers_p1"] + res["supers_p2"]

				# Record non-mirror & overall stats
				var is_mirror: bool = (c1_name == c2_name)
				_record_class_bucket(stats[c1_name], res["winner"] == 1, res["stalled"], res["turns"], res["p1_tel"], res["wc_p1"], res["supers_p1"], is_mirror, p1.deck.size())
				_record_class_bucket(stats[c2_name], res["winner"] == 2, res["stalled"], res["turns"], res["p2_tel"], res["wc_p2"], res["supers_p2"], is_mirror, p2.deck.size())

				if res["stalled"]:
					total_stalls += 1
					matrix[c1_name][c2_name]["stalls"] += 1
				elif res["winner"] == 1:
					matrix[c1_name][c2_name]["wins"] += 1
				else:
					matrix[c1_name][c2_name]["losses"] += 1

	return {
		"level": level,
		"full_library": full_library,
		"advertised_speed": use_advertised_speed,
		"total_matches": total_matches,
		"avg_turns": snappedf(float(total_turns) / float(max(1, total_matches)), 0.1),
		"stalls": total_stalls,
		"wall_crushes_per_match": snappedf(float(total_wall_crushes) / float(max(1, total_matches)), 0.02),
		"supers_per_match": snappedf(float(total_supers) / float(max(1, total_matches)), 0.02),
		"classes": _finalize_class_buckets(stats),
		"matrix_p1_vs_p2": matrix,
	}


func _run_equipment_suite(games_per_combo: int, level: int) -> Dictionary:
	var out: Dictionary = {}
	for edef in EQUIPMENT_DEFS:
		var ename: String = edef["name"]
		var eq: EquipmentData = load(edef["path"])
		out[ename] = {}
		for cdef in CLASS_DEFS:
			var cname: String = cdef["name"]
			var wins: int = 0
			var stalls: int = 0
			var turns: int = 0
			for g in range(games_per_combo):
				var opp_def: Dictionary = CLASS_DEFS.pick_random()
				var subject: CharacterData = _build_fighter(cdef["type"], level, false, false, "Sub")
				subject.equipment.append(eq)
				subject.max_hp = max(1, subject.max_hp + eq.bonus_max_hp)
				subject.max_sp = max(1, subject.max_sp + eq.bonus_max_sp)
				subject.current_hp = subject.max_hp
				subject.current_sp = subject.max_sp

				var opp: CharacterData = _build_fighter(opp_def["type"], level, false, false, "Opp")
				var sub_p1: bool = (g % 2 == 0)
				var res: Dictionary = _simulate_match(subject, opp, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD) if sub_p1 else _simulate_match(opp, subject, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD)
				turns += res["turns"]
				if res["stalled"]:
					stalls += 1
				elif (res["winner"] == 1 and sub_p1) or (res["winner"] == 2 and not sub_p1):
					wins += 1
			out[ename][cname] = {
				"games": games_per_combo,
				"wins": wins,
				"win_rate_pct": snappedf(100.0 * float(wins) / float(games_per_combo), 0.1),
				"stalls": stalls,
				"avg_turns": snappedf(float(turns) / float(games_per_combo), 0.1),
			}
	return out


func _run_presets_suite(games_per_pair: int) -> Dictionary:
	var loaded: Array[Dictionary] = []
	for pdef in PRESET_DEFS:
		var res_preset: PresetCharacter = load(pdef["path"]) as PresetCharacter
		if res_preset:
			loaded.append({ "name": pdef["name"], "preset": res_preset })

	var stats: Dictionary = {}
	for entry in loaded:
		var sample: CharacterData = ClassFactory.create_from_preset(entry["preset"], true)
		stats[entry["name"]] = {
			"class": ClassFactory.class_enum_to_string(sample.class_type),
			"hp": sample.max_hp,
			"sp": sample.max_sp,
			"deck_size": sample.deck.size(),
			"games": 0,
			"wins": 0,
			"stalls": 0,
			"turns": 0,
		}

	var total_matches: int = 0
	for e1 in loaded:
		for e2 in loaded:
			if e1["name"] == e2["name"]:
				continue
			for _g in range(games_per_pair):
				var p1: CharacterData = ClassFactory.create_from_preset(e1["preset"], true)
				var p2: CharacterData = ClassFactory.create_from_preset(e2["preset"], true)
				p1.ai_profile = ClassFactory.pick_random_ai_profile()
				p2.ai_profile = ClassFactory.pick_random_ai_profile()

				var res: Dictionary = _simulate_match(p1, p2, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD)
				total_matches += 1
				stats[e1["name"]]["games"] += 1
				stats[e2["name"]]["games"] += 1
				stats[e1["name"]]["turns"] += res["turns"]
				stats[e2["name"]]["turns"] += res["turns"]
				if res["stalled"]:
					stats[e1["name"]]["stalls"] += 1
					stats[e2["name"]]["stalls"] += 1
				elif res["winner"] == 1:
					stats[e1["name"]]["wins"] += 1
				else:
					stats[e2["name"]]["wins"] += 1

	for pname: String in stats:
		var s: Dictionary = stats[pname]
		var g: int = max(1, s["games"])
		s["win_rate_pct"] = snappedf(100.0 * float(s["wins"]) / float(g), 0.1)
		s["avg_turns"] = snappedf(float(s["turns"]) / float(g), 0.1)
		s.erase("turns")

	return { "total_matches": total_matches, "presets": stats }


# ==============================================================================
# CORE MATCH SIMULATION (SYNCHRONOUS AGAINST REAL GameManager)
# ==============================================================================

func _simulate_match(p1: CharacterData, p2: CharacterData, p1_diff: GameManager.Difficulty, p2_diff: GameManager.Difficulty) -> Dictionary:
	_active_p1 = p1
	_active_p2 = p2
	_match_winner = 0
	_wall_crushes_p1 = 0
	_wall_crushes_p2 = 0

	GameManager.start_combat(p1, p2)
	GameManager.current_state = GameManager.State.SELECTION

	var p1_tel: Dictionary = { "turns": 0, "struggles": 0, "offence": 0, "defence": 0, "total_cost": 0, "supers": 0, "tech_uses": 0, "cards": {} }
	var p2_tel: Dictionary = { "turns": 0, "struggles": 0, "offence": 0, "defence": 0, "total_cost": 0, "supers": 0, "tech_uses": 0, "cards": {} }

	var turns: int = 0
	while _match_winner == 0 and turns < MAX_TURNS:
		turns += 1
		var p1_choice: Dictionary = _pick_turn_choice(1, p1_diff)
		var p2_choice: Dictionary = _pick_turn_choice(2, p2_diff)

		var p1_card: ActionData = _apply_extra_data(p1_choice["card"], p1_choice["extra"])
		var p2_card: ActionData = _apply_extra_data(p2_choice["card"], p2_choice["extra"])

		if p1_choice["extra"].get("technique", 0) > 0: p1_tel["tech_uses"] += 1
		if p2_choice["extra"].get("technique", 0) > 0: p2_tel["tech_uses"] += 1

		_track_card(p1_tel, p1_card)
		_track_card(p2_tel, p2_card)

		GameManager.state.p1_action_queue = p1_card
		GameManager.state.p2_action_queue = p2_card
		GameManager.state.p1_rage_active = p1_choice["extra"].get("rage", false)
		GameManager.state.p2_rage_active = p2_choice["extra"].get("rage", false)

		GameManager.state.p1_pending_feint = p1_card.feint
		GameManager.state.p2_pending_feint = p2_card.feint

		if GameManager.state.p1_pending_feint:
			var sec1: ActionData = _pick_feint_card(1, p1_diff)
			GameManager.current_state = GameManager.State.FEINT_CHECK
			_apply_feint_direct(1, sec1)

		if GameManager.state.p2_pending_feint:
			var sec2: ActionData = _pick_feint_card(2, p2_diff)
			GameManager.current_state = GameManager.State.FEINT_CHECK
			_apply_feint_direct(2, sec2)

		GameManager.current_state = GameManager.State.RESOLUTION
		GameManager.resolve_clash()

	return {
		"winner": _match_winner,
		"stalled": _match_winner == 0,
		"turns": turns,
		"wc_p1": _wall_crushes_p1,
		"wc_p2": _wall_crushes_p2,
		"supers_p1": p1_tel["supers"],
		"supers_p2": p2_tel["supers"],
		"p1_tel": p1_tel,
		"p2_tel": p2_tel,
	}


func _apply_extra_data(action: ActionData, extra_data: Dictionary) -> ActionData:
	var tech_idx: int = extra_data.get("technique", 0)
	if action == null or tech_idx <= 0:
		return action
	var final_action: ActionData = action.duplicate()
	final_action.cost += 1
	match tech_idx:
		1:
			if final_action.type == ActionData.Type.OFFENCE:
				final_action.is_opener = true
				final_action.display_name += "+"
		2:
			final_action.tiring += 1
			final_action.display_name += "+"
		3:
			final_action.momentum_gain += 1
			final_action.display_name += "+"
	return final_action


func _apply_feint_direct(player_id: int, secondary: ActionData) -> void:
	if secondary == null:
		GameManager._clear_feint_flag(player_id)
		return
	var base_card: ActionData = GameManager.state.p1_action_queue if player_id == 1 else GameManager.state.p2_action_queue
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var total_cost: int = base_card.cost + secondary.cost
	var opp_val: int = GameManager.state.p1_opportunity_stat if player_id == 1 else GameManager.state.p2_opportunity_stat
	var effective_total: int = max(0, total_cost - opp_val)
	var combined_card: ActionData = GameManager._combine_actions(base_card, secondary)
	var total_required: int = effective_total
	var can_afford: bool = (character.current_sp >= total_required)
	if not can_afford and character.class_type == CharacterData.ClassType.HEAVY and (character.current_sp + character.current_hp) > total_required:
		can_afford = true
	if can_afford:
		if player_id == 1:
			GameManager.state.p1_action_queue = combined_card
		else:
			GameManager.state.p2_action_queue = combined_card
	GameManager._clear_feint_flag(player_id)


func _pick_turn_choice(player_id: int, difficulty: GameManager.Difficulty) -> Dictionary:
	var locked: ActionData = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
	if locked != null:
		return { "card": locked, "extra": {} }
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var c: Dictionary = _get_player_constraints(player_id)
	return _choose_ai_choice(character, player_id, difficulty, c["filter"], c["needs_opener"], c["max_cost"], c["opening_stat"], c["can_use_super"], c["opportunity_stat"])


func _pick_feint_card(player_id: int, difficulty: GameManager.Difficulty) -> ActionData:
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var c: Dictionary = _get_player_constraints(player_id)
	var chosen: Dictionary = _choose_ai_choice(character, player_id, difficulty, c["filter"], c["needs_opener"], c["max_cost"], c["opening_stat"], c["can_use_super"], c["opportunity_stat"])
	if chosen["card"].is_struggle:
		return null
	return chosen["card"]


func _get_player_constraints(player_id: int) -> Dictionary:
	var attacker_id: int = GameManager.get_attacker()
	var is_combo: bool = (GameManager.state.current_combo_attacker != 0)
	var mom: int = GameManager.state.momentum
	var c: Dictionary = {
		"filter": null, "needs_opener": false, "max_cost": 99,
		"opening_stat": 0, "can_use_super": false, "opportunity_stat": 0,
	}
	if player_id == 1:
		c["max_cost"] = GameManager.state.p1_cost_limit
		c["opening_stat"] = GameManager.state.p1_opening_stat
		c["opportunity_stat"] = GameManager.state.p1_opportunity_stat
		if mom == GameManager.get_wall_momentum(1) and not _active_p1.has_used_super and not GameManager.is_super_disabled(1):
			c["can_use_super"] = true
		if GameManager.state.p1_must_opener:
			c["needs_opener"] = true
	else:
		c["max_cost"] = GameManager.state.p2_cost_limit
		c["opening_stat"] = GameManager.state.p2_opening_stat
		c["opportunity_stat"] = GameManager.state.p2_opportunity_stat
		if mom == GameManager.get_wall_momentum(2) and not _active_p2.has_used_super and not GameManager.is_super_disabled(2):
			c["can_use_super"] = true
		if GameManager.state.p2_must_opener:
			c["needs_opener"] = true

	if attacker_id != 0:
		c["filter"] = ActionData.Type.OFFENCE if attacker_id == player_id else ActionData.Type.DEFENCE
	if mom == 0 or (attacker_id == player_id and not is_combo):
		c["needs_opener"] = true
	return c


func _choose_ai_choice(character: CharacterData, my_id: int, difficulty: GameManager.Difficulty, type_filter: Variant, must_be_opener: bool, max_cost: int, my_opening: int, allow_super: bool, my_opportunity: int) -> Dictionary:
	var opponent: CharacterData = _active_p2 if my_id == 1 else _active_p1
	var candidates: Array[Dictionary] = []

	for card: ActionData in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if card.counter_value > 0 and my_opening < card.counter_value: continue
		if card.is_super and not allow_super: continue
		var base_needs_opener_block: bool = (must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener)

		if not base_needs_opener_block and card.cost <= max_cost:
			var can_pay: bool = GameManager.get_effective_repeat_count(character, card, my_opportunity, false, false) > 0
			if can_pay:
				candidates.append({ "card": card, "sim": card, "extra": {} })
				if character.has_technique_dropdown and (card.cost + 1) <= max_cost:
					var tech_first_cost: int = max(0, (card.cost + 1) - my_opportunity)
					if character.current_sp >= tech_first_cost + 1:
						if opponent.current_sp > 0:
							var sim_tire: ActionData = card.duplicate()
							sim_tire.cost += 1
							sim_tire.tiring += 1
							candidates.append({ "card": card, "sim": sim_tire, "extra": { "technique": 2 } })
						if card.type == ActionData.Type.OFFENCE:
							var sim_mom: ActionData = card.duplicate()
							sim_mom.cost += 1
							sim_mom.momentum_gain += 1
							candidates.append({ "card": card, "sim": sim_mom, "extra": { "technique": 3 } })

		if base_needs_opener_block and character.has_technique_dropdown and (card.cost + 1) <= max_cost:
			var opener_first_cost: int = max(0, (card.cost + 1) - my_opportunity)
			if character.current_sp >= opener_first_cost:
				var sim_open: ActionData = card.duplicate()
				sim_open.cost += 1
				sim_open.is_opener = true
				candidates.append({ "card": card, "sim": sim_open, "extra": { "technique": 1 } })

	if candidates.is_empty():
		var required_type: ActionData.Type = type_filter if type_filter != null else ActionData.Type.OFFENCE
		return { "card": GameManager.get_struggle_action(required_type), "extra": {} }
	if candidates.size() == 1:
		return { "card": candidates[0]["card"], "extra": candidates[0]["extra"] }

	GameManager.ai_difficulty = difficulty
	var is_hard: bool = (difficulty == GameManager.Difficulty.HARD)
	var brain: AIBehavior = character.ai_profile
	var attacker_id: int = GameManager.get_attacker()

	var scored: Array[Dictionary] = []
	for cand in candidates:
		var sim_card: ActionData = cand["sim"]
		var score: float = brain.score_action(sim_card, character, opponent, my_id)
		if is_hard:
			if sim_card.type == ActionData.Type.OFFENCE:
				if opponent.current_sp == 0 and sim_card.damage >= 2: score += 20.0
				if sim_card.guard_break and opponent.current_sp <= 1: score += 22.0
				if sim_card.damage == 0 and attacker_id == my_id: score -= 12.0
			else:
				if attacker_id != my_id and attacker_id != 0:
					if sim_card.is_parry and opponent.current_sp >= 1: score += 16.0
					if sim_card.reversal: score += 12.0
					if sim_card.block_value >= 1 and sim_card.cost == 0: score += 10.0
		score += randf_range(-2.0, 2.0)
		scored.append({ "card": cand["card"], "extra": cand["extra"], "score": score })

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	return { "card": scored[0]["card"], "extra": scored[0]["extra"] }


# ==============================================================================
# TELEMETRY HELPERS
# ==============================================================================

func _track_card(tel: Dictionary, card: ActionData) -> void:
	tel["turns"] += 1
	tel["total_cost"] += card.cost
	if card.is_struggle: tel["struggles"] += 1
	if card.is_super: tel["supers"] += 1
	if card.type == ActionData.Type.OFFENCE: tel["offence"] += 1
	else: tel["defence"] += 1
	var cname: String = card.display_name
	tel["cards"][cname] = tel["cards"].get(cname, 0) + 1


func _new_class_bucket() -> Dictionary:
	return {
		"games": 0, "wins": 0, "non_mirror_games": 0, "non_mirror_wins": 0,
		"stalls": 0, "turns": 0, "struggles": 0, "offence": 0, "defence": 0,
		"total_cost": 0, "wall_crushed": 0, "supers": 0, "tech_uses": 0, "deck_size_sum": 0, "cards": {},
	}


func _record_class_bucket(b: Dictionary, won: bool, stalled: bool, match_turns: int, tel: Dictionary, wc: int, supers: int, is_mirror: bool, deck_size: int) -> void:
	b["games"] += 1
	if won: b["wins"] += 1
	if not is_mirror:
		b["non_mirror_games"] += 1
		if won: b["non_mirror_wins"] += 1
	if stalled: b["stalls"] += 1
	b["turns"] += match_turns
	b["struggles"] += tel["struggles"]
	b["offence"] += tel["offence"]
	b["defence"] += tel["defence"]
	b["total_cost"] += tel["total_cost"]
	b["wall_crushed"] += wc
	b["supers"] += supers
	b["tech_uses"] += tel["tech_uses"]
	b["deck_size_sum"] += deck_size
	for cname: String in tel["cards"]:
		b["cards"][cname] = b["cards"].get(cname, 0) + tel["cards"][cname]


func _finalize_class_buckets(stats: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cname: String in stats:
		var b: Dictionary = stats[cname]
		var g: int = max(1, b["games"])
		var nmg: int = max(1, b["non_mirror_games"])
		var actions: int = max(1, b["offence"] + b["defence"])

		var pairs: Array[Dictionary] = []
		for k: String in b["cards"]:
			pairs.append({ "name": k, "count": b["cards"][k] })
		pairs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["count"] > y["count"])
		var top_cards: Array[Dictionary] = []
		for i in range(min(4, pairs.size())):
			top_cards.append({ "name": pairs[i]["name"], "pct": snappedf(100.0 * float(pairs[i]["count"]) / float(actions), 0.1) })

		out[cname] = {
			"overall_wr_pct": snappedf(100.0 * float(b["wins"]) / float(g), 0.1),
			"non_mirror_wr_pct": snappedf(100.0 * float(b["non_mirror_wins"]) / float(nmg), 0.1),
			"stalls": b["stalls"],
			"avg_turns": snappedf(float(b["turns"]) / float(g), 0.1),
			"avg_deck_size": snappedf(float(b["deck_size_sum"]) / float(g), 0.1),
			"struggle_pct": snappedf(100.0 * float(b["struggles"]) / float(actions), 0.1),
			"avg_cost": snappedf(float(b["total_cost"]) / float(actions), 0.01),
			"wall_crushed_per_match": snappedf(float(b["wall_crushed"]) / float(g), 0.02),
			"supers_per_match": snappedf(float(b["supers"]) / float(g), 0.02),
			"tech_uses_per_match": snappedf(float(b["tech_uses"]) / float(g), 0.02),
			"top_cards": top_cards,
		}
	return out
