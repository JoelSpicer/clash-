extends Node

const REPORT_OUTPUT_PATH: String = "res://ai_balance_report.json"
const CombatSimulatorScript = preload("res://Scripts/Balance/CombatSimulator.gd")

const PROFILE_DEFS: Array[Dictionary] = [
	{ "name": "Aggressive", "path": "res://Data/AI/AIAggressive.tres" },
	{ "name": "Balanced", "path": "res://Data/AI/AIBalanced.tres" },
	{ "name": "Defensive", "path": "res://Data/AI/AIDefensive.tres" },
	{ "name": "Trickster", "path": "res://Data/AI/AITrickster.tres" },
]

const CLASS_DEFS: Array[Dictionary] = [
	{ "name": "Heavy", "type": CharacterData.ClassType.HEAVY },
	{ "name": "Patient", "type": CharacterData.ClassType.PATIENT },
	{ "name": "Quick", "type": CharacterData.ClassType.QUICK },
	{ "name": "Technical", "type": CharacterData.ClassType.TECHNICAL },
]

var _profiles: Dictionary = {}
var _sim: CombatSimulator = null


func _ready() -> void:
	seed(424242)
	RunManager.clear_active_run_state()
	GameManager.apply_environment_rules("Dojo")

	for pdef: Dictionary in PROFILE_DEFS:
		_profiles[str(pdef["name"])] = load(str(pdef["path"]))

	_sim = CombatSimulatorScript.new()
	_sim.connect_signals()

	var t0: int = Time.get_ticks_msec()

	var report: Dictionary = {
		"seed": 424242,
		"godot_version": Engine.get_version_info().string,
		"suites": {}
	}

	report["suites"]["mirrored_base_hard"] = _run_mirrored_suite(10, GameManager.Difficulty.HARD)
	report["suites"]["leveled_draft_hard"] = _run_leveled_suite(10, 5, GameManager.Difficulty.HARD)
	report["suites"]["class_x_ai_medium"] = _run_class_synergy_suite(20, GameManager.Difficulty.MEDIUM)
	report["suites"]["difficulty_ladder"] = _run_difficulty_ladder_suite(40)

	var elapsed_ms: int = Time.get_ticks_msec() - t0
	report["elapsed_ms"] = elapsed_ms
	_sim.dispose()

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("AI_BALANCE_DONE elapsed_ms=", elapsed_ms, " path=", REPORT_OUTPUT_PATH)
	else:
		printerr("AI_BALANCE_ERROR failed to write report to ", REPORT_OUTPUT_PATH)

	get_tree().quit()


func _run_mirrored_suite(games_per_pair_per_class: int, difficulty: GameManager.Difficulty) -> Dictionary:
	var matrix: Dictionary = {}
	var profile_stats: Dictionary = {}
	var class_stats: Dictionary = {}
	var p1_wins_total: int = 0
	var p2_wins_total: int = 0
	var stalls_total: int = 0
	var total_matches: int = 0
	var total_turns: int = 0

	for pdef: Dictionary in PROFILE_DEFS:
		var pname: String = str(pdef["name"])
		matrix[pname] = {}
		profile_stats[pname] = _new_bucket()
		for odef: Dictionary in PROFILE_DEFS:
			matrix[pname][str(odef["name"])] = { "wins": 0, "losses": 0, "stalls": 0 }

	for cdef: Dictionary in CLASS_DEFS:
		class_stats[str(cdef["name"])] = { "matches": 0, "turns": 0, "stalls": 0 }

	for p1_def: Dictionary in PROFILE_DEFS:
		var p1_name: String = str(p1_def["name"])
		for p2_def: Dictionary in PROFILE_DEFS:
			var p2_name: String = str(p2_def["name"])
			for cdef: Dictionary in CLASS_DEFS:
				var cname: String = str(cdef["name"])
				var ctype: CharacterData.ClassType = cdef["type"] as CharacterData.ClassType
				for _g: int in range(games_per_pair_per_class):
					var p1: CharacterData = ClassFactory.create_character(ctype, "P1")
					var p2: CharacterData = ClassFactory.create_character(ctype, "P2")
					p1.ai_profile = _profiles[p1_name]
					p2.ai_profile = _profiles[p2_name]

					var res: Dictionary = _sim.simulate_match(p1, p2, difficulty, difficulty)
					total_matches += 1
					total_turns += int(res["turns"])
					class_stats[cname]["matches"] += 1
					class_stats[cname]["turns"] += int(res["turns"])

					_record_telemetry(profile_stats[p1_name], res["p1_tel"] as Dictionary, int(res["winner"]) == 1, bool(res["stalled"]), int(res["turns"]))
					_record_telemetry(profile_stats[p2_name], res["p2_tel"] as Dictionary, int(res["winner"]) == 2, bool(res["stalled"]), int(res["turns"]))

					if bool(res["stalled"]):
						stalls_total += 1
						class_stats[cname]["stalls"] += 1
						matrix[p1_name][p2_name]["stalls"] += 1
					elif int(res["winner"]) == 1:
						p1_wins_total += 1
						matrix[p1_name][p2_name]["wins"] += 1
					else:
						p2_wins_total += 1
						matrix[p1_name][p2_name]["losses"] += 1

	return {
		"total_matches": total_matches,
		"avg_turns": float(total_turns) / float(maxi(1, total_matches)),
		"p1_wins": p1_wins_total,
		"p2_wins": p2_wins_total,
		"stalls": stalls_total,
		"matrix_p1_vs_p2": matrix,
		"profiles": _finalize_buckets(profile_stats),
		"classes": class_stats,
	}


