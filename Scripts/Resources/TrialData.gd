class_name TrialData
extends Resource

enum Category {
	INTERACTION_DRILL,
	PASSIVES_AND_HYBRIDS,
	TACTICAL_PUZZLE,
}

# --- METADATA ---
@export var id: String = ""
@export var title: String = ""
@export var category: Category = Category.INTERACTION_DRILL
@export var order: int = 0
@export var difficulty: int = 1 # 1..3 stars
@export var focus_trait: String = ""
@export var objective_short: String = ""
@export_multiline var briefing_text: String = ""
@export_multiline var hint_text: String = ""
@export_multiline var lesson_summary: String = ""
@export var token_reward: int = 5
@export var environment: String = "Dojo"

# --- FIGHTER SETUP ---
@export var p1_name: String = "Challenger"
@export var p1_class: CharacterData.ClassType = CharacterData.ClassType.NONE
@export var p1_max_hp: int = 10
@export var p1_start_hp: int = 10
@export var p1_max_sp: int = 5
@export var p1_start_sp: int = 5
@export var p1_card_names: Array[String] = []

@export var p2_name: String = "Sensei"
@export var p2_class: CharacterData.ClassType = CharacterData.ClassType.NONE
@export var p2_max_hp: int = 10
@export var p2_start_hp: int = 10
@export var p2_max_sp: int = 5
@export var p2_start_sp: int = 5
@export var p2_card_names: Array[String] = []

# --- INITIAL MATCH STATE ---
@export var start_momentum: int = 0
@export var start_combo_attacker: int = 0
@export var start_priority_player: int = 1
@export var start_p1_opening: int = 0
@export var start_p2_opening: int = 0
@export var start_p1_opportunity: int = 0
@export var start_p2_opportunity: int = 0
@export var start_p1_must_opener: bool = false
@export var start_p2_must_opener: bool = false
@export var start_p1_statuses: Dictionary = {}
@export var start_p2_statuses: Dictionary = {}

# --- OPPONENT SCRIPT & TELEGRAPHING ---
@export var bot_moves: Array[String] = []
@export var show_enemy_intent: bool = true

# --- COMPOSABLE WIN CONDITIONS ---
@export var turn_limit: int = 1
@export var require_enemy_ko: bool = false
@export var max_p1_damage_taken: int = -1 # -1 = unlimited (as long as P1 survives)
@export var require_p1_attacker: bool = false
@export var require_p1_parry: bool = false
@export var min_p1_sp_end: int = -1 # -1 = ignored
@export var min_damage_to_p2: int = 0
