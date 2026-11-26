extends Node

const MAX_TURNS: int = 80
const REPORT_OUTPUT_PATH: String = "res://boss_balance_report.json"

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

var _match_winner: int = 0
var _active_p1: CharacterData
var _active_p2: CharacterData
var _player_eq_pool: Array[EquipmentData] = []


func _ready() -> void:
	seed(777222)

	RunManager.is_arcade_mode = false
	RunManager.player_run_data = null
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""
	RunManager.is_boss_match = false
	RunManager.is_rival_match = false
	GameManager.apply_environment_rules("Dojo")

	for path: String in PLAYER_COMBAT_EQUIPMENT:
		var eq: EquipmentData = load(path) as EquipmentData
		if eq:
			_player_eq_pool.append(eq)

	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)

	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = {
		"seed": 777222,
		"mid_boss_lv5_vs_lv6": _run_tier_suite(5, 6, 1, 10),
		"finals_l1_lv10_vs_lv12": _run_tier_suite(10, 12, 2, 10),
		"finals_l2_double_mod_lv18_vs_lv20": _run_double_mod_suite(18, 20, 3, 20),
	}
	report["elapsed_ms"] = Time.get_ticks_msec() - t0

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("BOSS_BALANCE_DONE elapsed_ms=", report["elapsed_ms"])
	else:
		printerr("BOSS_BALANCE_ERROR failed to write report")

	get_tree().quit()


func _on_game_over(winner_id: int) -> void:
	if _match_winner == 0:
		_match_winner = winner_id


func _run_tier_suite(player_level: int, boss_level: int, player_eq_count: int, games_per_class: int) -> Dictionary:
	var out: Dictionary = {}
	for bdef: Dictionary in BOSS_MOD_PATHS:
		var bname: String = bdef["name"]
		var mod: EquipmentData = load(bdef["path"]) as EquipmentData
		var total_player_wins: int = 0
		var total_games: int = 0
		var total_stalls: int = 0
		var total_turns: int = 0
		var per_class: Dictionary = {}

		for cdef: Dictionary in CLASS_DEFS:
			var cname: String = cdef["name"]
			var wins: int = 0
			var stalls: int = 0
			var turns: int = 0

			for _g in range(games_per_class):
				var player: CharacterData = _build_player_fighter(cdef["type"], player_level, player_eq_count)
				var mods: Array[EquipmentData] = [mod]
				var boss: CharacterData = ClassFactory.create_boss_enemy(boss_level, GameManager.Difficulty.HARD, mods)
				var res: Dictionary = _simulate_match(player, boss)
				turns += res["turns"]
				if res["stalled"]:
					stalls += 1
				elif res["winner"] == 1:
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
			"player_wr_pct": snappedf(100.0 * float(total_player_wins) / float(max(1, total_games)), 0.1),
			"stalls": total_stalls,
			"avg_turns": snappedf(float(total_turns) / float(max(1, total_games)), 0.1),
			"classes": per_class,
		}
	return out


func _run_double_mod_suite(player_level: int, boss_level: int, player_eq_count: int, games_per_class: int) -> Dictionary:
	var all_mods: Array[EquipmentData] = []
	for bdef: Dictionary in BOSS_MOD_PATHS:
		var m: EquipmentData = load(bdef["path"]) as EquipmentData
		if m:
			all_mods.append(m)

	var total_player_wins: int = 0
	var total_games: int = 0
	var total_stalls: int = 0
	var total_turns: int = 0
	var per_class: Dictionary = {}

	for cdef: Dictionary in CLASS_DEFS:
		var cname: String = cdef["name"]
		var wins: int = 0
		var stalls: int = 0
		var turns: int = 0

		for _g in range(games_per_class):
			var player: CharacterData = _build_player_fighter(cdef["type"], player_level, player_eq_count)
			var shuffled: Array[EquipmentData] = all_mods.duplicate()
			shuffled.shuffle()
			var pair: Array[EquipmentData] = [shuffled[0], shuffled[1]]
			var boss: CharacterData = ClassFactory.create_boss_enemy(boss_level, GameManager.Difficulty.HARD, pair)
			var res: Dictionary = _simulate_match(player, boss)
			turns += res["turns"]
			if res["stalled"]:
				stalls += 1
			elif res["winner"] == 1:
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
		"player_wr_pct": snappedf(100.0 * float(total_player_wins) / float(max(1, total_games)), 0.1),
		"stalls": total_stalls,
		"avg_turns": snappedf(float(total_turns) / float(max(1, total_games)), 0.1),
		"classes": per_class,
	}


