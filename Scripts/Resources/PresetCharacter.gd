extends Resource
class_name PresetCharacter

@export_group("Identity")
@export var character_name: String = "New Hero"
@export var class_type: CharacterData.ClassType = CharacterData.ClassType.HEAVY
@export var level: int = 1 # Mostly for flavor, or you could display it

@export_multiline var description: String = "Preset description."

@export_group("Build")
@export var extra_skills: Array[String] = [] # List the EXACT names of actions here (e.g. "Drop Kick")
