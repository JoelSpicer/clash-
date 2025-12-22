class_name CharacterData
extends Resource

enum ClassType { HEAVY, PATIENT, QUICK, TECHNICAL }

@export_group("Identity")
@export var character_name: String
@export var portrait: Texture2D
@export var class_type: ClassType

@export_group("Stats")
@export var max_hp: int = 10     # Standard starting HP [cite: 810]
@export var max_sp: int = 3      # FIXED: Uses the corrected v0.3 value [cite: 807]
@export var speed: int = 1       # "Priority Token" stat (Quick=4, Heavy=1) 

@export_group("Progression")
# This array holds every card the player has learned.
# In the Selection Phase, we instantiate a Card Button for each item in this list.
@export var deck: Array[ActionData] 

@export_group("Abilities")
@export_multiline var passive_desc: String # Description of Rage/Relentless/etc. [cite: 798]