func _build_player_fighter(ctype: CharacterData.ClassType, level: int, eq_count: int) -> CharacterData:
	var c: CharacterData = ClassFactory.create_character(ctype, "Player", false)
	c.ai_profile = ClassFactory.pick_random_ai_profile()
	if level > 1:
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
			for n: int in ClassFactory.TREE_CONNECTIONS[root_id]:
				unlockable.append(n)
		for _i in range(cards_to_draft):
			var eligible: Array[int] = []
			for cid: int in unlockable:
				var cn: Variant = ClassFactory.ID_TO_NAME_MAP.get(cid)
				if cn != null:
					var cc: ActionData = ClassFactory.find_action_resource(str(cn))
					if cc and ClassFactory.can_draft_action(cc, c.unlocked_actions):
						eligible.append(cid)
			if eligible.is_empty():
				break
			var picked: int = eligible.pick_random()
			var pname: Variant = ClassFactory.ID_TO_NAME_MAP.get(picked)
			if pname != null:
				var nc: ActionData = ClassFactory.find_action_resource(str(pname))
				if nc and not ClassFactory._has_card(c.unlocked_actions, nc):
					c.unlocked_actions.append(nc)
			owned_ids.append(picked)
			unlockable.erase(picked)
			if picked in ClassFactory.TREE_CONNECTIONS:
				for n: int in ClassFactory.TREE_CONNECTIONS[picked]:
					if n not in owned_ids and n not in unlockable:
						unlockable.append(n)
		c.deck = ClassFactory._select_smart_hand(c.unlocked_actions)
		var stat_bonus: int = level - 1
		var hp_gain: int = randi_range(0, stat_bonus)
		c.max_hp += hp_gain
		c.max_sp += (stat_bonus - hp_gain)

	# Equip random distinct standard items simulating typical run progression
	var eq_choices: Array[EquipmentData] = _player_eq_pool.duplicate()
	eq_choices.shuffle()
	for i in range(min(eq_count, eq_choices.size())):
		var eq: EquipmentData = eq_choices[i]
		c.equipment.append(eq)
		c.max_hp = max(1, c.max_hp + eq.bonus_max_hp)
		c.max_sp = max(1, c.max_sp + eq.bonus_max_sp)

	c.current_hp = c.max_hp
	c.current_sp = c.max_sp
	return c


func _simulate_match(p1: CharacterData, p2: CharacterData) -> Dictionary:
	_active_p1 = p1
	_active_p2 = p2
	_match_winner = 0
	GameManager.start_combat(p1, p2)
	GameManager.current_state = GameManager.State.SELECTION

	var turns: int = 0
	while _match_winner == 0 and turns < MAX_TURNS:
		turns += 1
		var p1_choice: Dictionary = _pick_turn_choice(1)
		var p2_choice: Dictionary = _pick_turn_choice(2)
		var p1_card: ActionData = _apply_extra_data(p1_choice["card"], p1_choice["extra"])
		var p2_card: ActionData = _apply_extra_data(p2_choice["card"], p2_choice["extra"])

		GameManager.state.p1_action_queue = p1_card
		GameManager.state.p2_action_queue = p2_card
		GameManager.state.p1_rage_active = false
		GameManager.state.p2_rage_active = false
		GameManager.state.p1_pending_feint = p1_card.feint
		GameManager.state.p2_pending_feint = p2_card.feint

		if GameManager.state.p1_pending_feint:
			_apply_feint_direct(1, _pick_feint_card(1))
		if GameManager.state.p2_pending_feint:
			_apply_feint_direct(2, _pick_feint_card(2))

		GameManager.current_state = GameManager.State.RESOLUTION
		GameManager.resolve_clash()

	return { "winner": _match_winner, "stalled": _match_winner == 0, "turns": turns }


func _apply_extra_data(action: ActionData, extra_data: Dictionary) -> ActionData:
	var tech_idx: int = extra_data.get("technique", 0)
	if action == null or tech_idx <= 0:
		return action
	var fa: ActionData = action.duplicate()
	fa.cost += 1
	match tech_idx:
		1:
			if fa.type == ActionData.Type.OFFENCE:
				fa.is_opener = true
		2: fa.tiring += 1
		3: fa.momentum_gain += 1
	return fa


func _apply_feint_direct(player_id: int, secondary: ActionData) -> void:
	if secondary == null:
		GameManager._clear_feint_flag(player_id)
		return
	var base_card: ActionData = GameManager.state.p1_action_queue if player_id == 1 else GameManager.state.p2_action_queue
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var opp_val: int = GameManager.state.p1_opportunity_stat if player_id == 1 else GameManager.state.p2_opportunity_stat
	var req: int = max(0, (base_card.cost + secondary.cost) - opp_val)
	var can_afford: bool = (character.current_sp >= req) or (character.can_pay_with_hp and (character.current_sp + character.current_hp) > req)
	if can_afford:
		var comb: ActionData = GameManager._combine_actions(base_card, secondary)
		if player_id == 1: GameManager.state.p1_action_queue = comb
		else: GameManager.state.p2_action_queue = comb
	GameManager._clear_feint_flag(player_id)


func _pick_turn_choice(player_id: int) -> Dictionary:
	var locked: ActionData = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
	if locked != null:
		return { "card": locked, "extra": {} }
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var c: Dictionary = _get_constraints(player_id)
	return _choose_ai_choice(character, player_id, c)


