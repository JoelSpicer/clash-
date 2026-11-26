extends AIBehavior
class_name AIAggressive


func _init() -> void:
	w_dmg = 1.35
	w_def = 0.65
	w_tech = 0.9
	w_cost = 0.75
	panic_hp_threshold = 2


## Scores an action using aggressive damage-first weighting plus MatchState context.
func score_action(card: ActionData, me: CharacterData, opp: CharacterData, my_id: int) -> float:
	if card.is_struggle:
		return -500.0

	var score: float = 0.0
	var match_state: GameManager.MatchState = GameManager.state
	var attacker_id: int = GameManager.get_attacker()

	var hits: int = _get_effective_hits(card, me, my_id)
	var raw_total_dmg: int = card.damage * hits
	var exp_dmg: float = _get_expected_damage(card, hits)
	var total_mom: int = card.momentum_gain * hits
	var total_tiring: int = card.tiring * hits
	var total_cost: int = _get_effective_total_cost(card, my_id, hits)

	var my_last_action: String = match_state.p1_last_action_name if my_id == 1 else match_state.p2_last_action_name
	var opp_last_cost: int = match_state.p2_last_cost if my_id == 1 else match_state.p1_last_cost

	# 1. Anti-repetition (inverted when Very Easy picks lowest scores)
	if card.display_name == my_last_action:
		if GameManager.ai_difficulty == GameManager.Difficulty.VERY_EASY:
			score += repetition_penalty
		else:
			score -= repetition_penalty

	# 2. Kill shot priority (accounts for multi-hit Repeat lethal)
	if raw_total_dmg >= opp.current_hp and opp.current_hp > 0:
		score += kill_shot_bonus * (0.75 if (hits > 1 and card.damage == 1 and not card.guard_break) else 1.0)

	# 3. Strict 0-SP recovery priority (use real SP recovery options before ever hitting Struggle)
	var eff_recover: int = (card.recover_value + (1 if card.type == ActionData.Type.DEFENCE else 0)) * hits
	if me.current_sp == 0 and eff_recover > 0:
		score += float(eff_recover) * 32.0

	# 4. Offensive & defensive tactical adjustments
	if card.type == ActionData.Type.OFFENCE:
		var opp_opening: int = match_state.p2_opening_stat if my_id == 1 else match_state.p1_opening_stat
		if opp_opening > 0 and card.counter_value > 0 and card.counter_value <= opp_opening:
			score += 55.0 * w_tech

		var opp_sp_ratio: float = float(opp.current_sp) / float(max(1, opp.max_sp))
		if opp_last_cost >= 2 or opp_sp_ratio < 0.35:
			score += exp_dmg * 4.5 * w_dmg

		if raw_total_dmg == 0 and attacker_id == my_id:
			score -= 10.0
		if raw_total_dmg >= 2:
			score += 12.0 * w_dmg
		if card.guard_break:
			score += 28.0 * w_tech
		if card.feint:
			score += 18.0 * w_tech
	else:
		if attacker_id != my_id and attacker_id != 0:
			if card.is_parry:
				score += 14.0 * w_def
			if opp_last_cost >= 2:
				if card.dodge_value > 0:
					score += 20.0 * w_def
				if card.block_value >= 4:
					score += 15.0 * w_def
		if me.current_hp < panic_hp_threshold:
			score += (float(card.block_value) * 8.0 * w_def) + (float(card.heal_value * hits) * 14.0 * w_def) + (14.0 * w_def)

	# 5. Base stat & stamina cost trade-off (Repeat-aware)
	score += (exp_dmg * 8.0 * w_dmg) + (float(card.block_value) * 5.0 * w_def) + (float(card.heal_value * hits) * 5.0 * w_def)
	score += float(total_mom) * 4.0 * w_dmg
	if me.combo_sp_recovery_rate > 0 and hits >= 2 and card.type == ActionData.Type.OFFENCE:
		score += float(hits) * 4.0
	if total_tiring > 0 and opp.current_sp > 0:
		score += float(total_tiring) * 5.0 * w_tech
	if card.create_opening > 0:
		score += float(card.create_opening) * 4.0 * w_tech

	if total_cost > 0:
		var my_sp_ratio: float = float(me.current_sp) / float(max(1, me.max_sp))
		var scarcity: float = 1.0 if my_sp_ratio > 0.35 else 1.5
		score -= float(total_cost) * (4.0 * w_cost * scarcity)

	return score
