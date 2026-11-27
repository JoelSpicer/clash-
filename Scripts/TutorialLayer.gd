extends CanvasLayer

@onready var darkener: ColorRect = $Darkener
@onready var sensei_text: RichTextLabel = $MessageBox/MarginContainer/VBoxContainer/SenseiText
@onready var continue_btn: Button = $MessageBox/MarginContainer/VBoxContainer/ContinueButton

# We fetch the BattleUI dynamically so we can locate the UI elements
@onready var battle_ui: Node = $"../CombatArena/BattleUI"

var skip_btn: Button

signal tutorial_message_closed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	continue_btn.pressed.connect(_on_continue_pressed)

	# Build a clean top-right Skip Tutorial button
	skip_btn = Button.new()
	skip_btn.text = "Skip Tutorial"
	skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left = -150.0
	skip_btn.offset_top = 18.0
	skip_btn.offset_right = -18.0
	skip_btn.offset_bottom = 52.0
	skip_btn.pressed.connect(_on_skip_pressed)
	add_child(skip_btn)

	# Initialize Shader default values
	if darkener.material:
		darkener.material.set_shader_parameter("center", Vector2(0.5, 0.5))
		darkener.material.set_shader_parameter("radius_px", 0.0) # Start closed


func show_message(
	text: String,
	target_node: Control = null,
	button_text: String = "Continue",
	allow_skip: bool = true
) -> void:
	visible = true
	sensei_text.text = "[center]" + text + "[/center]"
	continue_btn.text = button_text
	if skip_btn:
		skip_btn.visible = allow_skip

	# Pause the background action so the player can read
	get_tree().paused = true

	if darkener.material:
		var screen_size: Vector2 = get_viewport().get_visible_rect().size
		darkener.material.set_shader_parameter("screen_size", screen_size)

		if target_node != null:
			_move_spotlight(target_node)
		else:
			var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_method(_set_spotlight_radius, darkener.material.get_shader_parameter("radius_px"), 0.0, 0.5)


func _move_spotlight(target_node: Control) -> void:
	var target_radius: float = 200.0

	# If it's a wide container like the hand, make the hole bigger!
	if target_node.name == "ButtonGrid":
		target_radius = 280.0

	# Find the global center of the UI element
	var center_pos: Vector2 = target_node.global_position + (target_node.size / 2.0)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	# Convert pixel position to UV coordinates (0.0 to 1.0 format)
	var target_uv: Vector2 = center_pos / screen_size

	var start_uv: Vector2 = darkener.material.get_shader_parameter("center")
	var start_rad: float = darkener.material.get_shader_parameter("radius_px")

	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_spotlight_center, start_uv, target_uv, 0.6)
	tween.tween_method(_set_spotlight_radius, start_rad, target_radius, 0.6)


# --- Tween Helper Functions ---
func _set_spotlight_center(uv: Vector2) -> void:
	darkener.material.set_shader_parameter("center", uv)


func _set_spotlight_radius(r: float) -> void:
	darkener.material.set_shader_parameter("radius_px", r)


func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false

	# Reset the spotlight so it sweeps in cleanly next time
	if darkener.material:
		darkener.material.set_shader_parameter("radius_px", 0.0)

	emit_signal("tutorial_message_closed")


func _on_skip_pressed() -> void:
	visible = false
	get_tree().paused = false
	if darkener.material:
		darkener.material.set_shader_parameter("radius_px", 0.0)
	TutorialManager.end_tutorial()
