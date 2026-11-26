extends AIBehavior
class_name AIBalanced


func _init() -> void:
	w_dmg = 1.0
	w_def = 1.0
	w_tech = 1.0
	w_cost = 1.0
	panic_hp_threshold = 4


## Scores an action with balanced offense, defense, technical setup, and stamina economy.
func score_action(card: ActionData, me: CharacterData, opp: CharacterData, my_id: int) -> float:
	var score: float = 0.0
	var match_state: GameManager.MatchState = GameManager.state

	var my_last_action: String = match_state.p1_last_action_name if my_id == 1 else match_state.p2_last_action_name
	var opp_last_cost: int = match_state.p2_last_cost if my_id == 1 else match_state.p1_last_cost

	# 1. Anti-repetition (inverted when Very Easy picks lowest scores)
	if card.display_name == my_last_action:
		if GameManager.ai_difficulty == GameManager.Difficulty.VERY_EASY:
			score += repetition_penalty
		else:
			score -= repetition_penalty

	# 2. Kill shot priority
	if card.damage >= opp.current_hp and opp.current_hp > 0:
		score += kill_shot_bonus

	# 3. Balanced offensive & defensive tactical scoring
	if card.type == ActionData.Type.OFFENCE:
		var opp_opening: int = match_state.p2_opening_stat if my_id == 1 else match_state.p1_opening_stat
		if opp_opening > 0 and card.counter_value > 0 and card.counter_value <= opp_opening:
			score += 50.0 * w_tech

		var opp_sp_ratio: float = float(opp.current_sp) / float(max(1, opp.max_sp))
		if opp_last_cost >= 2 or opp_sp_ratio < 0.35:
			score += float(card.damage) * 5.0 * w_dmg

		if card.guard_break:
			score += 25.0 * w_tech
		if card.feint:
			score += 15.0 * w_tech
	else:
		if opp_last_cost >= 2:
			if card.dodge_value > 0:
				score += 20.0 * w_def
			if card.block_value >= 4:
				score += 15.0 * w_def
		if card.recover_value > 0:
			score += float(card.recover_value) * 5.0 * w_def

	# 4. Survival instinct & Struggle SP management
	if me.current_hp < panic_hp_threshold:
		score += (float(card.block_value) * 10.0 * w_def) + (float(card.heal_value) * 15.0 * w_def) + (20.0 * w_def)

	if card.display_name == "Struggle":
		if me.current_sp <= 1:
			score += 50.0
		elif me.current_sp >= me.max_sp:
			score -= 50.0

	# 5. Base stat & stamina cost trade-off
	score += (float(card.damage) * 5.0 * w_dmg) + (float(card.block_value) * 5.0 * w_def) + (float(card.heal_value) * 5.0 * w_def)
	if card.tiring > 0:
		score += float(card.tiring) * 5.0 * w_tech
	if card.create_opening > 0:
		score += float(card.create_opening) * 5.0 * w_tech

	if card.cost > 0:
		var my_sp_ratio: float = float(me.current_sp) / float(max(1, me.max_sp))
		var scarcity: float = 1.0 if my_sp_ratio > 0.5 else 2.5
		score -= float(card.cost) * (10.0 * w_cost * scarcity)

	return score
