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
	
	if action.display_name.begins_with("CLASS:"):
		$InnerMargin/VBox/IconContainer.visible = false
		$InnerMargin/VBox/CostPanel.visible = false
		stats_label.add_theme_font_size_override("normal_font_size", 14) # Smaller text
	else:
		$InnerMargin/VBox/IconContainer.visible = true
		$InnerMargin/VBox/CostPanel.visible = true
		stats_label.remove_theme_font_size_override("normal_font_size") # Reset to default
	
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

# 4. DESCRIPTION LOGIC (Rich Text Upgrade)
	
	# Determine the final text string
	var final_text = ""
	
	if action.description and action.description != "":
		final_text = action.description
	else:
		# Auto-generate text for non-class cards
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
			
		final_text = "\n".join(parts)

	# Apply to RichTextLabel
	stats_label.text = "[center]" + final_text + "[/center]"
	
	# Optional: Adjust color based on card type if not manually colored
	if action.type == ActionData.Type.OFFENCE:
		stats_label.modulate = Color(1, 0.9, 0.9) # Slight red tint
	else:
		stats_label.modulate = Color(0.9, 0.9, 1.0) # Slight blue tint

	# Apply the border style
	card_border.add_theme_stylebox_override("panel", style)

# Optional: Reset function if you pool these objects
func clear():
	title_label.text = ""
	type_icon.text = ""
	stats_label.text = ""
