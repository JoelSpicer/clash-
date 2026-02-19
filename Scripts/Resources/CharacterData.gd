class_name CharacterData
extends Resource

#region vars

#To add a completely new class identity, you still need to do two small code updates:
#
#Add MAGE to the ClassType Enum.
#
#Add the if class == MAGE: logic in GameManager for their specific mechanic.

enum ClassType { HEAVY, PATIENT, QUICK, TECHNICAL }

# --- NEW: AI PERSONALITY TYPES ---
enum AIArchetype { BALANCED, AGGRESSIVE, DEFENSIVE, TRICKSTER }
@export var ai_archetype: AIArchetype = AIArchetype.BALANCED 
# ---------------------------------

# --- STATIC DATA ---
@export_group("Identity")
@export var character_name: String
@export var portrait: Texture2D
@export var class_type: ClassType

@export_group("Stats")
@export var max_hp: int = 5     
@export var max_sp: int = 4      
@export var speed: int = 1       

@export_group("Progression")
@export var deck: Array[ActionData]  # The Active 8 Cards
@export var unlocked_actions: Array[ActionData] = [] # The Full Library
@export var equipment: Array[EquipmentData] = [] # <--- NEW: The items you carry

@export_group("Passive")
@export_multiline var passive_desc: String 

# --- RUNTIME STATE ---
@export_group("Runtime State")
var current_hp: int
var current_sp: int
var has_used_super: bool = false 
var combo_action_count: int = 0 # Track for Relentless passive
var patient_buff_active: bool = false #Tracks the +1 Damage Buff
# NEW: Passive Flags inherited from Class
var can_pay_with_hp: bool = false
var tiring_drains_hp: bool = false
var combo_sp_recovery_rate: int = 0
var has_bide_mechanic: bool = false
var has_keep_up_toggle: bool = false
var has_technique_dropdown: bool = false


# --- NEW: STATUS DICTIONARY ---
# Format: { "Injured": 1, "Poison": 3, "Stunned": 1 }
var statuses: Dictionary = {}


#endregion

# --- LOGIC ---

func reset_stats(maintain_hp: bool = false):
	# Only reset HP to max if we are NOT maintaining it
	if not maintain_hp:
		current_hp = max_hp
		
	# SP and Statuses always reset per fight
	current_sp = max_sp
	has_used_super = false
	combo_action_count = 0
	patient_buff_active = false
	statuses.clear()
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

# --- SERIALIZATION (SAVE/LOAD) ---

func to_save_dictionary() -> Dictionary:
	return {
		"identity": {
			"name": character_name,
			"type": class_type,
			"portrait_path": portrait.resource_path if portrait else ""
		},
		"stats": {
			"current_hp": current_hp,
			"max_hp": max_hp,
			"current_sp": current_sp,
			"max_sp": max_sp,
			"speed": speed
		},
		# Save Cards by their Display Name (which ClassFactory uses to find them)
		"deck": deck.map(func(c): return c.display_name),
		"library": unlocked_actions.map(func(c): return c.display_name),
		# Save Equipment by Display Name
		"equipment": equipment.map(func(e): return e.display_name),
		"statuses": statuses
	}

# Static helper to rebuild data from the dictionary
static func from_save_dictionary(data: Dictionary) -> CharacterData:
	var new_char = CharacterData.new()
	
	# 1. Identity
	new_char.character_name = data.identity.name
	new_char.class_type = data.identity.type as ClassType
	
	# --- NEW: INJECT PASSIVES FROM REGISTRY ---
	var def = ClassFactory.class_registry.get(new_char.class_type)
	if def:
		new_char.can_pay_with_hp = def.can_pay_with_hp
		new_char.tiring_drains_hp = def.tiring_drains_hp
		new_char.combo_sp_recovery_rate = def.combo_sp_recovery_rate
		new_char.has_bide_mechanic = def.has_bide_mechanic
		new_char.has_keep_up_toggle = def.has_keep_up_toggle
		new_char.has_technique_dropdown = def.has_technique_dropdown
	# ------------------------------------------
	if data.identity.portrait_path != "":
		new_char.portrait = load(data.identity.portrait_path)
	
	# 2. Stats
	new_char.current_hp = data.stats.current_hp
	new_char.max_hp = data.stats.max_hp
	new_char.current_sp = data.stats.current_sp
	new_char.max_sp = data.stats.max_sp
	new_char.speed = data.stats.speed
	new_char.statuses = data.statuses
	
	# 3. Reconstruct Deck (String -> Resource)
	for card_name in data.deck:
		var card = ClassFactory.find_action_resource(card_name)
		if card: new_char.deck.append(card)
		
	# 4. Reconstruct Library
	for card_name in data.library:
		var card = ClassFactory.find_action_resource(card_name)
		if card: new_char.unlocked_actions.append(card)
	
	# 5. Reconstruct Equipment (Requires RunManager helper)
	# We will handle equipment re-linking in RunManager because it owns the equipment list
	
	return new_char
