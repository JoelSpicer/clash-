class_name EquipmentData
extends Resource

@export_group("Visuals")
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_group("Stat Modifiers")
@export var max_hp_bonus: int = 0
@export var max_sp_bonus: int = 0
@export var starting_sp_bonus: int = 0 # Gives extra SP at the start of a fight

@export_group("Combat Modifiers")
@export var wall_crush_damage_bonus: int = 0
