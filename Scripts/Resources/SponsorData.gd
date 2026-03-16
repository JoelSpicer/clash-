extends Resource
class_name SponsorData

@export_category("Sponsor Identity")
@export var sponsor_name: String = "Unknown Sponsor"
@export_multiline var description: String = "Provides backing for the upcoming tournament."
@export var icon: Texture2D
@export var flavor_quote: String = "\"Win at all costs.\""

@export_category("Starting Stats")
@export var bonus_max_hp: int = 0
@export var bonus_max_sp: int = 0
@export var bonus_speed: int = 0
@export var starting_barrier: int = 0

@export_category("Starting Loadout")
@export var starting_equipment: Array[EquipmentData] = []
@export var starting_cards: Array[ActionData] = []

@export_category("Combat Passives")
@export var global_damage_mod: int = 0
@export var global_block_mod: int = 0
@export var momentum_start_bonus: int = 0
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
@export var thorns_active: int = 0

@export_category("The Rivalry")
@export_group("Rival Details")
@export var rival_character_name: String = ""
@export_multiline var rival_custom_intro: String = ""
@export_group("Rival Buffs (Difficulty)")
@export var rival_boss_hp_buff: int = 0
@export var rival_boss_sp_buff: int = 0
@export var rival_momentum_handicap: int = 0
@export_group("Rival Rewards")
@export var rival_reward_currency_bonus: int = 0
@export var rival_reward_item: EquipmentData
