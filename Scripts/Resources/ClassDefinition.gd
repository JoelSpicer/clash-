extends Resource
class_name ClassDefinition

@export_group("Identity")
@export var class_named: String = "New Class"
@export var class_type: CharacterData.ClassType # Keep enum for safety, or switch to String ID
@export var portrait: Texture2D
@export_multiline var passive_description: String
@export_multiline var tree_description: String
@export_multiline var playstyle_summary: String = "A brief description of how this class plays."

@export_group("Base Stats")
@export var base_hp: int = 5
@export var base_sp: int = 4
@export var base_speed: int = 1

@export_group("Growth Rules")
# How much stats increase per card type
@export var offence_hp_growth: int = 0
@export var offence_sp_growth: int = 0
@export var defence_hp_growth: int = 0
@export var defence_sp_growth: int = 0

@export_group("Progression")
@export var starting_deck: Array[ActionData] = []
@export var skill_tree_root_id: int = 0

@export_group("Passive Mechanics")
@export var can_pay_with_hp: bool = false
@export var tiring_drains_hp: bool = false
@export var combo_sp_recovery_rate: int = 0 # 0 means disabled, 3 means every 3 hits
@export var has_bide_mechanic: bool = false
@export var has_keep_up_toggle: bool = false
@export var has_technique_dropdown: bool = false
