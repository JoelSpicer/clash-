class_name ActionData
extends Resource

# Enums allow for dropdown selection in the Inspector, preventing typos.
enum Type { OFFENCE, DEFENCE }

# --- VISUALS ---
@export_group("Visuals")
@export var id: String             # Unique ID (e.g., "basic_strike_01")
@export var display_name: String   # The name displayed to the player
@export var icon: Texture2D        # The card art/icon
@export_multiline var description: String # Tooltip description of effects

# --- CORE STATS ---
@export_group("Core Stats")
@export var type: Type             # OFFENCE (Red) or DEFENCE (Blue)
@export var cost: int = 0          # Stamina (SP) cost to play this card
@export var damage: int = 0        # Base damage dealt to opponent
@export var momentum_gain: int = 0 # Amount this card pushes the momentum tracker

# --- COMBAT VALUES ---
@export_group("Combat Values")
@export var block_value: int = 0   # Reduces incoming Damage
@export var dodge_value: int = 0   # Reduces incoming Damage (thematically distinct)
@export var heal_value: int = 0    # Restores HP
@export var recover_value: int = 0 # Restores SP
@export var fall_back_value: int = 0 # Pushes momentum backwards (counteracts gain)
@export var counter_value: int = 0 # Required "Opening" level on opponent to play this
@export var tiring: int = 0        # Drains opponent's SP on hit

# --- SPECIAL BOOLEANS ---
@export_group("Special Mechanics")
@export var is_opener: bool = false      # Can be played at 0 Momentum or start of combo
@export var is_super: bool = false       # Requires specific Momentum; 1 use per match
@export var guard_break: bool = false    # Ignores opponent's Block/Dodge
@export var feint: bool = false          # Triggers Secondary Selection phase
#@export var injure: bool = false         # Applies "Injured" status (DoT)
@export var sweep: bool = false          # (Mass combat flag - unused in 1v1)
@export var retaliate: bool = false      # Reflects damage back to attacker
@export var reversal: bool = false       # Seizes initiative if momentum moves closer
@export var is_parry: bool = false       # Steals momentum; grants Immunity if successful

# --- NEW: SCALABLE STATUS PAYLOAD ---
# Editor Usage: Add Element -> Key: "name" Value: "Poison", Key: "amount" Value: 3
@export var statuses_to_apply: Array[Dictionary] = []

# --- ADVANCED LOGIC ---
@export_group("Advanced Logic")
@export var multi_limit: int = 0         # Limits opponent's max cost next turn
@export var repeat_count: int = 1        # Number of times the effect loop runs (e.g., Flurry)
@export var create_opening: int = 0      # Sets opponent's Opening Stat (enables Counters)
@export var opportunity: int = 0         # Reduces cost/Increases momentum next turn
