class_name BotDecisionMaker
extends RefCounted

const CombatRulesScript = preload("res://Scripts/Battle/CombatRules.gd")

## Evaluates all legal actions (and Technical custom-technique variants) for [param character]
## and returns `{ "card": ActionData, "extra": Dictionary }` based on difficulty and AI profile.
## When [param feint_mode] is true, enforces combined `base_feint_cost + card.cost` affordability
## and returns `{ "card": null, "extra": {} }` (SKIP FEINT) instead of `Struggle`.
static func choose_action(
	character: CharacterData,
	opponent: CharacterData,
	my_id: int,
	type_filter: Variant,
	must_be_opener: bool,
	max_cost: int,
	my_opening: int,
	allow_super: bool,
	my_opportunity: int,
	feint_mode: bool = false,
	base_feint_cost: int = 0
) -> Dictionary:
	var constraints: Dictionary = {
		"filter": type_filter,
		"needs_opener": must_be_opener,
		"max_cost": max_cost,
		"opening_stat": my_opening,
		"can_use_super": allow_super,
		"opportunity_stat": my_opportunity,
	}

	var candidates: Array[Dictionary] = []

	for card: ActionData in character.deck:
		var base_eval: Dictionary = CombatRulesScript.evaluate_card_legality(
			character, card, constraints, false, 0, feint_mode, base_feint_cost
		)
		if bool(base_eval["valid"]):
			candidates.append({ "card": card, "sim": card, "extra": {} })

			if not feint_mode and character.has_technique_dropdown and (card.cost + 1) <= max_cost:
				var tech_first_cost: int = maxi(0, (card.cost + 1) - my_opportunity)
				if character.current_sp >= tech_first_cost + 1:
					if opponent.current_sp > 0:
						candidates.append({
							"card": card,
							"sim": CombatRulesScript.apply_technique(card, 2),
							"extra": { "technique": 2 }
						})
					if card.type == ActionData.Type.OFFENCE:
						candidates.append({
							"card": card,
							"sim": CombatRulesScript.apply_technique(card, 3),
							"extra": { "technique": 3 }
						})

		elif not feint_mode and str(base_eval["reason"]) == "needs_opener" and character.has_technique_dropdown:
			var opener_eval: Dictionary = CombatRulesScript.evaluate_card_legality(
				character, card, constraints, false, 1, false, 0
			)
			if bool(opener_eval["valid"]):
				candidates.append({
					"card": card,
					"sim": CombatRulesScript.apply_technique(card, 1),
					"extra": { "technique": 1 }
				})

	if candidates.is_empty():
		if feint_mode:
			return { "card": null, "extra": {} }
		var required_type: ActionData.Type = type_filter as ActionData.Type if type_filter != null else ActionData.Type.OFFENCE
		return { "card": GameManager.get_struggle_action(required_type), "extra": {} }

	if candidates.size() == 1:
		return { "card": candidates[0]["card"], "extra": candidates[0]["extra"] }

	var brain: AIBehavior = character.ai_profile
	if brain == null:
		brain = ClassFactory.pick_random_ai_profile()
		if brain == null:
			brain = preload("res://Scripts/Resources/AIBalanced.gd").new()
		character.ai_profile = brain

	if GameManager.ai_difficulty == GameManager.Difficulty.EASY and randf() < 0.80:
		var pick: Dictionary = candidates.pick_random()
		return { "card": pick["card"], "extra": pick["extra"] }

	var is_very_easy: bool = (GameManager.ai_difficulty == GameManager.Difficulty.VERY_EASY)
	var is_hard: bool = (GameManager.ai_difficulty == GameManager.Difficulty.HARD)
	var noise_range: float = 2.0
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: noise_range = 8.0
		GameManager.Difficulty.EASY: noise_range = 80.0
		GameManager.Difficulty.MEDIUM: noise_range = 45.0
		GameManager.Difficulty.HARD: noise_range = 2.0

	var attacker_id: int = GameManager.get_attacker()
	var scored: Array[Dictionary] = []

	for cand: Dictionary in candidates:
		var sim_card: ActionData = cand["sim"] as ActionData
		var score: float = brain.score_action(sim_card, character, opponent, my_id)
		if GameManager.ai_difficulty == GameManager.Difficulty.EASY and score >= brain.kill_shot_bonus * 0.5:
			score -= brain.kill_shot_bonus
		if is_hard:
			if sim_card.type == ActionData.Type.OFFENCE:
				if opponent.current_sp == 0 and sim_card.damage >= 2:
					score += 20.0
				if sim_card.guard_break and opponent.current_sp <= 1:
					score += 22.0
				if sim_card.damage == 0 and attacker_id == my_id:
					score -= 12.0
			else:
				if attacker_id != my_id and attacker_id != 0:
					if sim_card.is_parry and opponent.current_sp >= 1:
						score += 16.0
					if sim_card.reversal:
						score += 12.0
					if sim_card.block_value >= 1 and sim_card.cost == 0:
						score += 10.0
		score += randf_range(-noise_range, noise_range)
		scored.append({ "card": cand["card"], "extra": cand["extra"], "score": score })

	if is_very_easy:
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
		return { "card": scored[0]["card"], "extra": scored[0]["extra"] }

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	if GameManager.ai_difficulty == GameManager.Difficulty.MEDIUM and scored.size() > 1 and randf() < 0.40:
		var sub_idx: int = mini(scored.size() - 1, randi_range(1, 2))
		return { "card": scored[sub_idx]["card"], "extra": scored[sub_idx]["extra"] }

	return { "card": scored[0]["card"], "extra": scored[0]["extra"] }
