extends Resource
class_name BaseModifierData

@export_category("Synergy & Drops")
@export var synergy_keywords: Array[String] = [] 
# Example inputs: ["Defence", "Block", "Heavy"]

@export_category("Identity")
@export var item_name: String = "Unknown Modifier"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_category("Starting Stats")
@export var bonus_max_hp: int = 0
@export var bonus_max_sp: int = 0
@export var bonus_speed: int = 0
@export var starting_barrier: int = 0
@export var starting_sp_bonus: int = 0

@export_category("Combat Passives")
@export var damage_modifier: int = 0
@export var block_modifier: int = 0
@export var momentum_start_bonus: int = 0
@export var thorns: int = 0
@export var wall_crush_damage_bonus: int = 0
@export var heal_on_win: int = 0
@export var combo_sp_regen_bonus: int = 0

@export_category("Run Modifiers")
@export var extra_draft_options: int = 0
@export var starting_rerolls: int = 0
@export var gym_bonus_multiplier: float = 1.0
@export var meta_currency_multiplier: float = 1.0

@export_category("Rule-Breaking Toggles")
@export var reveal_enemy_opener: bool = false
@export var feints_cost_hp: bool = false
@export var disable_supers: bool = false
