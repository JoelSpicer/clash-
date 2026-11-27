extends Node

const REPORT_OUTPUT_PATH: String = "res://class_balance_report.json"
const CombatSimulatorScript = preload("res://Scripts/Balance/CombatSimulator.gd")

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

var _sim: CombatSimulator = null


func _ready() -> void:
	seed(777888)
	RunManager.clear_active_run_state()
	_sim = CombatSimulatorScript.new()
	_sim.connect_signals()

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

	# Suite 5: What-If Speed Diagnostic (Lv.1 with advertised Speeds 1/2/3/4)
	GameManager.apply_environment_rules("Dojo")
	report["suites"]["lv1_with_advertised_speeds"] = _run_class_round_robin(10, 1, false, true)

	# Suite 6: Authored Presets Showdown (full library = true, matching multiplayer)
	GameManager.apply_environment_rules("Dojo")
	report["suites"]["presets_showdown"] = _run_presets_suite(4)

	var elapsed_ms: int = Time.get_ticks_msec() - t0
	report["elapsed_ms"] = elapsed_ms
	_sim.dispose()

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("CLASS_BALANCE_DONE elapsed_ms=", elapsed_ms, " path=", REPORT_OUTPUT_PATH)
	else:
		printerr("CLASS_BALANCE_ERROR failed to write report")

	get_tree().quit()


func _build_fighter(ctype: CharacterData.ClassType, level: int, full_library: bool, use_advertised_speed: bool, label: String) -> CharacterData:
	var c: CharacterData = CombatSimulatorScript.build_fighter(ctype, level, full_library, label)
	if use_advertised_speed:
		for cdef: Dictionary in CLASS_DEFS:
			if cdef["type"] == ctype:
				c.speed = int(cdef["advertised_speed"])
				break
	return c


func _run_class_round_robin(games_per_pair: int, level: int, full_library: bool, use_advertised_speed: bool) -> Dictionary:
	var matrix: Dictionary = {}
	var stats: Dictionary = {}
	var total_matches: int = 0
	var total_turns: int = 0
	var total_stalls: int = 0
	var total_wall_crushes: int = 0
	var total_supers: int = 0

	for cdef: Dictionary in CLASS_DEFS:
		var cname: String = str(cdef["name"])
		matrix[cname] = {}
		stats[cname] = _new_class_bucket()
		for odef: Dictionary in CLASS_DEFS:
			matrix[cname][str(odef["name"])] = { "wins": 0, "losses": 0, "stalls": 0 }

	for c1_def: Dictionary in CLASS_DEFS:
		var c1_name: String = str(c1_def["name"])
		for c2_def: Dictionary in CLASS_DEFS:
			var c2_name: String = str(c2_def["name"])
			for _g: int in range(games_per_pair):
				var p1: CharacterData = _build_fighter(c1_def["type"] as CharacterData.ClassType, level, full_library, use_advertised_speed, "P1_" + c1_name)
				var p2: CharacterData = _build_fighter(c2_def["type"] as CharacterData.ClassType, level, full_library, use_advertised_speed, "P2_" + c2_name)

				var res: Dictionary = _sim.simulate_match(p1, p2, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD)
				total_matches += 1
				total_turns += int(res["turns"])
				total_wall_crushes += int(res["wc_p1"]) + int(res["wc_p2"])
				total_supers += int(res["supers_p1"]) + int(res["supers_p2"])

				var is_mirror: bool = (c1_name == c2_name)
				_record_class_bucket(stats[c1_name], int(res["winner"]) == 1, bool(res["stalled"]), int(res["turns"]), res["p1_tel"] as Dictionary, int(res["wc_p1"]), int(res["supers_p1"]), is_mirror, p1.deck.size())
				_record_class_bucket(stats[c2_name], int(res["winner"]) == 2, bool(res["stalled"]), int(res["turns"]), res["p2_tel"] as Dictionary, int(res["wc_p2"]), int(res["supers_p2"]), is_mirror, p2.deck.size())

				if bool(res["stalled"]):
					total_stalls += 1
					matrix[c1_name][c2_name]["stalls"] += 1
				elif int(res["winner"]) == 1:
					matrix[c1_name][c2_name]["wins"] += 1
				else:
					matrix[c1_name][c2_name]["losses"] += 1

	return {
		"level": level,
		"full_library": full_library,
		"advertised_speed": use_advertised_speed,
		"total_matches": total_matches,
		"avg_turns": snappedf(float(total_turns) / float(maxi(1, total_matches)), 0.1),
		"stalls": total_stalls,
		"wall_crushes_per_match": snappedf(float(total_wall_crushes) / float(maxi(1, total_matches)), 0.02),
		"supers_per_match": snappedf(float(total_supers) / float(maxi(1, total_matches)), 0.02),
		"classes": _finalize_class_buckets(stats),
		"matrix_p1_vs_p2": matrix,
	}


