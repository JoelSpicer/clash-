extends Resource
class_name GlobalSaveData

@export var circuit_tokens: int = 0

# Future-proofing for when we build the unlock shop!
@export var unlocked_sponsors: Array[String] = []
@export var unlocked_classes: Array[String] = []
