extends Node

const REPORT_OUTPUT_PATH: String = "res://equipment_balance_report.json"
const CombatSimulatorScript = preload("res://Scripts/Balance/CombatSimulator.gd")

const CLASS_DEFS: Array[Dictionary] = [
	{ "name": "Heavy", "type": CharacterData.ClassType.HEAVY },
	{ "name": "Patient", "type": CharacterData.ClassType.PATIENT },
	{ "name": "Quick", "type": CharacterData.ClassType.QUICK },
	{ "name": "Technical", "type": CharacterData.ClassType.TECHNICAL },
]

const EQUIPMENT_DEFS: Array[Dictionary] = [
	{ "name": "None_Baseline", "path": "" },
	{ "name": "Adrenaline", "path": "res://Data/Equipment/Adrenaline.tres" },
	{ "name": "BodyArmour", "path": "res://Data/Equipment/BodyArmour.tres" },
	{ "name": "BoxingTape", "path": "res://Data/Equipment/BoxingTape.tres" },
	{ "name": "EnergyDrink", "path": "res://Data/Equipment/EnergyDrink.tres" },
	{ "name": "FlowBandana", "path": "res://Data/Equipment/FlowBandana.tres" },
	{ "name": "ScouterImplant", "path": "res://Data/Equipment/ScouterImplant.tres" },
	{ "name": "SpikedCleats", "path": "res://Data/Equipment/SpikedCleats.tres" },
	{ "name": "SpikedJacket", "path": "res://Data/Equipment/SpikedJacket.tres" },
	{ "name": "SpikedWraps", "path": "res://Data/Equipment/SpikedWraps.tres" },
	{ "name": "WeightedKnuckles", "path": "res://Data/Equipment/WeightedKnuckles.tres" },
]

var _sim: CombatSimulator = null


func _ready() -> void:
	seed(555111)
	RunManager.clear_active_run_state()
	GameManager.apply_environment_rules("Dojo")

	_sim = CombatSimulatorScript.new()
	_sim.connect_signals()

	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = {
		"seed": 555111,
		"lv_1": _run_level_equipment_suite(1, 20),
		"lv_6": _run_level_equipment_suite(6, 20),
	}
	report["elapsed_ms"] = Time.get_ticks_msec() - t0
	_sim.dispose()

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("EQUIP_BALANCE_DONE elapsed_ms=", report["elapsed_ms"])
	else:
		printerr("EQUIP_BALANCE_ERROR failed to write report")

	get_tree().quit()


func _run_level_equipment_suite(level: int, games_per_class: int) -> Dictionary:
	var out: Dictionary = {}
	for edef: Dictionary in EQUIPMENT_DEFS:
		var ename: String = str(edef["name"])
		var path: String = str(edef["path"])
		var eq: EquipmentData = load(path) as EquipmentData if path != "" else null
		var total_wins: int = 0
		var total_games: int = 0
		var total_stalls: int = 0
		var per_class: Dictionary = {}

		for cdef: Dictionary in CLASS_DEFS:
			var cname: String = str(cdef["name"])
			var wins: int = 0
			var stalls: int = 0
			var turns: int = 0

			for g: int in range(games_per_class):
				var opp_def: Dictionary = CLASS_DEFS[g % CLASS_DEFS.size()]
				var subject: CharacterData = CombatSimulatorScript.build_fighter(cdef["type"] as CharacterData.ClassType, level, false, "Sub")
				if eq != null:
					subject.equipment.append(eq)
					subject.max_hp = maxi(1, subject.max_hp + eq.bonus_max_hp)
					subject.max_sp = maxi(1, subject.max_sp + eq.bonus_max_sp)
					subject.current_hp = subject.max_hp
					subject.current_sp = subject.max_sp

				var opp: CharacterData = CombatSimulatorScript.build_fighter(opp_def["type"] as CharacterData.ClassType, level, false, "Opp")
				var sub_p1: bool = (g % 2 == 0)
				var res: Dictionary = _sim.simulate_match(subject, opp) if sub_p1 else _sim.simulate_match(opp, subject)
				turns += int(res["turns"])
				if bool(res["stalled"]):
					stalls += 1
				elif (int(res["winner"]) == 1 and sub_p1) or (int(res["winner"]) == 2 and not sub_p1):
					wins += 1

			total_wins += wins
			total_games += games_per_class
			total_stalls += stalls
			per_class[cname] = {
				"wr_pct": snappedf(100.0 * float(wins) / float(games_per_class), 0.1),
				"stalls": stalls,
				"avg_turns": snappedf(float(turns) / float(games_per_class), 0.1),
			}

		out[ename] = {
			"overall_wr_pct": snappedf(100.0 * float(total_wins) / float(maxi(1, total_games)), 0.1),
			"stalls": total_stalls,
			"classes": per_class,
		}
	return out
