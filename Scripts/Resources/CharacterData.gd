class_name CharacterData
extends Resource

enum ClassType { HEAVY, PATIENT, QUICK, TECHNICAL }

# --- STATIC DATA (Does not change during match) ---
@export_group("Identity")
@export var character_name: String
@export var portrait: Texture2D
@export var class_type: ClassType

@export_group("Stats")
@export var max_hp: int = 10     # Maximum Health
@export var max_sp: int = 3      # Maximum Stamina
@export var speed: int = 1       # Determines Priority in ties

@export_group("Progression")
@export var deck: Array[ActionData] # The list of cards available to this character

@export_group("Passive")
@export_multiline var passive_desc: String # Flavor text for passives

# --- RUNTIME STATE (Changes during match) ---
@export_group("Runtime State")
var current_hp: int
var current_sp: int
var has_used_super: bool = false # Tracks if the 1-per-match Super has been used

# Resets the character to full health/stamina for a new match
func reset_stats():
	current_hp = max_hp
	current_sp = max_sp
	has_used_super = false
