extends Control

# UI References
@onready var background = $Background
@onready var cost_label = $VBoxContainer/Header/CostLabel
@onready var name_label = $VBoxContainer/Header/NameLabel
@onready var art_rect = $VBoxContainer/Art
@onready var stat_label = $VBoxContainer/StatsRow/StatLabel
@onready var desc_label = $VBoxContainer/Description

# Colors
const OFFENCE_COLOR = Color("#d14d4d") # Red
const DEFENCE_COLOR = Color("#4d8ad1") # Blue

func set_card_data(action: ActionData, override_cost: int = -1):
	# 1. Set Basic Text
	name_label.text = action.display_name
	
	# Determine Cost Display
	var final_cost = action.cost
	if override_cost != -1:
		final_cost = override_cost
		
	cost_label.text = str(final_cost) + " SP"
	desc_label.text = action.description
	
	if final_cost == 0 and override_cost == -1:
		cost_label.text = "" # Hide for classes
	else:
		cost_label.text = str(final_cost) + " SP"
	
	# 2. Set Art
	if action.icon:
		art_rect.texture = action.icon
	
	# 3. Set Color based on Type
	var bg_style = StyleBoxFlat.new()
	if action.type == ActionData.Type.OFFENCE:
		bg_style.bg_color = OFFENCE_COLOR
	else:
		bg_style.bg_color = DEFENCE_COLOR
	
	bg_style.set_corner_radius_all(10)
	background.add_theme_stylebox_override("panel", bg_style)
	
	# 4. Compile Stats String
	var stats_text = ""
	
	if action.damage > 0: stats_text += str(action.damage) + " DMG  "
	if action.block_value > 0: stats_text += str(action.block_value) + " BLK  "
	if action.dodge_value > 0: stats_text += str(action.dodge_value) + " DDG  "
	if action.heal_value > 0: stats_text += str(action.heal_value) + " HEAL "
		
	# Recover Logic (Visuals matching Game Logic)
	var final_rec = action.recover_value
	if action.type == ActionData.Type.DEFENCE:
		final_rec += 1
	if final_rec > 0: stats_text += str(final_rec) + " REC "
	
	# Boolean Tags
	if action.tiring > 0: stats_text += str(action.tiring) + " TIRE "
	if action.retaliate: stats_text += "RETAL "
	if action.feint: stats_text += "FEINT "
	
	# NEW: GENERIC STATUS TEXT
	for effect in action.statuses_to_apply:
		var s_name = effect.get("name", "???").to_upper()
		var s_val = effect.get("amount", 1)
		var is_self = effect.get("self", false)
		
		var prefix = "SELF " if is_self else ""
		var val_str = str(s_val) + " " if s_val > 1 else ""
		
		stats_text += prefix + val_str + s_name + " "
		
	stat_label.text = stats_text
