class_name CombatSimulator
extends RefCounted
## Synchronous headless match simulator shared by all balance runners.
## Drives the real GameManager, CombatRules, and BotDecisionMaker with zero scene/UI overhead.

const MAX_TURNS: int = 80
const CombatRulesScript = preload("res://Scripts/Battle/CombatRules.gd")
const BotDecisionMakerScript = preload("res://Scripts/Battle/BotDecisionMaker.gd")

var _match_winner: int = 0
var _wall_crushes_p1: int = 0
var _wall_crushes_p2: int = 0


func connect_signals() -> void:
	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)
	if not GameManager.wall_crush_occurred.is_connected(_on_wall_crush):
		GameManager.wall_crush_occurred.connect(_on_wall_crush)


func dispose() -> void:
	if GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.disconnect(_on_game_over)
	if GameManager.wall_crush_occurred.is_connected(_on_wall_crush):
		GameManager.wall_crush_occurred.disconnect(_on_wall_crush)


static func build_fighter(
	ctype: CharacterData.ClassType,
	level: int,
	full_library: bool = false,
	label: String = "Fighter"
) -> CharacterData:
	if level <= 1:
		var c: CharacterData = ClassFactory.create_character(ctype, label, full_library)
		c.ai_profile = ClassFactory.pick_random_ai_profile()
		return c
	return ClassFactory.create_leveled_fighter(ctype, level, full_library, label)


func simulate_match(
	p1: CharacterData,
	p2: CharacterData,
	p1_diff: GameManager.Difficulty = GameManager.Difficulty.HARD,
	p2_diff: GameManager.Difficulty = GameManager.Difficulty.HARD
) -> Dictionary:
	connect_signals()
	_match_winner = 0
	_wall_crushes_p1 = 0
	_wall_crushes_p2 = 0

	GameManager.start_combat(p1, p2)
	GameManager.current_state = GameManager.State.SELECTION

	var p1_tel: Dictionary = {
		"turns": 0, "struggles": 0, "offence": 0, "defence": 0,
		"total_cost": 0, "supers": 0, "tech_uses": 0, "feints": 0, "cards": {},
	}
	var p2_tel: Dictionary = {
		"turns": 0, "struggles": 0, "offence": 0, "defence": 0,
		"total_cost": 0, "supers": 0, "tech_uses": 0, "feints": 0, "cards": {},
	}

	var turns: int = 0
	while _match_winner == 0 and turns < MAX_TURNS:
		turns += 1
		var p1_choice: Dictionary = _pick_turn_choice(1, p1, p2, p1_diff)
		var p2_choice: Dictionary = _pick_turn_choice(2, p1, p2, p2_diff)

		var p1_extra: Dictionary = p1_choice["extra"] as Dictionary
		var p2_extra: Dictionary = p2_choice["extra"] as Dictionary
		var p1_tech: int = int(p1_extra.get("technique", 0))
		var p2_tech: int = int(p2_extra.get("technique", 0))

		var p1_card: ActionData = CombatRulesScript.apply_technique(p1_choice["card"] as ActionData, p1_tech)
		var p2_card: ActionData = CombatRulesScript.apply_technique(p2_choice["card"] as ActionData, p2_tech)

		if p1_tech > 0:
			p1_tel["tech_uses"] = int(p1_tel["tech_uses"]) + 1
		if p2_tech > 0:
			p2_tel["tech_uses"] = int(p2_tel["tech_uses"]) + 1

		_track_card(p1_tel, p1_card)
		_track_card(p2_tel, p2_card)

		GameManager.state.p1_action_queue = p1_card
		GameManager.state.p2_action_queue = p2_card
		GameManager.state.p1_rage_active = bool(p1_extra.get("rage", false))
		GameManager.state.p2_rage_active = bool(p2_extra.get("rage", false))

		GameManager.state.p1_pending_feint = p1_card.feint
		GameManager.state.p2_pending_feint = p2_card.feint

		if GameManager.state.p1_pending_feint:
			p1_tel["feints"] = int(p1_tel["feints"]) + 1
			GameManager.current_state = GameManager.State.FEINT_CHECK
			_apply_feint_direct(1, _pick_feint_card(1, p1, p2, p1_card.cost, p1_diff), p1, p2)

		if GameManager.state.p2_pending_feint:
			p2_tel["feints"] = int(p2_tel["feints"]) + 1
			GameManager.current_state = GameManager.State.FEINT_CHECK
			_apply_feint_direct(2, _pick_feint_card(2, p1, p2, p2_card.cost, p2_diff), p1, p2)

		GameManager.current_state = GameManager.State.RESOLUTION
		GameManager.resolve_clash()

	return {
		"winner": _match_winner,
		"stalled": _match_winner == 0,
		"turns": turns,
		"p1_hp_end": p1.current_hp,
		"p2_hp_end": p2.current_hp,
		"wc_p1": _wall_crushes_p1,
		"wc_p2": _wall_crushes_p2,
		"supers_p1": int(p1_tel["supers"]),
		"supers_p2": int(p2_tel["supers"]),
		"p1_tel": p1_tel,
		"p2_tel": p2_tel,
	}


