extends Control

@onready var title_label: Label = $InnerMargin/VBox/TitleLabel
@onready var type_icon: Label = $InnerMargin/VBox/IconContainer/TypeIcon
@onready var stats_label: RichTextLabel = $InnerMargin/VBox/StatsLabel
@onready var cost_label: Label = $InnerMargin/VBox/CostPanel/CostLabel
@onready var card_border: Panel = $CardBorder
@onready var card_background: Control = $CardBackground

var _pending_action: ActionData = null
var _pending_cost: int = -1

const COL_OFFENCE: Color = Color("#ff6666")
const COL_DEFENCE: Color = Color("#66a3ff")
const COL_UTIL: Color = Color("#cfcfcf")


func _ready() -> void:
	if _pending_action:
		set_card_data(_pending_action, _pending_cost)


func set_card_data(action: ActionData, override_cost: int = -1) -> void:
	_pending_action = action
	_pending_cost = override_cost

	if not title_label:
		return

	title_label.text = action.display_name

	var final_cost: int = override_cost if override_cost != -1 else action.cost

	if cost_label:
		cost_label.text = str(final_cost) + " SP"
		if override_cost != -1 and override_cost < action.cost:
			cost_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			cost_label.modulate = Color(1, 1, 1)

		var cost_bg: StyleBoxFlat = StyleBoxFlat.new()
		cost_bg.bg_color = Color(0, 0, 0, 0.6)
		cost_bg.set_corner_radius_all(6)
		if has_node("InnerMargin/VBox/CostPanel"):
			$InnerMargin/VBox/CostPanel.add_theme_stylebox_override("panel", cost_bg)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(6)
	style.set_corner_radius_all(12)

	type_icon.text = ""
	stats_label.text = ""

	if action.type == ActionData.Type.OFFENCE:
		style.border_color = COL_OFFENCE
		type_icon.text = "⚔️"
		if action.damage > 4:
			type_icon.text = "💥"
		stats_label.modulate = COL_OFFENCE
	elif action.type == ActionData.Type.DEFENCE:
		style.border_color = COL_DEFENCE
		type_icon.text = "🛡️"
		if action.dodge_value > 0:
			type_icon.text = "💨"
		stats_label.modulate = COL_DEFENCE

	if action.heal_value > 0:
		type_icon.text = "❤️"
		stats_label.modulate = Color.GREEN_YELLOW

	if action.statuses_to_apply.size() > 0:
		if action.damage == 0 and action.block_value == 0:
			type_icon.text = "☠️"
			stats_label.modulate = Color.PURPLE

	if action.description and action.description != "":
		stats_label.text = "[center]" + action.description.c_unescape() + "[/center]"
	else:
		var parts: Array[String] = []
		if action.damage > 0:
			parts.append("[color=#ff9999]" + str(action.damage) + " DMG[/color]")
		if action.block_value > 0:
			parts.append("[color=#99ccff]" + str(action.block_value) + " BLOCK[/color]")
		if action.dodge_value > 0:
			parts.append("[color=#99ccff]" + str(action.dodge_value) + " DODGE[/color]")
		if action.heal_value > 0:
			parts.append("[color=#aaffaa]+" + str(action.heal_value) + " HP[/color]")

		for s: Dictionary in action.statuses_to_apply:
			var status_name: String = str(s.get("name", "Effect"))
			var duration: int = int(s.get("duration", 0))
			var status_text: String = "Apply " + status_name
			if duration > 0:
				status_text += " (" + str(duration) + ")"
			parts.append(status_text)

		stats_label.text = "[center]" + "\n".join(parts) + "[/center]"

	card_border.add_theme_stylebox_override("panel", style)

	if action.display_name.begins_with("CLASS:"):
		$InnerMargin/VBox/IconContainer.visible = false
	else:
		$InnerMargin/VBox/IconContainer.visible = true
