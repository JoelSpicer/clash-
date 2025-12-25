extends Control

# UI References (Link these in the Inspector or use unique names)
@onready var background = $Background
@onready var cost_label = $VBoxContainer/Header/CostLabel
@onready var name_label = $VBoxContainer/Header/NameLabel
@onready var art_rect = $VBoxContainer/Art
@onready var stat_label = $VBoxContainer/StatsRow/StatLabel
@onready var desc_label = $VBoxContainer/Description

# Colors for the Background (You can tweak these hex codes)
const OFFENCE_COLOR = Color("#d14d4d") # Red
const DEFENCE_COLOR = Color("#4d8ad1") # Blue

func set_card_data(action: ActionData):
	# 1. Set Basic Text
	name_label.text = action.display_name
	cost_label.text = str(action.cost) + " SP"
	desc_label.text = action.description
	
	# 2. Set Art (if it exists, otherwise use a placeholder color)
	if action.icon:
		art_rect.texture = action.icon
	
	# 3. Set Color based on Type
	var bg_style = StyleBoxFlat.new()
	if action.type == ActionData.Type.OFFENCE:
		bg_style.bg_color = OFFENCE_COLOR
	else:
		bg_style.bg_color = DEFENCE_COLOR
	
	# Add a nice corner radius
	bg_style.set_corner_radius_all(10)
	background.add_theme_stylebox_override("panel", bg_style)
	
	# 4. Compile Stats String (e.g., "3 DMG | 2 BLK")
	var stats_text = ""
	
	if action.damage > 0:
		stats_text += str(action.damage) + " DMG  "
	if action.block_value > 0:
		stats_text += str(action.block_value) + " BLK  "
	if action.dodge_value > 0:
		stats_text += str(action.dodge_value) + " DDG  "
	if action.heal_value > 0:
		stats_text += str(action.heal_value) + " HEAL "
	
	if action.tiring > 0:
		stats_text += str(action.tiring) + " TIRE "
	if action.retaliate:
		stats_text += "RETAL "
	if action.feint:
		stats_text += "FEINT "
		
	# NEW: Injure
	if action.injure:
		stats_text += "INJURE "
		
	stat_label.text = stats_text
