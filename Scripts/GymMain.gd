extends Control

@onready var stats_label: Label = $Content/StatsLabel
@onready var btn_heal: Button = $Content/ChoicesContainer/BtnHeal
@onready var btn_block: Button = $Content/ChoicesContainer/BtnBlock
@onready var btn_debuff: Button = $Content/ChoicesContainer/BtnDebuff
@onready var flavor_text: Label = $Content/FlavorText

var player: CharacterData


func _ready() -> void:
	player = RunManager.player_run_data
	_update_stats_display()

	var heal_amt: int = _get_heal_amount()
	btn_heal.text = "FIRST AID\n\nHeal %d HP\n(Immediate)" % heal_amt
	btn_block.text = "IRON STANCE\n\nStart Next Fight\nwith +1 Block"
	btn_debuff.text = "EXPLOIT WEAKNESS\n\nNext Enemy Starts\nwith -20% HP"

	btn_heal.pressed.connect(_on_heal_pressed)
	btn_block.pressed.connect(_on_block_pressed)
	btn_debuff.pressed.connect(_on_debuff_pressed)


func _update_stats_display() -> void:
	if player == null:
		return
	stats_label.text = "CURRENT CONDITION\nHP: %d / %d   |   SP: %d / %d" % [
		player.current_hp, player.max_hp,
		player.current_sp, player.max_sp
	]


func _on_heal_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	var heal_amt: int = _get_heal_amount()
	player.current_hp = mini(player.current_hp + heal_amt, player.max_hp)
	flavor_text.text = "Patched up and ready to fight."
	_finish_gym()


func _on_block_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	RunManager.active_gym_buff = "iron_stance"
	flavor_text.text = "Practicing your guard..."
	_finish_gym()


func _on_debuff_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	RunManager.active_gym_buff = "exploit_weakness"
	flavor_text.text = "Studying enemy weak points..."
	_finish_gym()


func _finish_gym() -> void:
	_update_stats_display()
	btn_heal.disabled = true
	btn_block.disabled = true
	btn_debuff.disabled = true

	await get_tree().create_timer(1.0).timeout
	RunManager.advance_map()


func _get_heal_amount() -> int:
	var base_heal: int = maxi(1, roundi(float(player.max_hp) * 0.3))
	if RunManager.active_sponsor:
		base_heal = roundi(float(base_heal) * RunManager.active_sponsor.gym_bonus_multiplier)
	return base_heal