func _run_leveled_suite(games_per_pair: int, level: int, difficulty: GameManager.Difficulty) -> Dictionary:
	var matrix: Dictionary = {}
	var profile_stats: Dictionary = {}
	var total_matches: int = 0
	var total_turns: int = 0
	var stalls_total: int = 0

	for pdef: Dictionary in PROFILE_DEFS:
		var pname: String = str(pdef["name"])
		matrix[pname] = {}
		profile_stats[pname] = _new_bucket()
		for odef: Dictionary in PROFILE_DEFS:
			matrix[pname][str(odef["name"])] = { "wins": 0, "losses": 0, "stalls": 0 }

	for p1_def: Dictionary in PROFILE_DEFS:
		var p1_name: String = str(p1_def["name"])
		for p2_def: Dictionary in PROFILE_DEFS:
			var p2_name: String = str(p2_def["name"])
			for _g: int in range(games_per_pair):
				var base_bot: CharacterData = ClassFactory.create_random_enemy(level, difficulty)
				var p1: CharacterData = base_bot.duplicate(true) as CharacterData
				var p2: CharacterData = base_bot.duplicate(true) as CharacterData
				p1.character_name = "P1"
				p2.character_name = "P2"
				p1.ai_profile = _profiles[p1_name]
				p2.ai_profile = _profiles[p2_name]

				var res: Dictionary = _sim.simulate_match(p1, p2, difficulty, difficulty)
				total_matches += 1
				total_turns += int(res["turns"])

				_record_telemetry(profile_stats[p1_name], res["p1_tel"] as Dictionary, int(res["winner"]) == 1, bool(res["stalled"]), int(res["turns"]))
				_record_telemetry(profile_stats[p2_name], res["p2_tel"] as Dictionary, int(res["winner"]) == 2, bool(res["stalled"]), int(res["turns"]))

				if bool(res["stalled"]):
					stalls_total += 1
					matrix[p1_name][p2_name]["stalls"] += 1
				elif int(res["winner"]) == 1:
					matrix[p1_name][p2_name]["wins"] += 1
				else:
					matrix[p1_name][p2_name]["losses"] += 1

	return {
		"level": level,
		"total_matches": total_matches,
		"avg_turns": float(total_turns) / float(maxi(1, total_matches)),
		"stalls": stalls_total,
		"matrix_p1_vs_p2": matrix,
		"profiles": _finalize_buckets(profile_stats),
	}


func _run_class_synergy_suite(games_per_combo: int, difficulty: GameManager.Difficulty) -> Dictionary:
	var class_winrates: Dictionary = {}
	var synergy: Dictionary = {}
	var total_matches: int = 0
	var stalls_total: int = 0

	for cdef: Dictionary in CLASS_DEFS:
		var cname: String = str(cdef["name"])
		class_winrates[cname] = { "wins": 0, "games": 0 }
		synergy[cname] = {}
		for pdef: Dictionary in PROFILE_DEFS:
			synergy[cname][str(pdef["name"])] = { "wins": 0, "games": 0, "stalls": 0 }

	for cdef: Dictionary in CLASS_DEFS:
		var cname: String = str(cdef["name"])
		var ctype: CharacterData.ClassType = cdef["type"] as CharacterData.ClassType
		for pdef: Dictionary in PROFILE_DEFS:
			var pname: String = str(pdef["name"])
			for g: int in range(games_per_combo):
				var opp_cdef: Dictionary = CLASS_DEFS.pick_random()
				var opp_pdef: Dictionary = PROFILE_DEFS.pick_random()

				var subject: CharacterData = ClassFactory.create_character(ctype, "Subject")
				subject.ai_profile = _profiles[pname]
				var opp: CharacterData = ClassFactory.create_character(opp_cdef["type"] as CharacterData.ClassType, "Opp")
				opp.ai_profile = _profiles[str(opp_pdef["name"])]

				var subject_is_p1: bool = (g % 2 == 0)
				var res: Dictionary = _sim.simulate_match(subject, opp, difficulty, difficulty) if subject_is_p1 else _sim.simulate_match(opp, subject, difficulty, difficulty)
				total_matches += 1

				var subject_won: bool = (int(res["winner"]) == 1) if subject_is_p1 else (int(res["winner"]) == 2)
				synergy[cname][pname]["games"] += 1
				class_winrates[cname]["games"] += 1
				if bool(res["stalled"]):
					stalls_total += 1
					synergy[cname][pname]["stalls"] += 1
				elif subject_won:
					synergy[cname][pname]["wins"] += 1
					class_winrates[cname]["wins"] += 1

	return {
		"total_matches": total_matches,
		"stalls": stalls_total,
		"class_winrates": class_winrates,
		"class_x_profile": synergy,
	}


