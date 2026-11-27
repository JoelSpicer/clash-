extends Node

const REPORT_OUTPUT_PATH: String = "res://sponsor_balance_report.json"
const CombatSimulatorScript = preload("res://Scripts/Balance/CombatSimulator.gd")

const CLASS_DEFS: Array[Dictionary] = [
	{ "name": "Heavy", "type": CharacterData.ClassType.HEAVY },
	{ "name": "Patient", "type": CharacterData.ClassType.PATIENT },
	{ "name": "Quick", "type": CharacterData.ClassType.QUICK },
	{ "name": "Technical", "type": CharacterData.ClassType.TECHNICAL },
]

const SPONSOR_DEFS: Array[Dictionary] = [
	{ "name": "None_Baseline", "path": "" },
	{ "name": "CRASHSupplements", "path": "res://Data/Sponsors/CRASHSupplements.tres" },
	{ "name": "SLAMSupplements", "path": "res://Data/Sponsors/SLAMSupplements.tres" },
	{ "name": "AegisIndustrial", "path": "res://Data/Sponsors/AegisIndustrial.tres" },
	{ "name": "OlympusSportsMed", "path": "res://Data/Sponsors/OlympusSportsMed.tres" },
	{ "name": "VanguardLogistics", "path": "res://Data/Sponsors/VanguardLogistics.tres" },
	{ "name": "NeonMediaGroup", "path": "res://Data/Sponsors/NeonMediaGroup.tres" },
	{ "name": "TitanDemolitions", "path": "res://Data/Sponsors/TitanDemolitions.tres" },
	{ "name": "OmniCorpAnalytics", "path": "res://Data/Sponsors/OmniCorpAnalytics.tres" },
	{ "name": "ApexGenetics", "path": "res://Data/Sponsors/ApexGenetics.tres" },
	{ "name": "HorizonTech", "path": "res://Data/Sponsors/HorizonTech.tres" },
	{ "name": "PhantomSyndicate", "path": "res://Data/Sponsors/PhantomSyndicate.tres" },
]

var _sim: CombatSimulator = null


func _ready() -> void:
	seed(888333)
	RunManager.clear_active_run_state()
	GameManager.apply_environment_rules("Dojo")

	_sim = CombatSimulatorScript.new()
	_sim.connect_signals()

	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = {
		"seed": 888333,
		"lv_1": _run_level_sponsor_suite(1, 10),
		"lv_6": _run_level_sponsor_suite(6, 10),
	}
	report["elapsed_ms"] = Time.get_ticks_msec() - t0

	RunManager.clear_active_run_state()
	_sim.dispose()

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("SPONSOR_BALANCE_DONE elapsed_ms=", report["elapsed_ms"])
	else:
		printerr("SPONSOR_BALANCE_ERROR failed to write report")

	get_tree().quit()


func _run_level_sponsor_suite(level: int, games_per_class: int) -> Dictionary:
	var out: Dictionary = {}
	for sdef: Dictionary in SPONSOR_DEFS:
		var sname: String = str(sdef["name"])
		var path: String = str(sdef["path"])
		var sponsor: SponsorData = load(path) as SponsorData if path != "" else null
		# Enable Arcade mode when testing a sponsor so CombatRules applies sponsor passives cleanly
		RunManager.is_arcade_mode = (sponsor != null)
		RunManager.active_sponsor = sponsor

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
				var subject: CharacterData = CombatSimulatorScript.build_fighter(cdef["type"] as CharacterData.ClassType, level, false, "P1_Sub")
				if sponsor != null:
					subject.max_hp += sponsor.bonus_max_hp
					subject.max_sp += sponsor.bonus_max_sp
					for eq: EquipmentData in sponsor.starting_equipment:
						if eq == null:
							continue
						subject.equipment.append(eq)
						subject.max_hp += eq.bonus_max_hp
						subject.max_sp += eq.bonus_max_sp
					subject.max_hp = maxi(1, subject.max_hp)
					subject.max_sp = maxi(1, subject.max_sp)
					subject.current_hp = subject.max_hp
					subject.current_sp = subject.max_sp

				var opp: CharacterData = CombatSimulatorScript.build_fighter(opp_def["type"] as CharacterData.ClassType, level, false, "P2_Opp")
				var res: Dictionary = _sim.simulate_match(subject, opp)
				turns += int(res["turns"])
				if bool(res["stalled"]):
					stalls += 1
				elif int(res["winner"]) == 1:
					wins += 1

			total_wins += wins
			total_games += games_per_class
			total_stalls += stalls
			per_class[cname] = {
				"wr_pct": snappedf(100.0 * float(wins) / float(games_per_class), 0.1),
				"stalls": stalls,
				"avg_turns": snappedf(float(turns) / float(games_per_class), 0.1),
			}

		out[sname] = {
			"overall_wr_pct": snappedf(100.0 * float(total_wins) / float(maxi(1, total_games)), 0.1),
			"stalls": total_stalls,
			"classes": per_class,
		}
	return out
