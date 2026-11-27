extends Node

const REPORT_OUTPUT_PATH: String = "res://boss_balance_report.json"
const CombatSimulatorScript = preload("res://Scripts/Balance/CombatSimulator.gd")

const CLASS_DEFS: Array[Dictionary] = [
	{ "name": "Heavy", "type": CharacterData.ClassType.HEAVY },
	{ "name": "Patient", "type": CharacterData.ClassType.PATIENT },
	{ "name": "Quick", "type": CharacterData.ClassType.QUICK },
	{ "name": "Technical", "type": CharacterData.ClassType.TECHNICAL },
]

const PLAYER_COMBAT_EQUIPMENT: Array[String] = [
	"res://Data/Equipment/Adrenaline.tres",
	"res://Data/Equipment/BodyArmour.tres",
	"res://Data/Equipment/BoxingTape.tres",
	"res://Data/Equipment/EnergyDrink.tres",
	"res://Data/Equipment/FlowBandana.tres",
	"res://Data/Equipment/SpikedCleats.tres",
	"res://Data/Equipment/SpikedJacket.tres",
	"res://Data/Equipment/SpikedWraps.tres",
	"res://Data/Equipment/WeightedKnuckles.tres",
]

const BOSS_MOD_PATHS: Array[Dictionary] = [
	{ "name": "Juggernaut", "path": "res://Data/BossModifiers/juggernaut.tres" },
	{ "name": "IronWall", "path": "res://Data/BossModifiers/iron_wall.tres" },
	{ "name": "BlitzChampion", "path": "res://Data/BossModifiers/blitz_champion.tres" },
	{ "name": "Grandmaster", "path": "res://Data/BossModifiers/grandmaster.tres" },
	{ "name": "Berserker", "path": "res://Data/BossModifiers/berserker.tres" },
	{ "name": "Tactician", "path": "res://Data/BossModifiers/tactician.tres" },
]

var _player_eq_pool: Array[EquipmentData] = []
var _sim: CombatSimulator = null


func _ready() -> void:
	seed(777222)
	RunManager.clear_active_run_state()
	GameManager.apply_environment_rules("Dojo")

	for path: String in PLAYER_COMBAT_EQUIPMENT:
		var eq: EquipmentData = load(path) as EquipmentData
		if eq:
			_player_eq_pool.append(eq)

	_sim = CombatSimulatorScript.new()
	_sim.connect_signals()

	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = {
		"seed": 777222,
		"mid_boss_lv5_vs_lv6": _run_tier_suite(5, 6, 1, 10),
		"finals_l1_lv10_vs_lv12": _run_tier_suite(10, 12, 2, 10),
		"finals_l2_double_mod_lv18_vs_lv20": _run_double_mod_suite(18, 20, 3, 20),
	}
	report["elapsed_ms"] = Time.get_ticks_msec() - t0
	_sim.dispose()

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("BOSS_BALANCE_DONE elapsed_ms=", report["elapsed_ms"])
	else:
		printerr("BOSS_BALANCE_ERROR failed to write report")

	get_tree().quit()


