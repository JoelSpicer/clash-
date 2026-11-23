extends Resource
class_name AIBehavior

## Base utility weights exported for Inspector tuning on .tres instances.
@export_group("Base Weights")
@export var w_dmg: float = 1.0
@export var w_def: float = 1.0
@export var w_tech: float = 1.0
@export var w_cost: float = 1.0

@export_group("Behavioral Thresholds")
@export var repetition_penalty: float = 100.0
@export var kill_shot_bonus: float = 1000.0
@export var panic_hp_threshold: int = 3


## Evaluates how desirable [param card] is for [param me] against [param opp].
## Override in subclasses for archetype-specific scoring rules.
func score_action(card: ActionData, me: CharacterData, opp: CharacterData, my_id: int) -> float:
	push_error("AIBehavior.score_action() must be overridden by a subclass.")
	return 0.0
