extends BaseModifierData # <--- THIS IS THE MAGIC LINE
class_name SponsorData

@export_category("Sponsor Specifics")
@export var flavor_quote: String = "\"Win at all costs.\""

@export_category("Starting Loadout")
@export var starting_equipment: Array[EquipmentData] = []
@export var starting_cards: Array[ActionData] = []

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
