extends Control

# --- NODES ---
@onready var title_label = $InnerMargin/VBox/TitleLabel
@onready var type_icon = $InnerMargin/VBox/IconContainer/TypeIcon
@onready var stats_label = $InnerMargin/VBox/StatsLabel
@onready var cost_label = $InnerMargin/VBox/CostPanel/CostLabel
@onready var card_border = $CardBorder
@onready var card_background = $CardBackground

# --- STYLING CONSTANTS ---
const COL_OFFENCE = Color("#ff6666") # Soft Red
const COL_DEFENCE = Color("#66a3ff") # Soft Blue
const COL_UTIL = Color("#cfcfcf")    # Grey

func set_card_data(action: ActionData, override_cost: int = -1):
	# 1. Basic Title
	title_label.text = action.display_name
	
	# 2. Cost Logic (With Discount Support)
	var final_cost = action.cost
	if override_cost != -1: final_cost = override_cost
	
	if cost_label:
		cost_label.text = str(final_cost) + " SP"
		if override_cost != -1 and override_cost < action.cost:
			cost_label.modulate = Color(0.5, 1.0, 0.5) # Green
		else:
			cost_label.modulate = Color(1, 1, 1) # White
			
		var cost_bg = StyleBoxFlat.new()
		cost_bg.bg_color = Color(0, 0, 0, 0.6)
		cost_bg.set_corner_radius_all(6)
		if has_node("InnerMargin/VBox/CostPanel"):
			$InnerMargin/VBox/CostPanel.add_theme_stylebox_override("panel", cost_bg)

	# 3. Visual Theme (Icons & Colors)
	var style = card_border.get_theme_stylebox("panel").duplicate()
	type_icon.text = "" # Reset
	
	# --- FORCE BORDER VISIBILITY ---
	style.bg_color = Color(0, 0, 0, 0) # Transparent center
	style.set_border_width_all(6)      # Force 6px thickness
	style.set_corner_radius_all(12)    # Force rounded corners
	# -------------------------------
	
	# Set Colors & Icons based on Type
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
	
	# Special Icon Overrides
	if action.heal_value > 0:
		type_icon.text = "❤️"
		stats_label.modulate = Color.GREEN_YELLOW
	if action.statuses_to_apply.size() > 0 and action.damage == 0 and action.block_value == 0:
		type_icon.text = "☠️"
		stats_label.modulate = Color.PURPLE

	# 4. DESCRIPTION TEXT (The Upgrade)
	# Prioritize the written description from the Resource
	if action.description and action.description != "":
		stats_label.text = action.description
	else:
		# Fallback: Auto-generate text if description is empty
		var parts = []
		if action.damage > 0: parts.append(str(action.damage) + " DMG")
		if action.block_value > 0: parts.append(str(action.block_value) + " BLOCK")
		if action.dodge_value > 0: parts.append(str(action.dodge_value) + " DODGE")
		if action.heal_value > 0: parts.append("+" + str(action.heal_value) + " HP")
		
		# Add statuses
		for s in action.statuses_to_apply:
			# We know 's' is a Dictionary, so we just use it directly
			var status_name = s.get("name", "Effect")
			var duration = s.get("duration", 0)
			
			var status_text = "Apply " + str(status_name)
			if duration > 0:
				status_text += " (" + str(duration) + ")"
				
			parts.append(status_text)

		# Join all parts with newlines
		if parts.size() > 0:
			stats_label.text = "\n".join(parts)
			
		#stats_label.text = "\n".join(parts) # Use newlines for lists

	card_border.add_theme_stylebox_override("panel", style)

# Optional: Reset function if you pool these objects
func clear():
	title_label.text = ""
	type_icon.text = ""
	stats_label.text = ""