func _run_tier_suite(player_level: int, boss_level: int, player_eq_count: int, games_per_class: int) -> Dictionary:
	var out: Dictionary = {}
	for bdef: Dictionary in BOSS_MOD_PATHS:
		var bname: String = str(bdef["name"])
		var mod: EquipmentData = load(str(bdef["path"])) as EquipmentData
		var total_player_wins: int = 0
		var total_games: int = 0
		var total_stalls: int = 0
		var total_turns: int = 0
		var per_class: Dictionary = {}

		for cdef: Dictionary in CLASS_DEFS:
			var cname: String = str(cdef["name"])
			var wins: int = 0
			var stalls: int = 0
			var turns: int = 0

			for _g: int in range(games_per_class):
				var player: CharacterData = _build_player_fighter(cdef["type"] as CharacterData.ClassType, player_level, player_eq_count)
				var mods: Array[EquipmentData] = [mod]
				var boss: CharacterData = ClassFactory.create_boss_enemy(boss_level, GameManager.Difficulty.HARD, mods)
				var res: Dictionary = _sim.simulate_match(player, boss)
				turns += int(res["turns"])
				if bool(res["stalled"]):
					stalls += 1
				elif int(res["winner"]) == 1:
					wins += 1

			total_player_wins += wins
			total_games += games_per_class
			total_stalls += stalls
			total_turns += turns
			per_class[cname] = {
				"player_wr_pct": snappedf(100.0 * float(wins) / float(games_per_class), 0.1),
				"stalls": stalls,
				"avg_turns": snappedf(float(turns) / float(games_per_class), 0.1),
			}

		out[bname] = {
			"player_wr_pct": snappedf(100.0 * float(total_player_wins) / float(maxi(1, total_games)), 0.1),
			"stalls": total_stalls,
			"avg_turns": snappedf(float(total_turns) / float(maxi(1, total_games)), 0.1),
			"classes": per_class,
		}
	return out


func _run_double_mod_suite(player_level: int, boss_level: int, player_eq_count: int, games_per_class: int) -> Dictionary:
	var all_mods: Array[EquipmentData] = []
	for bdef: Dictionary in BOSS_MOD_PATHS:
		var m: EquipmentData = load(str(bdef["path"])) as EquipmentData
		if m:
			all_mods.append(m)

	var total_player_wins: int = 0
	var total_games: int = 0
	var total_stalls: int = 0
	var total_turns: int = 0
	var per_class: Dictionary = {}

	for cdef: Dictionary in CLASS_DEFS:
		var cname: String = str(cdef["name"])
		var wins: int = 0
		var stalls: int = 0
		var turns: int = 0

		for _g: int in range(games_per_class):
			var player: CharacterData = _build_player_fighter(cdef["type"] as CharacterData.ClassType, player_level, player_eq_count)
			var shuffled: Array[EquipmentData] = all_mods.duplicate()
			shuffled.shuffle()
			var pair: Array[EquipmentData] = [shuffled[0], shuffled[1]]
			var boss: CharacterData = ClassFactory.create_boss_enemy(boss_level, GameManager.Difficulty.HARD, pair)
			var res: Dictionary = _sim.simulate_match(player, boss)
			turns += int(res["turns"])
			if bool(res["stalled"]):
				stalls += 1
			elif int(res["winner"]) == 1:
				wins += 1

		total_player_wins += wins
		total_games += games_per_class
		total_stalls += stalls
		total_turns += turns
		per_class[cname] = {
			"player_wr_pct": snappedf(100.0 * float(wins) / float(games_per_class), 0.1),
			"stalls": stalls,
			"avg_turns": snappedf(float(turns) / float(games_per_class), 0.1),
		}

	return {
		"player_wr_pct": snappedf(100.0 * float(total_player_wins) / float(maxi(1, total_games)), 0.1),
		"stalls": total_stalls,
		"avg_turns": snappedf(float(total_turns) / float(maxi(1, total_games)), 0.1),
		"classes": per_class,
	}


func _build_player_fighter(ctype: CharacterData.ClassType, level: int, eq_count: int) -> CharacterData:
	var c: CharacterData = CombatSimulatorScript.build_fighter(ctype, level, false, "Player")

	var eq_choices: Array[EquipmentData] = _player_eq_pool.duplicate()
	eq_choices.shuffle()
	for i: int in range(mini(eq_count, eq_choices.size())):
		var eq: EquipmentData = eq_choices[i]
		c.equipment.append(eq)
		c.max_hp = maxi(1, c.max_hp + eq.bonus_max_hp)
		c.max_sp = maxi(1, c.max_sp + eq.bonus_max_sp)

	c.current_hp = c.max_hp
	c.current_sp = c.max_sp
	return c
