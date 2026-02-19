class_name MapNodeData
extends Resource

enum Type { FIGHT, BOSS, GYM, SHOP, EVENT, MYSTERY }

@export var type: Type = Type.FIGHT
@export var title: String = "Round 1"
@export var is_completed: bool = false
@export var is_locked: bool = true # Unlock when previous node is beaten

# --- CONTENT ---
# If it's a fight, we store the generated enemy here
@export var enemy_data: CharacterData 

# If it's a shop/gym, we can store specific seed data here later
@export var special_data: Dictionary = {}
