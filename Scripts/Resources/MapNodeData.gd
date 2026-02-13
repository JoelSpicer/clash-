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


func to_save_dict() -> Dictionary:
	var data = {
		"type": type,
		"title": title,
		"is_completed": is_completed,
		"is_locked": is_locked,
		"enemy_data": null
	}
	if enemy_data:
		data["enemy_data"] = enemy_data.to_save_dictionary()
	return data

static func from_save_dict(data: Dictionary) -> MapNodeData:
	var node = MapNodeData.new()
	node.type = int(data.type) # Cast back to enum
	node.title = data.title
	node.is_completed = data.is_completed
	node.is_locked = data.is_locked
	
	if data.has("enemy_data") and data.enemy_data != null:
		node.enemy_data = CharacterData.from_save_dictionary(data.enemy_data)
		
	return node
