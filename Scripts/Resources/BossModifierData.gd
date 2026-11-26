extends EquipmentData
class_name BossModifierData

@export_category("Boss Identity")
@export var boss_epithet: String = "THE CHALLENGER"
@export_multiline var boss_intro_line: String = "Show me everything you've got!"
@export var preferred_ai_profile: AIBehavior = null
@export var grant_super: bool = false