func _on_game_over(winner_id: int) -> void:
	if _match_winner == 0:
		_match_winner = winner_id


func _on_wall_crush(player_id: int, _dmg: int) -> void:
	if player_id == 1:
		_wall_crushes_p1 += 1
	else:
		_wall_crushes_p2 += 1


func _pick_turn_choice(
	player_id: int,
	p1: CharacterData,
	p2: CharacterData,
	difficulty: GameManager.Difficulty
) -> Dictionary:
	var locked: ActionData = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
	if locked != null:
		return { "card": locked, "extra": {} }

	var character: CharacterData = p1 if player_id == 1 else p2
	var opponent: CharacterData = p2 if player_id == 1 else p1
	var c: Dictionary = CombatRulesScript.get_player_constraints(player_id)
	GameManager.ai_difficulty = difficulty
	return BotDecisionMakerScript.choose_action(
		character, opponent, player_id,
		c["filter"], bool(c["needs_opener"]), int(c["max_cost"]),
		int(c["opening_stat"]), bool(c["can_use_super"]), int(c["opportunity_stat"]),
		false, 0
	)


func _pick_feint_card(
	player_id: int,
	p1: CharacterData,
	p2: CharacterData,
	base_cost: int,
	difficulty: GameManager.Difficulty
) -> ActionData:
	var character: CharacterData = p1 if player_id == 1 else p2
	var opponent: CharacterData = p2 if player_id == 1 else p1
	var c: Dictionary = CombatRulesScript.get_player_constraints(player_id)
	GameManager.ai_difficulty = difficulty
	var chosen: Dictionary = BotDecisionMakerScript.choose_action(
		character, opponent, player_id,
		c["filter"], bool(c["needs_opener"]), int(c["max_cost"]),
		int(c["opening_stat"]), bool(c["can_use_super"]), int(c["opportunity_stat"]),
		true, base_cost
	)
	var card: ActionData = chosen.get("card", null) as ActionData
	if card == null or card.is_struggle:
		return null
	return card


func _apply_feint_direct(player_id: int, secondary: ActionData, p1: CharacterData, p2: CharacterData) -> void:
	if secondary == null:
		GameManager._clear_feint_flag(player_id)
		return
	var base_card: ActionData = GameManager.state.p1_action_queue if player_id == 1 else GameManager.state.p2_action_queue
	var character: CharacterData = p1 if player_id == 1 else p2
	var opp_val: int = GameManager.state.p1_opportunity_stat if player_id == 1 else GameManager.state.p2_opportunity_stat
	var total_required: int = maxi(0, (base_card.cost + secondary.cost) - opp_val)
	var can_afford: bool = (character.current_sp >= total_required) or (
		character.can_pay_with_hp and (character.current_sp + character.current_hp) > total_required
	)
	if can_afford:
		var combined: ActionData = GameManager._combine_actions(base_card, secondary)
		if player_id == 1:
			GameManager.state.p1_action_queue = combined
		else:
			GameManager.state.p2_action_queue = combined
	GameManager._clear_feint_flag(player_id)


func _track_card(tel: Dictionary, card: ActionData) -> void:
	tel["turns"] = int(tel["turns"]) + 1
	tel["total_cost"] = int(tel["total_cost"]) + card.cost
	if card.is_struggle:
		tel["struggles"] = int(tel["struggles"]) + 1
	if card.is_super:
		tel["supers"] = int(tel["supers"]) + 1
	if card.type == ActionData.Type.OFFENCE:
		tel["offence"] = int(tel["offence"]) + 1
	else:
		tel["defence"] = int(tel["defence"]) + 1
	var cname: String = card.display_name
	var cards_dict: Dictionary = tel["cards"] as Dictionary
	cards_dict[cname] = int(cards_dict.get(cname, 0)) + 1
