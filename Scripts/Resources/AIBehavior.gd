extends Resource
class_name AIBehavior

## Base utility weights exported for Inspector tuning on .tres instances.
@export_group("Base Weights")
@export var w_dmg: float = 1.0
@export var w_def: float = 1.0
@export var w_tech: float = 1.0
@export var w_cost: float = 1.0

@export_group("Behavioral Thresholds")
@export var repetition_penalty: float = 22.0
@export var kill_shot_bonus: float = 1000.0
@export var panic_hp_threshold: int = 3


## Returns how many hits (1..repeat_count) this card will actually execute with [param me]'s current SP/Opportunity.
func _get_effective_hits(card: ActionData, me: CharacterData, my_id: int) -> int:
	var opp_val: int = GameManager.state.p1_opportunity_stat if my_id == 1 else GameManager.state.p2_opportunity_stat
	var is_free: bool = (GameManager.state.p1_locked_card != null if my_id == 1 else GameManager.state.p2_locked_card != null)
	return max(1, GameManager.get_effective_repeat_count(me, card, opp_val, is_free, false))


## Returns the total SP cost paid across [param hits] repetitions (Opportunity applies to hit 1 only).
func _get_effective_total_cost(card: ActionData, my_id: int, hits: int) -> int:
	var opp_val: int = GameManager.state.p1_opportunity_stat if my_id == 1 else GameManager.state.p2_opportunity_stat
	var single_cost: int = max(0, card.cost)
	var first_cost: int = max(0, single_cost - opp_val)
	return first_cost + single_cost * max(0, hits - 1)


## Returns expected total damage across [param hits], slightly discounting 1-dmg non-Guard-Break multi-hits for Block risk.
func _get_expected_damage(card: ActionData, hits: int) -> float:
	var raw: float = float(card.damage * hits)
	if hits > 1 and card.damage == 1 and not card.guard_break:
		return raw * 0.78
	return raw


## Evaluates how desirable [param card] is for [param me] against [param opp].
## Override in subclasses for archetype-specific scoring rules.
func score_action(_card: ActionData, _me: CharacterData, _opp: CharacterData, _my_id: int) -> float:
	push_error("AIBehavior.score_action() must be overridden by a subclass.")
	return 0.0
