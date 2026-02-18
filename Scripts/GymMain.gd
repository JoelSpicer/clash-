extends Control

# UI References
@onready var stats_label = $Content/StatsLabel
@onready var btn_heal = $Content/ChoicesContainer/BtnHeal
@onready var btn_block = $Content/ChoicesContainer/BtnBlock
@onready var btn_debuff = $Content/ChoicesContainer/BtnDebuff
@onready var flavor_text = $Content/FlavorText

var player: CharacterData

func _ready():
	# 1. Grab Player Data
	player = RunManager.player_run_data
	
	# 2. Setup Texts
	_update_stats_display()
	
	# HEAL: 30% of Max HP
	var heal_amt = max(1, roundi(player.max_hp * 0.3))
	btn_heal.text = "FIRST AID\n\nHeal %d HP\n(Immediate)" % heal_amt
	
	# BLOCK: Flat 10 (You can adjust this number)
	btn_block.text = "IRON STANCE\n\nStart Next Fight\nwith 10 Block"
	
	# DEBUFF: 20% of Enemy HP
	btn_debuff.text = "EXPLOIT WEAKNESS\n\nNext Enemy Starts\nwith -20% HP"
	
	# 3. Connect Signals
	btn_heal.pressed.connect(_on_heal_pressed)
	btn_block.pressed.connect(_on_block_pressed)
	btn_debuff.pressed.connect(_on_debuff_pressed)
	
	# Optional: Play Chill Music
	# AudioManager.play_music("gym_theme")

func _update_stats_display():
	stats_label.text = "CURRENT CONDITION\nHP: %d / %d   |   SP: %d / %d" % [
		player.current_hp, player.max_hp,
		player.current_sp, player.max_sp
	]

# --- CHOICE 1: IMMEDIATE HEAL ---
func _on_heal_pressed():
	AudioManager.play_sfx("ui_confirm")
	
	var heal_amt = max(1, roundi(player.max_hp * 0.3))
	player.current_hp = min(player.current_hp + heal_amt, player.max_hp)
	
	flavor_text.text = "Patched up and ready to fight."
	_finish_gym()

# --- CHOICE 2: DEFENSIVE BUFF ---
func _on_block_pressed():
	AudioManager.play_sfx("ui_confirm")
	
	# Store the string key in RunManager
	RunManager.active_gym_buff = "iron_stance"
	
	flavor_text.text = "Practicing your guard..."
	_finish_gym()

# --- CHOICE 3: OFFENSIVE DEBUFF ---
func _on_debuff_pressed():
	AudioManager.play_sfx("ui_confirm")
	
	# Store the string key in RunManager
	RunManager.active_gym_buff = "exploit_weakness"
	
	flavor_text.text = "Studying enemy weak points..."
	_finish_gym()

# --- EXIT LOGIC ---
func _finish_gym():
	_update_stats_display()
	
	# Disable all buttons to prevent double clicking
	btn_heal.disabled = true
	btn_block.disabled = true
	btn_debuff.disabled = true
	
	# Visual Juice: Wait 1.0 second so the player sees the result, then leave
	await get_tree().create_timer(1.0).timeout
	
	# Return to Map
	RunManager.advance_map()
