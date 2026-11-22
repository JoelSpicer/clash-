extends Resource
class_name AIBehavior

@export_group("Base Weights")
@export var w_dmg: float = 1.0
@export var w_def: float = 1.0
@export var w_tech: float = 1.0
@export var w_cost: float = 1.0

# Virtual function that derived classes must implement
func score_action(card: ActionData, me: CharacterData, opp: CharacterData, my_id: int) -> float:
	push_error("AIBehavior is a base class. Use a specialized AI Resource.")
	return 0.0
