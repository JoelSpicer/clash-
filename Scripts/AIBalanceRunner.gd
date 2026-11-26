extends Node

const MAX_TURNS: int = 80
const REPORT_OUTPUT_PATH: String = "res://ai_balance_report.json"

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
var _match_winner: int = 0
var _active_p1: CharacterData
var _active_p2: CharacterData


func _ready() -> void:
	seed(424242)

	# Ensure clean neutral environment (Dojo, 8 slots) & no leftover arcade modifiers
	RunManager.is_arcade_mode = false
	RunManager.player_run_data = null
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""
	GameManager.apply_environment_rules("Dojo")

	for pdef in PROFILE_DEFS:
		_profiles[pdef["name"]] = load(pdef["path"])

	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)

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

	var file: FileAccess = FileAccess.open(REPORT_OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("AI_BALANCE_DONE elapsed_ms=", elapsed_ms, " path=", REPORT_OUTPUT_PATH)
	else:
		printerr("AI_BALANCE_ERROR failed to write report to ", REPORT_OUTPUT_PATH)

	get_tree().quit()


func _on_game_over(winner_id: int) -> void:
	if _match_winner == 0:
		_match_winner = winner_id


# ==============================================================================
# SUITES
# ==============================================================================

func _run_mirrored_suite(games_per_pair_per_class: int, difficulty: GameManager.Difficulty) -> Dictionary:
	var matrix: Dictionary = {}
	var profile_stats: Dictionary = {}
	var class_stats: Dictionary = {}
	var p1_wins_total: int = 0
	var p2_wins_total: int = 0
	var stalls_total: int = 0
	var total_matches: int = 0
	var total_turns: int = 0

	for pdef in PROFILE_DEFS:
		var pname: String = pdef["name"]
		matrix[pname] = {}
		profile_stats[pname] = _new_bucket()
		for odef in PROFILE_DEFS:
			matrix[pname][odef["name"]] = { "wins": 0, "losses": 0, "stalls": 0 }

	for cdef in CLASS_DEFS:
		class_stats[cdef["name"]] = { "matches": 0, "turns": 0, "stalls": 0 }

	for p1_def in PROFILE_DEFS:
		var p1_name: String = p1_def["name"]
		for p2_def in PROFILE_DEFS:
			var p2_name: String = p2_def["name"]
			for cdef in CLASS_DEFS:
				var cname: String = cdef["name"]
				var ctype: CharacterData.ClassType = cdef["type"]
				for _g in range(games_per_pair_per_class):
					var p1: CharacterData = ClassFactory.create_character(ctype, "P1")
					var p2: CharacterData = ClassFactory.create_character(ctype, "P2")
					p1.ai_profile = _profiles[p1_name]
					p2.ai_profile = _profiles[p2_name]

					var res: Dictionary = _simulate_match(p1, p2, difficulty, difficulty)
					total_matches += 1
					total_turns += res["turns"]
					class_stats[cname]["matches"] += 1
					class_stats[cname]["turns"] += res["turns"]

					_record_telemetry(profile_stats[p1_name], res["p1_tel"], res["winner"] == 1, res["stalled"], res["turns"])
					_record_telemetry(profile_stats[p2_name], res["p2_tel"], res["winner"] == 2, res["stalled"], res["turns"])

					if res["stalled"]:
						stalls_total += 1
						class_stats[cname]["stalls"] += 1
						matrix[p1_name][p2_name]["stalls"] += 1
					elif res["winner"] == 1:
						p1_wins_total += 1
						matrix[p1_name][p2_name]["wins"] += 1
					else:
						p2_wins_total += 1
						matrix[p1_name][p2_name]["losses"] += 1

	return {
		"total_matches": total_matches,
		"avg_turns": float(total_turns) / float(max(1, total_matches)),
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

	for pdef in PROFILE_DEFS:
		var pname: String = pdef["name"]
		matrix[pname] = {}
		profile_stats[pname] = _new_bucket()
		for odef in PROFILE_DEFS:
			matrix[pname][odef["name"]] = { "wins": 0, "losses": 0, "stalls": 0 }

	for p1_def in PROFILE_DEFS:
		var p1_name: String = p1_def["name"]
		for p2_def in PROFILE_DEFS:
			var p2_name: String = p2_def["name"]
			for _g in range(games_per_pair):
				var base_bot: CharacterData = ClassFactory.create_random_enemy(level, difficulty)
				# Mirror the exact drafted deck & stats so only AI profile differs!
				var p1: CharacterData = base_bot.duplicate(true)
				var p2: CharacterData = base_bot.duplicate(true)
				p1.character_name = "P1"
				p2.character_name = "P2"
				p1.ai_profile = _profiles[p1_name]
				p2.ai_profile = _profiles[p2_name]

				var res: Dictionary = _simulate_match(p1, p2, difficulty, difficulty)
				total_matches += 1
				total_turns += res["turns"]

				_record_telemetry(profile_stats[p1_name], res["p1_tel"], res["winner"] == 1, res["stalled"], res["turns"])
				_record_telemetry(profile_stats[p2_name], res["p2_tel"], res["winner"] == 2, res["stalled"], res["turns"])

				if res["stalled"]:
					stalls_total += 1
					matrix[p1_name][p2_name]["stalls"] += 1
				elif res["winner"] == 1:
					matrix[p1_name][p2_name]["wins"] += 1
				else:
					matrix[p1_name][p2_name]["losses"] += 1

	return {
		"level": level,
		"total_matches": total_matches,
		"avg_turns": float(total_turns) / float(max(1, total_matches)),
		"stalls": stalls_total,
		"matrix_p1_vs_p2": matrix,
		"profiles": _finalize_buckets(profile_stats),
	}


func _run_class_synergy_suite(games_per_combo: int, difficulty: GameManager.Difficulty) -> Dictionary:
	var class_winrates: Dictionary = {}
	var synergy: Dictionary = {}
	var total_matches: int = 0
	var stalls_total: int = 0

	for cdef in CLASS_DEFS:
		var cname: String = cdef["name"]
		class_winrates[cname] = { "wins": 0, "games": 0 }
		synergy[cname] = {}
		for pdef in PROFILE_DEFS:
			synergy[cname][pdef["name"]] = { "wins": 0, "games": 0, "stalls": 0 }

	for cdef in CLASS_DEFS:
		var cname: String = cdef["name"]
		var ctype: CharacterData.ClassType = cdef["type"]
		for pdef in PROFILE_DEFS:
			var pname: String = pdef["name"]
			for g in range(games_per_combo):
				var opp_cdef: Dictionary = CLASS_DEFS.pick_random()
				var opp_pdef: Dictionary = PROFILE_DEFS.pick_random()

				var subject: CharacterData = ClassFactory.create_character(ctype, "Subject")
				subject.ai_profile = _profiles[pname]
				var opp: CharacterData = ClassFactory.create_character(opp_cdef["type"], "Opp")
				opp.ai_profile = _profiles[opp_pdef["name"]]

				# Alternate P1/P2 seat to eliminate seat bias
				var subject_is_p1: bool = (g % 2 == 0)
				var res: Dictionary = _simulate_match(subject, opp, difficulty, difficulty) if subject_is_p1 else _simulate_match(opp, subject, difficulty, difficulty)
				total_matches += 1

				var subject_won: bool = (res["winner"] == 1) if subject_is_p1 else (res["winner"] == 2)
				synergy[cname][pname]["games"] += 1
				class_winrates[cname]["games"] += 1
				if res["stalled"]:
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
	for pair in pairs:
		var a_wins: int = 0
		var b_wins: int = 0
		var stalls: int = 0
		for g in range(games_per_pair):
			var ctype: CharacterData.ClassType = CLASS_DEFS[g % CLASS_DEFS.size()]["type"]
			var p1: CharacterData = ClassFactory.create_character(ctype, "A")
			var p2: CharacterData = ClassFactory.create_character(ctype, "B")
			p1.ai_profile = _profiles["Balanced"]
			p2.ai_profile = _profiles["Balanced"]
			var a_is_p1: bool = (g % 2 == 0)
			var res: Dictionary = _simulate_match(p1, p2, pair["a"], pair["b"]) if a_is_p1 else _simulate_match(p2, p1, pair["b"], pair["a"])
			if res["stalled"]:
				stalls += 1
			elif (res["winner"] == 1 and a_is_p1) or (res["winner"] == 2 and not a_is_p1):
				a_wins += 1
			else:
				b_wins += 1
		out[pair["label"]] = { "a_wins": a_wins, "b_wins": b_wins, "stalls": stalls }
	return out


# ==============================================================================
# CORE MATCH SIMULATION (SYNCHRONOUS AGAINST REAL GameManager)
# ==============================================================================

func _simulate_match(p1: CharacterData, p2: CharacterData, p1_diff: GameManager.Difficulty, p2_diff: GameManager.Difficulty) -> Dictionary:
	_active_p1 = p1
	_active_p2 = p2
	_match_winner = 0

	GameManager.start_combat(p1, p2)
	GameManager.current_state = GameManager.State.SELECTION

	var p1_tel: Dictionary = { "turns": 0, "struggles": 0, "offence": 0, "defence": 0, "total_cost": 0, "feints": 0, "cards": {} }
	var p2_tel: Dictionary = { "turns": 0, "struggles": 0, "offence": 0, "defence": 0, "total_cost": 0, "feints": 0, "cards": {} }

	var turns: int = 0
	while _match_winner == 0 and turns < MAX_TURNS:
		turns += 1

		var p1_card: ActionData = _pick_turn_card(1, p1_diff)
		var p2_card: ActionData = _pick_turn_card(2, p2_diff)

		_track_card(p1_tel, p1_card)
		_track_card(p2_tel, p2_card)

		GameManager.state.p1_action_queue = p1_card
		GameManager.state.p2_action_queue = p2_card

		# Handle Feint secondary selection identically to live combat
		GameManager.state.p1_pending_feint = p1_card.feint
		GameManager.state.p2_pending_feint = p2_card.feint

		if GameManager.state.p1_pending_feint:
			p1_tel["feints"] += 1
			var sec1: ActionData = _pick_feint_card(1, p1_diff)
			GameManager.current_state = GameManager.State.FEINT_CHECK
			_apply_feint_direct(1, sec1)

		if GameManager.state.p2_pending_feint:
			p2_tel["feints"] += 1
			var sec2: ActionData = _pick_feint_card(2, p2_diff)
			GameManager.current_state = GameManager.State.FEINT_CHECK
			_apply_feint_direct(2, sec2)

		GameManager.current_state = GameManager.State.RESOLUTION
		GameManager.resolve_clash()

	var stalled: bool = (_match_winner == 0)
	return {
		"winner": _match_winner,
		"stalled": stalled,
		"turns": turns,
		"p1_hp_end": p1.current_hp,
		"p2_hp_end": p2.current_hp,
		"p1_tel": p1_tel,
		"p2_tel": p2_tel,
	}


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
	var total_reps: int = max(1, combined_card.repeat_count)
	var total_required: int = effective_total * total_reps
	var can_afford: bool = (character.current_sp >= total_required)
	if not can_afford and character.class_type == CharacterData.ClassType.HEAVY and (character.current_sp + character.current_hp) > total_required:
		can_afford = true
	if can_afford:
		if player_id == 1:
			GameManager.state.p1_action_queue = combined_card
		else:
			GameManager.state.p2_action_queue = combined_card
	GameManager._clear_feint_flag(player_id)


func _pick_turn_card(player_id: int, difficulty: GameManager.Difficulty) -> ActionData:
	var locked: ActionData = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
	if locked != null:
		return locked
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var c: Dictionary = _get_player_constraints(player_id)
	return _choose_ai_card(character, player_id, difficulty, c["filter"], c["needs_opener"], c["max_cost"], c["opening_stat"], c["can_use_super"], c["opportunity_stat"])


func _pick_feint_card(player_id: int, difficulty: GameManager.Difficulty) -> ActionData:
	var character: CharacterData = _active_p1 if player_id == 1 else _active_p2
	var c: Dictionary = _get_player_constraints(player_id)
	var chosen: ActionData = _choose_ai_card(character, player_id, difficulty, c["filter"], c["needs_opener"], c["max_cost"], c["opening_stat"], c["can_use_super"], c["opportunity_stat"])
	if chosen.is_struggle:
		return null
	return chosen


func _get_player_constraints(player_id: int) -> Dictionary:
	var attacker_id: int = GameManager.get_attacker()
	var is_combo: bool = (GameManager.state.current_combo_attacker != 0)
	var mom: int = GameManager.state.momentum

	var c: Dictionary = {
		"filter": null,
		"needs_opener": false,
		"max_cost": 99,
		"opening_stat": 0,
		"can_use_super": false,
		"opportunity_stat": 0,
	}

	if player_id == 1:
		c["max_cost"] = GameManager.state.p1_cost_limit
		c["opening_stat"] = GameManager.state.p1_opening_stat
		c["opportunity_stat"] = GameManager.state.p1_opportunity_stat
		if mom == GameManager.get_wall_momentum(1) and not _active_p1.has_used_super:
			c["can_use_super"] = true
		if GameManager.state.p1_must_opener:
			c["needs_opener"] = true
	else:
		c["max_cost"] = GameManager.state.p2_cost_limit
		c["opening_stat"] = GameManager.state.p2_opening_stat
		c["opportunity_stat"] = GameManager.state.p2_opportunity_stat
		if mom == GameManager.get_wall_momentum(2) and not _active_p2.has_used_super:
			c["can_use_super"] = true
		if GameManager.state.p2_must_opener:
			c["needs_opener"] = true

	if attacker_id != 0:
		c["filter"] = ActionData.Type.OFFENCE if attacker_id == player_id else ActionData.Type.DEFENCE

	if mom == 0:
		c["needs_opener"] = true
	elif attacker_id == player_id and not is_combo:
		c["needs_opener"] = true

	return c


func _choose_ai_card(character: CharacterData, my_id: int, difficulty: GameManager.Difficulty, type_filter: Variant, must_be_opener: bool, max_cost: int, my_opening: int, allow_super: bool, my_opportunity: int) -> ActionData:
	var valid_options: Array[ActionData] = []

	for card: ActionData in character.deck:
		if type_filter != null and card.type != type_filter: continue
		if must_be_opener and card.type == ActionData.Type.OFFENCE and not card.is_opener: continue
		if card.cost > max_cost: continue
		if card.counter_value > 0 and my_opening < card.counter_value: continue
		if card.is_super and not allow_super: continue

		var effective_single_cost: int = max(0, card.cost - my_opportunity)
		var total_reps: int = max(1, card.repeat_count)
		var total_effective_cost: int = effective_single_cost * total_reps

		var can_pay: bool = (total_effective_cost <= character.current_sp)
		if character.can_pay_with_hp and (character.current_sp + character.current_hp) > total_effective_cost:
			can_pay = true

		if can_pay:
			valid_options.append(card)

	# Struggle is purely a last-resort backup when no legal card in the deck can be played
	if valid_options.is_empty():
		var required_type: ActionData.Type = type_filter if type_filter != null else ActionData.Type.OFFENCE
		return GameManager.get_struggle_action(required_type)

	if valid_options.size() == 1:
		return valid_options[0]

	# Set GameManager.ai_difficulty for this evaluation (AIBehavior reads it for VERY_EASY anti-rep)
	GameManager.ai_difficulty = difficulty
	if difficulty == GameManager.Difficulty.EASY and randf() < 0.80:
		return valid_options.pick_random()

	var is_very_easy: bool = (difficulty == GameManager.Difficulty.VERY_EASY)
	var is_hard: bool = (difficulty == GameManager.Difficulty.HARD)
	var opponent: CharacterData = _active_p2 if my_id == 1 else _active_p1
	var brain: AIBehavior = character.ai_profile

	var noise_range: float = 2.0
	match difficulty:
		GameManager.Difficulty.VERY_EASY: noise_range = 8.0
		GameManager.Difficulty.EASY: noise_range = 80.0
		GameManager.Difficulty.MEDIUM: noise_range = 45.0
		GameManager.Difficulty.HARD: noise_range = 2.0

	var attacker_id: int = GameManager.get_attacker()

	var scored: Array[Dictionary] = []
	for card: ActionData in valid_options:
		var score: float = brain.score_action(card, character, opponent, my_id)
		if difficulty == GameManager.Difficulty.EASY and score >= brain.kill_shot_bonus * 0.5:
			score -= brain.kill_shot_bonus
		if is_hard:
			if card.type == ActionData.Type.OFFENCE:
				if opponent.current_sp == 0 and card.damage >= 2:
					score += 20.0
				if card.guard_break and opponent.current_sp <= 1:
					score += 22.0
				if card.damage == 0 and attacker_id == my_id:
					score -= 12.0
			else:
				if attacker_id != my_id and attacker_id != 0:
					if card.is_parry and opponent.current_sp >= 1:
						score += 16.0
					if card.reversal:
						score += 12.0
					if card.block_value >= 1 and card.cost == 0:
						score += 10.0
		score += randf_range(-noise_range, noise_range)
		scored.append({ "card": card, "score": score })

	if is_very_easy:
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
		return scored[0]["card"]

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	if difficulty == GameManager.Difficulty.MEDIUM and scored.size() > 1 and randf() < 0.40:
		var sub_idx: int = min(scored.size() - 1, randi_range(1, 2))
		return scored[sub_idx]["card"]

	return scored[0]["card"]


# ==============================================================================
# TELEMETRY HELPERS
# ==============================================================================

func _track_card(tel: Dictionary, card: ActionData) -> void:
	tel["turns"] += 1
	tel["total_cost"] += card.cost
	if card.is_struggle:
		tel["struggles"] += 1
	if card.type == ActionData.Type.OFFENCE:
		tel["offence"] += 1
	else:
		tel["defence"] += 1
	var cname: String = card.display_name
	tel["cards"][cname] = tel["cards"].get(cname, 0) + 1


func _new_bucket() -> Dictionary:
	return {
		"games": 0,
		"wins": 0,
		"stalls": 0,
		"turns": 0,
		"struggles": 0,
		"offence": 0,
		"defence": 0,
		"total_cost": 0,
		"feints": 0,
		"cards": {},
	}


func _record_telemetry(bucket: Dictionary, tel: Dictionary, won: bool, stalled: bool, match_turns: int) -> void:
	bucket["games"] += 1
	if won:
		bucket["wins"] += 1
	if stalled:
		bucket["stalls"] += 1
	bucket["turns"] += match_turns
	bucket["struggles"] += tel["struggles"]
	bucket["offence"] += tel["offence"]
	bucket["defence"] += tel["defence"]
	bucket["total_cost"] += tel["total_cost"]
	bucket["feints"] += tel["feints"]
	for cname: String in tel["cards"]:
		bucket["cards"][cname] = bucket["cards"].get(cname, 0) + tel["cards"][cname]


func _finalize_buckets(stats: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for pname: String in stats:
		var b: Dictionary = stats[pname]
		var total_actions: int = max(1, b["offence"] + b["defence"])
		var games: int = max(1, b["games"])

		# Top 5 most-played cards
		var card_pairs: Array[Dictionary] = []
		for cname: String in b["cards"]:
			card_pairs.append({ "name": cname, "count": b["cards"][cname] })
		card_pairs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["count"] > y["count"])
		var top_cards: Array[Dictionary] = []
		for i in range(min(5, card_pairs.size())):
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
