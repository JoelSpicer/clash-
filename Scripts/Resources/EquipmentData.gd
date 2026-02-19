class_name EquipmentData
extends Resource

@export_group("Visuals")
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_group("Trade-offs")
# We keep these so you can make items like "Cursed Ring: +Damage, -Max HP"
@export var max_hp_bonus: int = 0
@export var max_sp_bonus: int = 0

@export_group("Start of Fight")
@export var starting_sp_bonus: int = 0
@export var starting_barrier: int = 0    # Starts fight with Temporary HP (Shield)
@export var starting_momentum: int = 0   # Positive starts momentum closer to enemy

@export_group("Combat Passives")
@export var damage_modifier: int = 0     # Added to every attack
@export var block_modifier: int = 0      # Added to every block
@export var speed_bonus: int = 0         # Helps win Priority clashes (Speed ties)
@export var wall_crush_damage_bonus: int = 0

@export_group("Reactionary")
@export var thorns: int = 0              # Deal X damage to opponent when they hit you
@export var heal_on_win: int = 0         # Sustain for long runs