func _pick_feint_card(player_id: int) -> ActionData:
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var ch: Dictionary = _choose_ai_choice(character, player_id, _get_constraints(player_id))
	return null if ch["card"].is_struggle else ch["card"]


func _get_constraints(player_id: int) -> Dictionary:
	var attacker_id: int = GameManager.get_attacker()
	var is_combo: bool = (GameManager.state.current_combo_attacker != 0)
	var mom: int = GameManager.state.momentum
	var c: Dictionary = { "filter": null, "needs_opener": false, "max_cost": 99, "opening_stat": 0, "can_use_super": false, "opportunity_stat": 0 }
	if player_id == 1:
		c["max_cost"] = GameManager.state.p1_cost_limit
		c["opening_stat"] = GameManager.state.p1_opening_stat
		c["opportunity_stat"] = GameManager.state.p1_opportunity_stat
		if mom == GameManager.get_wall_momentum(1) and not _active_p1.has_used_super and not GameManager.is_super_disabled(1):
			c["can_use_super"] = true
		if GameManager.state.p1_must_opener: c["needs_opener"] = true
	else:
		c["max_cost"] = GameManager.state.p2_cost_limit
		c["opening_stat"] = GameManager.state.p2_opening_stat
		c["opportunity_stat"] = GameManager.state.p2_opportunity_stat
		if mom == GameManager.get_wall_momentum(2) and not _active_p2.has_used_super and not GameManager.is_super_disabled(2):
			c["can_use_super"] = true
		if GameManager.state.p2_must_opener: c["needs_opener"] = true
	if attacker_id != 0:
		c["filter"] = ActionData.Type.OFFENCE if attacker_id == player_id else ActionData.Type.DEFENCE
	if mom == 0 or (attacker_id == player_id and not is_combo):
		c["needs_opener"] = true
	return c


func _choose_ai_choice(character: CharacterData, my_id: int, c: Dictionary) -> Dictionary:
	var opponent: CharacterData = _active_p2 if my_id == 1 else _active_p1
	var candidates: Array[Dictionary] = []
	for card: ActionData in character.deck:
		if c["filter"] != null and card.type != c["filter"]: continue
		if card.counter_value > 0 and c["opening_stat"] < card.counter_value: continue
		if card.is_super and not c["can_use_super"]: continue
		var needs_open: bool = (c["needs_opener"] and card.type == ActionData.Type.OFFENCE and not card.is_opener)
		if not needs_open and card.cost <= c["max_cost"]:
			if GameManager.get_effective_repeat_count(character, card, c["opportunity_stat"], false, false) > 0:
				candidates.append({ "card": card, "sim": card, "extra": {} })
				if character.has_technique_dropdown and (card.cost + 1) <= c["max_cost"]:
					var tfc: int = max(0, (card.cost + 1) - c["opportunity_stat"])
					if character.current_sp >= tfc + 1:
						if opponent.current_sp > 0:
							var st: ActionData = card.duplicate(); st.cost += 1; st.tiring += 1
							candidates.append({ "card": card, "sim": st, "extra": { "technique": 2 } })
						if card.type == ActionData.Type.OFFENCE:
							var sm: ActionData = card.duplicate(); sm.cost += 1; sm.momentum_gain += 1
							candidates.append({ "card": card, "sim": sm, "extra": { "technique": 3 } })
		if needs_open and character.has_technique_dropdown and (card.cost + 1) <= c["max_cost"]:
			if character.current_sp >= max(0, (card.cost + 1) - c["opportunity_stat"]):
				var so: ActionData = card.duplicate(); so.cost += 1; so.is_opener = true
				candidates.append({ "card": card, "sim": so, "extra": { "technique": 1 } })

	if candidates.is_empty():
		var rt: ActionData.Type = c["filter"] if c["filter"] != null else ActionData.Type.OFFENCE
		return { "card": GameManager.get_struggle_action(rt), "extra": {} }
	if candidates.size() == 1:
		return { "card": candidates[0]["card"], "extra": candidates[0]["extra"] }

	GameManager.ai_difficulty = GameManager.Difficulty.HARD
	var brain: AIBehavior = character.ai_profile
	var attacker_id: int = GameManager.get_attacker()
	var scored: Array[Dictionary] = []
	for cand in candidates:
		var sc: ActionData = cand["sim"]
		var score: float = brain.score_action(sc, character, opponent, my_id)
		if sc.type == ActionData.Type.OFFENCE:
			if opponent.current_sp == 0 and sc.damage >= 2: score += 20.0
			if sc.guard_break and opponent.current_sp <= 1: score += 22.0
			if sc.damage == 0 and attacker_id == my_id: score -= 12.0
		else:
			if attacker_id != my_id and attacker_id != 0:
				if sc.is_parry and opponent.current_sp >= 1: score += 16.0
				if sc.reversal: score += 12.0
				if sc.block_value >= 1 and sc.cost == 0: score += 10.0
		score += randf_range(-2.0, 2.0)
		scored.append({ "card": cand["card"], "extra": cand["extra"], "score": score })

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	return { "card": scored[0]["card"], "extra": scored[0]["extra"] }