func _run_equipment_suite(games_per_combo: int, level: int) -> Dictionary:
	var out: Dictionary = {}
	for edef: Dictionary in EQUIPMENT_DEFS:
		var ename: String = str(edef["name"])
		var eq: EquipmentData = load(str(edef["path"])) as EquipmentData
		out[ename] = {}
		for cdef: Dictionary in CLASS_DEFS:
			var cname: String = str(cdef["name"])
			var wins: int = 0
			var stalls: int = 0
			var turns: int = 0
			for g: int in range(games_per_combo):
				var opp_def: Dictionary = CLASS_DEFS.pick_random()
				var subject: CharacterData = _build_fighter(cdef["type"] as CharacterData.ClassType, level, false, false, "Sub")
				subject.equipment.append(eq)
				subject.max_hp = maxi(1, subject.max_hp + eq.bonus_max_hp)
				subject.max_sp = maxi(1, subject.max_sp + eq.bonus_max_sp)
				subject.current_hp = subject.max_hp
				subject.current_sp = subject.max_sp

				var opp: CharacterData = _build_fighter(opp_def["type"] as CharacterData.ClassType, level, false, false, "Opp")
				var sub_p1: bool = (g % 2 == 0)
				var res: Dictionary = _sim.simulate_match(subject, opp, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD) if sub_p1 else _sim.simulate_match(opp, subject, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD)
				turns += int(res["turns"])
				if bool(res["stalled"]):
					stalls += 1
				elif (int(res["winner"]) == 1 and sub_p1) or (int(res["winner"]) == 2 and not sub_p1):
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
	for pdef: Dictionary in PRESET_DEFS:
		var res_preset: PresetCharacter = load(str(pdef["path"])) as PresetCharacter
		if res_preset:
			loaded.append({ "name": str(pdef["name"]), "preset": res_preset })

	var stats: Dictionary = {}
	for entry: Dictionary in loaded:
		var sample: CharacterData = ClassFactory.create_from_preset(entry["preset"] as PresetCharacter, true)
		stats[str(entry["name"])] = {
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
	for e1: Dictionary in loaded:
		for e2: Dictionary in loaded:
			if e1["name"] == e2["name"]:
				continue
			for _g: int in range(games_per_pair):
				var p1: CharacterData = ClassFactory.create_from_preset(e1["preset"] as PresetCharacter, true)
				var p2: CharacterData = ClassFactory.create_from_preset(e2["preset"] as PresetCharacter, true)
				p1.ai_profile = ClassFactory.pick_random_ai_profile()
				p2.ai_profile = ClassFactory.pick_random_ai_profile()

				var res: Dictionary = _sim.simulate_match(p1, p2, GameManager.Difficulty.HARD, GameManager.Difficulty.HARD)
				total_matches += 1
				stats[str(e1["name"])]["games"] += 1
				stats[str(e2["name"])]["games"] += 1
				stats[str(e1["name"])]["turns"] += int(res["turns"])
				stats[str(e2["name"])]["turns"] += int(res["turns"])
				if bool(res["stalled"]):
					stats[str(e1["name"])]["stalls"] += 1
					stats[str(e2["name"])]["stalls"] += 1
				elif int(res["winner"]) == 1:
					stats[str(e1["name"])]["wins"] += 1
				else:
					stats[str(e2["name"])]["wins"] += 1

	for pname: String in stats:
		var s: Dictionary = stats[pname]
		var g: int = maxi(1, int(s["games"]))
		s["win_rate_pct"] = snappedf(100.0 * float(s["wins"]) / float(g), 0.1)
		s["avg_turns"] = snappedf(float(s["turns"]) / float(g), 0.1)
		s.erase("turns")

	return { "total_matches": total_matches, "presets": stats }


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
	b["struggles"] += int(tel["struggles"])
	b["offence"] += int(tel["offence"])
	b["defence"] += int(tel["defence"])
	b["total_cost"] += int(tel["total_cost"])
	b["wall_crushed"] += wc
	b["supers"] += supers
	b["tech_uses"] += int(tel["tech_uses"])
	b["deck_size_sum"] += deck_size
	var cards_dict: Dictionary = tel["cards"] as Dictionary
	for cname: String in cards_dict:
		b["cards"][cname] = int(b["cards"].get(cname, 0)) + int(cards_dict[cname])


func _finalize_class_buckets(stats: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cname: String in stats:
		var b: Dictionary = stats[cname]
		var g: int = maxi(1, int(b["games"]))
		var nmg: int = maxi(1, int(b["non_mirror_games"]))
		var actions: int = maxi(1, int(b["offence"]) + int(b["defence"]))

		var pairs: Array[Dictionary] = []
		for k: String in b["cards"]:
			pairs.append({ "name": k, "count": int(b["cards"][k]) })
		pairs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["count"]) > int(y["count"]))
		var top_cards: Array[Dictionary] = []
		for i: int in range(mini(4, pairs.size())):
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
