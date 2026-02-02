extends Control

# --- NODES ---
# Ensure these names match your Scene Tree exactly
@onready var title_label = $InnerMargin/VBox/TitleLabel
@onready var type_icon = $InnerMargin/VBox/IconContainer/TypeIcon
@onready var stats_label = $InnerMargin/VBox/StatsLabel
@onready var cost_label = $InnerMargin/VBox/CostPanel/CostLabel
@onready var card_border = $CardBorder
@onready var card_background = $CardBackground

# --- DATA STORAGE ---
var _pending_action: ActionData = null
var _pending_cost: int = -1

# --- STYLING CONSTANTS ---
const COL_OFFENCE = Color("#ff6666") 
const COL_DEFENCE = Color("#66a3ff") 
const COL_UTIL = Color("#cfcfcf")    

func _ready():
	# When the node finishes loading, check if we have data waiting
	if _pending_action:
		set_card_data(_pending_action, _pending_cost)

func set_card_data(action: ActionData, override_cost: int = -1):
	# 1. Store data (so we can use it later if the node isn't ready yet)
	_pending_action = action
	_pending_cost = override_cost
	
	# 2. Silent Safety Check
	# If variables are not loaded yet, stop here. 
	# The _ready() function will trigger this again automatically.
	if not title_label:
		return

	# --- RENDER LOGIC ---
	
	# Basic Title
	title_label.text = action.display_name
	
	# Cost Logic
	var final_cost = action.cost
	if override_cost != -1: final_cost = override_cost
	
	if cost_label:
		cost_label.text = str(final_cost) + " SP"
		if override_cost != -1 and override_cost < action.cost:
			cost_label.modulate = Color(0.5, 1.0, 0.5) 
		else:
			cost_label.modulate = Color(1, 1, 1) 
			
		var cost_bg = StyleBoxFlat.new()
		cost_bg.bg_color = Color(0, 0, 0, 0.6)
		cost_bg.set_corner_radius_all(6)
		if has_node("InnerMargin/VBox/CostPanel"):
			$InnerMargin/VBox/CostPanel.add_theme_stylebox_override("panel", cost_bg)

	# Visual Theme (Border & Icons)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(6)
	style.set_corner_radius_all(12)
	
	type_icon.text = "" 
	stats_label.text = ""
	
	if action.type == ActionData.Type.OFFENCE:
		style.border_color = COL_OFFENCE
		type_icon.text = "⚔️"
		if action.damage > 4: type_icon.text = "💥"
		stats_label.modulate = COL_OFFENCE
		
	elif action.type == ActionData.Type.DEFENCE:
		style.border_color = COL_DEFENCE
		type_icon.text = "🛡️"
		if action.dodge_value > 0: type_icon.text = "💨"
		stats_label.modulate = COL_DEFENCE
	
	if action.heal_value > 0:
		type_icon.text = "❤️"
		stats_label.modulate = Color.GREEN_YELLOW
		
	if action.statuses_to_apply.size() > 0:
		if action.damage == 0 and action.block_value == 0:
			type_icon.text = "☠️"
			stats_label.modulate = Color.PURPLE

	# Description Logic
	if action.description and action.description != "":
		stats_label.text = "[center]" + action.description + "[/center]"
	else:
		var parts = []
		if action.damage > 0: parts.append("[color=#ff9999]" + str(action.damage) + " DMG[/color]")
		if action.block_value > 0: parts.append("[color=#99ccff]" + str(action.block_value) + " BLOCK[/color]")
		if action.dodge_value > 0: parts.append("[color=#99ccff]" + str(action.dodge_value) + " DODGE[/color]")
		if action.heal_value > 0: parts.append("[color=#aaffaa]+" + str(action.heal_value) + " HP[/color]")
		
		for s in action.statuses_to_apply:
			var status_name = s.get("name", "Effect")
			var duration = s.get("duration", 0)
			var status_text = "Apply " + str(status_name)
			if duration > 0: status_text += " (" + str(duration) + ")"
			parts.append(status_text)
			
		stats_label.text = "[center]" + "\n".join(parts) + "[/center]"

	card_border.add_theme_stylebox_override("panel", style)
	
	# HIDE ICON FOR CLASSES (Optional polish)
	if action.display_name.begins_with("CLASS:"):
		$InnerMargin/VBox/IconContainer.visible = false
	else:
		$InnerMargin/VBox/IconContainer.visible = true
