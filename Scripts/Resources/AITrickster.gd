extends AIBehavior
class_name AITrickster


func _init() -> void:
	w_dmg = 1.15
	w_def = 0.85
	w_tech = 1.3
	w_cost = 0.8
	panic_hp_threshold = 3


## Scores an action prioritizing openings, counters, feints, SP drain, and cashing in setups for damage.
func score_action(card: ActionData, me: CharacterData, opp: CharacterData, my_id: int) -> float:
	if card.is_struggle:
		return -500.0

	var score: float = 0.0
	var match_state: GameManager.MatchState = GameManager.state
	var attacker_id: int = GameManager.get_attacker()

	var my_last_action: String = match_state.p1_last_action_name if my_id == 1 else match_state.p2_last_action_name
	var opp_last_cost: int = match_state.p2_last_cost if my_id == 1 else match_state.p1_last_cost
	var opp_opening: int = match_state.p2_opening_stat if my_id == 1 else match_state.p1_opening_stat
	var my_opp_stat: int = match_state.p1_opportunity_stat if my_id == 1 else match_state.p2_opportunity_stat

	# 1. Anti-repetition (inverted when Very Easy picks lowest scores)
	if card.display_name == my_last_action:
		if GameManager.ai_difficulty == GameManager.Difficulty.VERY_EASY:
			score += repetition_penalty
		else:
			score -= repetition_penalty

	# 2. Kill shot priority
	if card.damage >= opp.current_hp and opp.current_hp > 0:
		score += kill_shot_bonus

	# 3. Strict 0-SP recovery priority (use real SP recovery options before ever hitting Struggle)
	var eff_recover: int = card.recover_value + (1 if card.type == ActionData.Type.DEFENCE else 0)
	if me.current_sp == 0 and eff_recover > 0:
		score += float(eff_recover) * 35.0

	# 4. Trickster tactical scoring — set up openings/opportunity, then CASH THEM IN for damage!
	if opp_opening > 0:
		if card.counter_value > 0 and card.counter_value <= opp_opening:
			score += 65.0 * w_tech
		if card.damage > 0:
			score += float(card.damage) * 6.0 * w_dmg
	else:
		if card.create_opening > 0 and opp.current_hp > 3:
			score += float(card.create_opening) * 5.5 * w_tech

	if my_opp_stat > 0 and card.damage > 0:
		score += float(card.damage) * 5.0 * w_dmg
	elif card.opportunity > 0 and opp.current_hp > 3:
		score += float(card.opportunity) * 4.5 * w_tech

	if card.feint:
		score += 20.0 * w_tech
	if card.guard_break:
		score += 26.0 * w_tech
	if card.tiring > 0 and opp.current_sp > 0:
		score += float(card.tiring) * 6.5 * w_tech

	if card.type == ActionData.Type.DEFENCE:
		if attacker_id != my_id and attacker_id != 0:
			if opp_last_cost >= 2 and card.dodge_value > 0:
				score += 22.0 * w_def
			if card.is_parry:
				score += 18.0 * w_tech
		if card.reversal:
			score += 18.0 * w_tech
	else:
		if card.damage == 0 and attacker_id == my_id:
			score -= 10.0
		var opp_sp_ratio: float = float(opp.current_sp) / float(max(1, opp.max_sp))
		if opp_last_cost >= 2 or opp_sp_ratio < 0.35:
			score += float(card.damage) * 5.0 * w_dmg

	# 5. Survival instinct (only when hurt)
	if me.current_hp < panic_hp_threshold and me.current_hp < me.max_hp:
		score += (float(card.block_value) * 8.0 * w_def) + (float(card.heal_value) * 14.0 * w_def) + (14.0 * w_def)

	# 6. Base stat & stamina cost trade-off
	score += (float(card.damage) * 8.0 * w_dmg) + (float(card.block_value) * 5.0 * w_def) + (float(card.heal_value) * 5.0 * w_def)
	score += float(card.momentum_gain) * 3.5 * w_dmg

	if card.cost > 0:
		var my_sp_ratio: float = float(me.current_sp) / float(max(1, me.max_sp))
		var scarcity: float = 1.0 if my_sp_ratio > 0.35 else 1.5
		score -= float(card.cost) * (4.0 * w_cost * scarcity)

	return score
