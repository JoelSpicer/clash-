class_name CharacterData
extends Resource

enum ClassType { HEAVY, PATIENT, QUICK, TECHNICAL }

# --- STATIC DATA ---
@export_group("Identity")
@export var character_name: String
@export var portrait: Texture2D
@export var class_type: ClassType

@export_group("Stats")
@export var max_hp: int = 10     
@export var max_sp: int = 3      
@export var speed: int = 1       

@export_group("Progression")
@export var deck: Array[ActionData] 

@export_group("Passive")
@export_multiline var passive_desc: String 

# --- RUNTIME STATE ---
@export_group("Runtime State")
var current_hp: int
var current_sp: int
var has_used_super: bool = false 
var combo_action_count: int = 0 # Track for Relentless passive

# --- LOGIC ---

func reset_stats():
	current_hp = max_hp
	current_sp = max_sp
	has_used_super = false
	combo_action_count = 0

# Call this when the player "Learns" a new card to apply Class Stat Growth
func unlock_action(new_action: ActionData):
	if new_action in deck: return
	
	deck.append(new_action)
	_apply_level_up_stats(new_action.type)

func _apply_level_up_stats(card_type):
	# Rules derived from PDF v0.2 Class Section
	match class_type:
		ClassType.HEAVY:
			if card_type == ActionData.Type.OFFENCE: max_sp += 1
			elif card_type == ActionData.Type.DEFENCE: max_hp += 2
			
		ClassType.PATIENT:
			if card_type == ActionData.Type.OFFENCE: max_hp += 1
			elif card_type == ActionData.Type.DEFENCE: 
				max_hp += 1
				max_sp += 1
				
		ClassType.QUICK:
			if card_type == ActionData.Type.OFFENCE: max_hp += 1
			elif card_type == ActionData.Type.DEFENCE: max_sp += 2
			
		ClassType.TECHNICAL:
			if card_type == ActionData.Type.OFFENCE: 
				max_hp += 1
				max_sp += 1
			elif card_type == ActionData.Type.DEFENCE: max_sp += 1
			
	# Heal to full on level up? Optional, but usually good.
	current_hp = max_hp
	current_sp = max_sp
	print("Level Up! New Stats - HP: " + str(max_hp) + " | SP: " + str(max_sp))
