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

@export var pending_advancement: bool = false
@export var pending_reward: bool = false

@export var active_sponsor: SponsorData = null
@export var leagues_completed: int = 0
@export var current_rerolls: int = 0
@export var active_gym_buff: String = ""
@export var next_fight_statuses: Array[String] = []
@export var is_boss_match: bool = false
@export var is_rival_match: bool = false
