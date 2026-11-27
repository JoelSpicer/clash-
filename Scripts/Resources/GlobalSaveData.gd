extends Resource
class_name GlobalSaveData

@export var circuit_tokens: int = 0

# Future-proofing for when we build the unlock shop!
@export var unlocked_sponsors: Array[String] = []
@export var unlocked_classes: Array[String] = []
@export var seen_menu_tutorials: Dictionary = {}
@export var completed_trials: Array[String] = []
@export var career_stats: Dictionary = {}
@export var match_history: Array[Dictionary] = []
@export var unlocked_achievements: Array[String] = []
@export var active_title: String = ""
