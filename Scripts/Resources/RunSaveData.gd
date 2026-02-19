class_name RunSaveData
extends Resource

@export var run_name: String = ""
@export var current_level: int = 1
@export var current_map_index: int = 0
@export var difficulty: int = 2
@export var maintain_hp: bool = false
@export var tree_ids: Array[int] = []

@export var player_data: CharacterData
@export var map_data: Array[MapNodeData] = []
@export var timestamp: String = ""