func _run_difficulty_ladder_suite(games_per_pair: int) -> Dictionary:
	var pairs: Array[Dictionary] = [
		{ "label": "VERY_EASY_vs_MEDIUM", "a": GameManager.Difficulty.VERY_EASY, "b": GameManager.Difficulty.MEDIUM },
		{ "label": "EASY_vs_HARD", "a": GameManager.Difficulty.EASY, "b": GameManager.Difficulty.HARD },
		{ "label": "MEDIUM_vs_HARD", "a": GameManager.Difficulty.MEDIUM, "b": GameManager.Difficulty.HARD },
	]
	var out: Dictionary = {}
	for pair: Dictionary in pairs:
		var a_wins: int = 0
		var b_wins: int = 0
		var stalls: int = 0
		for g: int in range(games_per_pair):
			var ctype: CharacterData.ClassType = CLASS_DEFS[g % CLASS_DEFS.size()]["type"] as CharacterData.ClassType
			var p1: CharacterData = ClassFactory.create_character(ctype, "A")
			var p2: CharacterData = ClassFactory.create_character(ctype, "B")
			p1.ai_profile = _profiles["Balanced"]
			p2.ai_profile = _profiles["Balanced"]
			var a_is_p1: bool = (g % 2 == 0)
			var res: Dictionary = _sim.simulate_match(p1, p2, pair["a"] as GameManager.Difficulty, pair["b"] as GameManager.Difficulty) if a_is_p1 else _sim.simulate_match(p2, p1, pair["b"] as GameManager.Difficulty, pair["a"] as GameManager.Difficulty)
			if bool(res["stalled"]):
				stalls += 1
			elif (int(res["winner"]) == 1 and a_is_p1) or (int(res["winner"]) == 2 and not a_is_p1):
				a_wins += 1
			else:
				b_wins += 1
		out[str(pair["label"])] = { "a_wins": a_wins, "b_wins": b_wins, "stalls": stalls }
	return out


func _new_bucket() -> Dictionary:
	return {
		"games": 0, "wins": 0, "stalls": 0, "turns": 0,
		"struggles": 0, "offence": 0, "defence": 0,
		"total_cost": 0, "feints": 0, "cards": {},
	}


func _record_telemetry(bucket: Dictionary, tel: Dictionary, won: bool, stalled: bool, match_turns: int) -> void:
	bucket["games"] += 1
	if won: bucket["wins"] += 1
	if stalled: bucket["stalls"] += 1
	bucket["turns"] += match_turns
	bucket["struggles"] += int(tel["struggles"])
	bucket["offence"] += int(tel["offence"])
	bucket["defence"] += int(tel["defence"])
	bucket["total_cost"] += int(tel["total_cost"])
	bucket["feints"] += int(tel["feints"])
	var cards_dict: Dictionary = tel["cards"] as Dictionary
	for cname: String in cards_dict:
		bucket["cards"][cname] = int(bucket["cards"].get(cname, 0)) + int(cards_dict[cname])


func _finalize_buckets(stats: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for pname: String in stats:
		var b: Dictionary = stats[pname]
		var total_actions: int = maxi(1, int(b["offence"]) + int(b["defence"]))
		var games: int = maxi(1, int(b["games"]))

		var card_pairs: Array[Dictionary] = []
		for cname: String in b["cards"]:
			card_pairs.append({ "name": cname, "count": int(b["cards"][cname]) })
		card_pairs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["count"]) > int(y["count"]))
		var top_cards: Array[Dictionary] = []
		for i: int in range(mini(5, card_pairs.size())):
			top_cards.append({
				"name": card_pairs[i]["name"],
				"pct": snappedf(100.0 * float(card_pairs[i]["count"]) / float(total_actions), 0.1)
			})

		out[pname] = {
			"games": b["games"],
			"wins": b["wins"],
			"win_rate_pct": snappedf(100.0 * float(b["wins"]) / float(games), 0.1),
			"stalls": b["stalls"],
			"avg_turns": snappedf(float(b["turns"]) / float(games), 0.1),
			"struggle_pct": snappedf(100.0 * float(b["struggles"]) / float(total_actions), 0.1),
			"offence_pct": snappedf(100.0 * float(b["offence"]) / float(total_actions), 0.1),
			"avg_cost": snappedf(float(b["total_cost"]) / float(total_actions), 0.01),
			"feints_per_match": snappedf(float(b["feints"]) / float(games), 0.01),
			"top_cards": top_cards,
		}
	return out
