extends CanvasLayer

@onready var panel = $StatusPanel
@onready var btn_toggle = $ToggleBtn
@onready var hp_label = $StatusPanel/VBoxContainer/HpLabel
@onready var sp_label = $StatusPanel/VBoxContainer/SpLabel
@onready var eq_grid = $StatusPanel/VBoxContainer/EquipmentGrid

func _ready():
	panel.visible = false
	btn_toggle.pressed.connect(_on_toggle)
	btn_toggle.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))
	btn_toggle.pressed.connect(func(): AudioManager.play_sfx("ui_click"))

func _on_toggle():
	panel.visible = not panel.visible
	if panel.visible:
		btn_toggle.text = "Hide Run Status"
		_refresh_display()
	else:
		btn_toggle.text = "View Run Status"

func _refresh_display():
	var p1 = RunManager.player_run_data
	if not p1: return
	
	# 1. CALCULATE NEXT FIGHT STATS
	# HP is what you currently have. SP will reset to Max + any starting bonuses.
	var next_fight_hp = p1.current_hp
	var max_hp = p1.max_hp
	
	var max_sp = p1.max_sp
	var starting_sp_bonus = 0
	for item in p1.equipment:
		starting_sp_bonus += item.starting_sp_bonus
		
	var next_fight_sp = max_sp + starting_sp_bonus
	
	# Apply rich text colors for clarity
	hp_label.text = "NEXT FIGHT HP: " + str(next_fight_hp) + " / " + str(max_hp)
	sp_label.text = "NEXT FIGHT SP: " + str(next_fight_sp) + " / " + str(max_sp)

	# 2. POPULATE EQUIPMENT GRID (Same logic as BattleUI)
	for child in eq_grid.get_children():
		child.queue_free()
		
	for item in p1.equipment:
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Fallback icon
		if item.icon: icon.texture = item.icon
		else: icon.texture = preload("res://icon.svg") 
		
		# Build Tooltip
		var tip = item.display_name + "\n" + item.description + "\n"
		tip += "-------------------\n"
		if item.max_hp_bonus != 0: tip += "Max HP: " + ("+" if item.max_hp_bonus > 0 else "") + str(item.max_hp_bonus) + "\n"
		if item.max_sp_bonus != 0: tip += "Max SP: " + ("+" if item.max_sp_bonus > 0 else "") + str(item.max_sp_bonus) + "\n"
		if item.starting_sp_bonus != 0: tip += "Start SP: +" + str(item.starting_sp_bonus) + "\n"
		if item.wall_crush_damage_bonus != 0: tip += "Wall Crush Dmg: +" + str(item.wall_crush_damage_bonus)
		
		icon.tooltip_text = tip 
		eq_grid.add_child(icon)
