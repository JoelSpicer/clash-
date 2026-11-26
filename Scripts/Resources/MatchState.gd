extends RefCounted
class_name MatchState

var momentum: int = 0
var current_combo_attacker: int = 0
var attacker_override: int = 0
var priority_player: int = 1

var p1_cost_limit: int = 99
var p2_cost_limit: int = 99
var p1_opening_stat: int = 0
var p2_opening_stat: int = 0
var p1_opportunity_stat: int = 0
var p2_opportunity_stat: int = 0

var p1_must_opener: bool = false
var p2_must_opener: bool = false
var p1_pending_feint: bool = false
var p2_pending_feint: bool = false

var p1_rage_active: bool = false
var p2_rage_active: bool = false
var p1_keep_up_active: bool = false
var p2_keep_up_active: bool = false

var p1_gym_block_bonus: int = 0

var p1_locked_card: ActionData = null
var p2_locked_card: ActionData = null

var p1_action_queue: ActionData = null
var p2_action_queue: ActionData = null

# --- AI MEMORY (Previous Clash Context) ---
var p1_last_action_name: String = ""
var p2_last_action_name: String = ""
var p1_last_cost: int = 0
var p2_last_cost: int = 0


func to_dict() -> Dictionary:
	return {
		"momentum": momentum,
		"current_combo_attacker": current_combo_attacker,
		"attacker_override": attacker_override,
		"priority_player": priority_player,
		"p1_cost_limit": p1_cost_limit,
		"p2_cost_limit": p2_cost_limit,
		"p1_opening_stat": p1_opening_stat,
		"p2_opening_stat": p2_opening_stat,
		"p1_opportunity_stat": p1_opportunity_stat,
		"p2_opportunity_stat": p2_opportunity_stat,
		"p1_must_opener": p1_must_opener,
		"p2_must_opener": p2_must_opener,
		"p1_pending_feint": p1_pending_feint,
		"p2_pending_feint": p2_pending_feint,
		"p1_rage_active": p1_rage_active,
		"p2_rage_active": p2_rage_active,
		"p1_keep_up_active": p1_keep_up_active,
		"p2_keep_up_active": p2_keep_up_active,
		"p1_gym_block_bonus": p1_gym_block_bonus,
		"p1_last_action_name": p1_last_action_name,
		"p2_last_action_name": p2_last_action_name,
		"p1_last_cost": p1_last_cost,
		"p2_last_cost": p2_last_cost,
		"p1_locked_card_name": p1_locked_card.display_name if p1_locked_card != null else "",
		"p2_locked_card_name": p2_locked_card.display_name if p2_locked_card != null else ""
	}


func from_dict(data: Dictionary) -> void:
	momentum = data.get("momentum", 0)
	current_combo_attacker = data.get("current_combo_attacker", 0)
	attacker_override = data.get("attacker_override", 0)
	priority_player = data.get("priority_player", 1)
	p1_cost_limit = data.get("p1_cost_limit", 99)
	p2_cost_limit = data.get("p2_cost_limit", 99)
	p1_opening_stat = data.get("p1_opening_stat", 0)
	p2_opening_stat = data.get("p2_opening_stat", 0)
	p1_opportunity_stat = data.get("p1_opportunity_stat", 0)
	p2_opportunity_stat = data.get("p2_opportunity_stat", 0)
	p1_must_opener = data.get("p1_must_opener", false)
	p2_must_opener = data.get("p2_must_opener", false)
	p1_pending_feint = data.get("p1_pending_feint", false)
	p2_pending_feint = data.get("p2_pending_feint", false)
	p1_rage_active = data.get("p1_rage_active", false)
	p2_rage_active = data.get("p2_rage_active", false)
	p1_keep_up_active = data.get("p1_keep_up_active", false)
	p2_keep_up_active = data.get("p2_keep_up_active", false)
	p1_gym_block_bonus = data.get("p1_gym_block_bonus", 0)
	p1_last_action_name = data.get("p1_last_action_name", "")
	p2_last_action_name = data.get("p2_last_action_name", "")
	p1_last_cost = data.get("p1_last_cost", 0)
	p2_last_cost = data.get("p2_last_cost", 0)
