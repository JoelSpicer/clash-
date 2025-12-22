class_name ActionData
extends Resource

# We use an Enum for Type so you get a dropdown menu in the Inspector
# instead of typing "Offence" strings (which prevents typos).
enum Type { OFFENCE, DEFENCE }

@export_group("Visuals")
@export var id: String             # Internal ID (e.g., "basic_light")
@export var display_name: String   # The text shown on the card
@export var icon: Texture2D        # The art [cite: 785]
@export_multiline var description: String # For specific effect text

@export_group("Core Stats")
@export var type: Type             # Defines the border color (Red/Blue)
@export var cost: int = 0          # "Cost X" [cite: 1257]
@export var damage: int = 0        # "Damage X" [cite: 1263]
@export var momentum_gain: int = 0 # "Momentum X" [cite: 1279]

@export_group("Combat Values")
# We export these explicitly so the Game Manager can do math easily.
# e.g., "if p2_card.block_value > 0: damage -= p2_card.block_value"
@export var block_value: int = 0   # "Block X" [cite: 1255]
@export var dodge_value: int = 0   # "Dodge X" [cite: 1267]
@export var heal_value: int = 0    # "Heal X" [cite: 1276]
@export var recover_value: int = 0 # "Recover X" [cite: 1295]
@export var fall_back_value: int = 0 # "Fall Back X" [cite: 1269]
@export var counter_value: int = 0 # "Counter X" [cite: 1259]
@export var tiring_value: int = 0

@export_group("Special Mechanics")
# These booleans trigger specific states in the Game Manager.
@export var is_opener: bool = false      # "Opener" [cite: 1288]
@export var is_super: bool = false       # "Super" [cite: 1305]
@export var guard_break: bool = false    # "Guard Break" [cite: 1274]
@export var feint: bool = false          # "Feint" [cite: 1271] (Triggers the secondary choice menu)
@export var injure: bool = false         # "Injure" [cite: 1277] (Applies the DoT status)
@export var sweep: bool = false          # "Sweep" [cite: 1308] (Mass combat flag)
@export var retaliate: bool = false      # "Retaliate" [cite: 1300]
@export var reversal: bool = false       # "Reversal" [cite: 1302]
@export var is_parry: bool = false

@export_group("Advanced Logic")
@export var multi_limit: int = 0         # "Multi X" [cite: 1281] (Holds the Cost Limit for next turn)
@export var repeat_count: int = 1        # "Repeat X" [cite: 1297] (Default is 1. If 3, the loop runs 3 times)
@export var create_opening: int = 0      # "Create Opening X" [cite: 1261]
@export var opportunity: int = 0         # "Opportunity X" [cite: 1290]
@export var tiring: int = 0              # "Tiring X" [cite: 1310]
