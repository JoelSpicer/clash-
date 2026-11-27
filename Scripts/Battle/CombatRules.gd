class_name CombatRules
extends RefCounted

## Single source of truth for combat turn constraints, card legality,
## Technical custom-technique mutations, modifier collection, and locked-card serialization.


static func get_all_modifiers_for(player_id: int) -> Array[BaseModifierData]:
	var mods: Array[BaseModifierData] = []
	var character: CharacterData = GameManager.p1_data if player_id == 1 else GameManager.p2_data
	if character != null:
		for eq: EquipmentData in character.equipment:
			if eq != null and eq not in mods:
				mods.append(eq)

	if player_id == 1 and RunManager.is_arcade_mode:
		if RunManager.player_run_data != null and RunManager.player_run_data != character:
			for eq: EquipmentData in RunManager.player_run_data.equipment:
				if eq != null and eq not in mods:
					mods.append(eq)
		if RunManager.active_sponsor != null:
			mods.append(RunManager.active_sponsor)

	return mods


static func get_player_constraints(player_id: int) -> Dictionary:
	var attacker_id: int = GameManager.get_attacker()
	var is_combo: bool = (GameManager.state.current_combo_attacker != 0)
	var mom: int = GameManager.state.momentum
	var character: CharacterData = GameManager.p1_data if player_id == 1 else GameManager.p2_data

	var c: Dictionary = {
		"filter": null,
		"required_tab": null,
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
		if character != null and mom == GameManager.get_wall_momentum(1) and not character.has_used_super and not GameManager.is_super_disabled(1):
			c["can_use_super"] = true
		if GameManager.state.p1_must_opener:
			c["needs_opener"] = true
	else:
		c["max_cost"] = GameManager.state.p2_cost_limit
		c["opening_stat"] = GameManager.state.p2_opening_stat
		c["opportunity_stat"] = GameManager.state.p2_opportunity_stat
		if character != null and mom == GameManager.get_wall_momentum(2) and not character.has_used_super and not GameManager.is_super_disabled(2):
			c["can_use_super"] = true
		if GameManager.state.p2_must_opener:
			c["needs_opener"] = true

	if attacker_id != 0:
		if attacker_id == player_id:
			c["filter"] = ActionData.Type.OFFENCE
			c["required_tab"] = ActionData.Type.OFFENCE
		else:
			c["filter"] = ActionData.Type.DEFENCE
			c["required_tab"] = ActionData.Type.DEFENCE

	if mom == 0 or (attacker_id == player_id and not is_combo):
		c["needs_opener"] = true

	return c


static func apply_technique(action: ActionData, tech_idx: int) -> ActionData:
	if action == null or tech_idx <= 0:
		return action
	var final_action: ActionData = action.duplicate() as ActionData
	final_action.cost += 1
	match tech_idx:
		1:
			if final_action.type == ActionData.Type.OFFENCE:
				final_action.is_opener = true
				final_action.display_name += "+"
		2:
			final_action.tiring += 1
			final_action.display_name += "+"
		3:
			final_action.momentum_gain += 1
			final_action.display_name += "+"
	return final_action


static func get_display_cost(card: ActionData, opp_val: int, tech_idx: int = 0, feint_mode: bool = false, base_feint_cost: int = 0) -> int:
	var raw_cost: int = card.cost + (1 if tech_idx > 0 else 0) + (base_feint_cost if feint_mode else 0)
	return maxi(0, raw_cost - opp_val)


static func evaluate_card_legality(
	character: CharacterData,
	card: ActionData,
	constraints: Dictionary,
	rage_active: bool = false,
	tech_idx: int = 0,
	feint_mode: bool = false,
	base_feint_cost: int = 0
) -> Dictionary:
	var opp_val: int = int(constraints.get("opportunity_stat", 0))
	var effective_cost: int = get_display_cost(card, opp_val, tech_idx, feint_mode, base_feint_cost)

	var type_filter: Variant = constraints.get("filter", null)
	if type_filter != null and card.type != type_filter:
		return { "valid": false, "effective_cost": effective_cost, "reason": "wrong_type" }

	var max_cost: int = int(constraints.get("max_cost", 99))
	var action_raw_cost: int = card.cost + (1 if tech_idx > 0 else 0)
	if action_raw_cost > max_cost:
		return { "valid": false, "effective_cost": effective_cost, "reason": "cost_limit" }

	var opening_stat: int = int(constraints.get("opening_stat", 0))
	if card.counter_value > 0 and opening_stat < card.counter_value:
		return { "valid": false, "effective_cost": effective_cost, "reason": "counter_req" }

	var can_use_super: bool = bool(constraints.get("can_use_super", false))
	if card.is_super and not can_use_super:
		return { "valid": false, "effective_cost": effective_cost, "reason": "super_locked" }

	var needs_opener: bool = bool(constraints.get("needs_opener", false))
	if needs_opener and card.type == ActionData.Type.OFFENCE:
		var has_opener: bool = card.is_opener or (tech_idx == 1)
		if not has_opener:
			return { "valid": false, "effective_cost": effective_cost, "reason": "needs_opener" }

	if character == null:
		return { "valid": false, "effective_cost": effective_cost, "reason": "no_character" }

	var affordable: bool = false
	if rage_active and character.can_pay_with_hp:
		affordable = character.current_hp > effective_cost
	elif character.current_sp >= effective_cost:
		affordable = true
	elif character.can_pay_with_hp and (character.current_sp + character.current_hp) > effective_cost:
		affordable = true

	return {
		"valid": affordable,
		"effective_cost": effective_cost,
		"reason": "" if affordable else "unaffordable",
	}


static func serialize_action_snapshot(card: ActionData) -> Dictionary:
	if card == null:
		return {}
	return {
		"display_name": card.display_name,
		"description": card.description,
		"type": int(card.type),
		"cost": card.cost,
		"damage": card.damage,
		"block_value": card.block_value,
		"dodge_value": card.dodge_value,
		"momentum_gain": card.momentum_gain,
		"fall_back_value": card.fall_back_value,
		"recover_value": card.recover_value,
		"heal_value": card.heal_value,
		"tiring": card.tiring,
		"create_opening": card.create_opening,
		"counter_value": card.counter_value,
		"opportunity": card.opportunity,
		"multi_limit": card.multi_limit,
		"repeat_count": card.repeat_count,
		"guard_break": card.guard_break,
		"retaliate": card.retaliate,
		"is_parry": card.is_parry,
		"reversal": card.reversal,
		"feint": card.feint,
		"sweep": card.sweep,
		"is_opener": card.is_opener,
		"is_super": card.is_super,
		"is_basic": card.is_basic,
		"is_struggle": card.is_struggle,
		"statuses_to_apply": card.statuses_to_apply.duplicate(true),
	}


static func deserialize_action_snapshot(data: Dictionary) -> ActionData:
	if data.is_empty():
		return null
	var card: ActionData = ActionData.new()
	card.display_name = str(data.get("display_name", ""))
	card.description = str(data.get("description", ""))
	card.type = int(data.get("type", 0)) as ActionData.Type
	card.cost = int(data.get("cost", 0))
	card.damage = int(data.get("damage", 0))
	card.block_value = int(data.get("block_value", 0))
	card.dodge_value = int(data.get("dodge_value", 0))
	card.momentum_gain = int(data.get("momentum_gain", 0))
	card.fall_back_value = int(data.get("fall_back_value", 0))
	card.recover_value = int(data.get("recover_value", 0))
	card.heal_value = int(data.get("heal_value", 0))
	card.tiring = int(data.get("tiring", 0))
	card.create_opening = int(data.get("create_opening", 0))
	card.counter_value = int(data.get("counter_value", 0))
	card.opportunity = int(data.get("opportunity", 0))
	card.multi_limit = int(data.get("multi_limit", 0))
	card.repeat_count = int(data.get("repeat_count", 1))
	card.guard_break = bool(data.get("guard_break", false))
	card.retaliate = bool(data.get("retaliate", false))
	card.is_parry = bool(data.get("is_parry", false))
	card.reversal = bool(data.get("reversal", false))
	card.feint = bool(data.get("feint", false))
	card.sweep = bool(data.get("sweep", false))
	card.is_opener = bool(data.get("is_opener", false))
	card.is_super = bool(data.get("is_super", false))
	card.is_basic = bool(data.get("is_basic", false))
	card.is_struggle = bool(data.get("is_struggle", false))
	var raw_statuses: Array = data.get("statuses_to_apply", [])
	card.statuses_to_apply.clear()
	for s: Variant in raw_statuses:
		if s is Dictionary:
			card.statuses_to_apply.append((s as Dictionary).duplicate(true))
	return card
