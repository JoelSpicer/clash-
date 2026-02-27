extends CanvasLayer

@onready var darkener = $Darkener
@onready var sensei_text = $MessageBox/MarginContainer/VBoxContainer/SenseiText
@onready var continue_btn = $MessageBox/MarginContainer/VBoxContainer/ContinueButton

# We fetch the BattleUI dynamically so we can locate the UI elements
@onready var battle_ui = $"../TestArena/BattleUI"

signal tutorial_message_closed

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	continue_btn.pressed.connect(_on_continue_pressed)
	
	# Initialize Shader default values
	if darkener.material:
		darkener.material.set_shader_parameter("center", Vector2(0.5, 0.5))
		darkener.material.set_shader_parameter("radius_px", 0.0) # Start closed

func show_message(text: String, target_node: Control = null):
	visible = true
	sensei_text.text = "[center]" + text + "[/center]"
	
	# Pause the background action so the player can read
	get_tree().paused = true 
	
	if darkener.material:
		var screen_size = get_viewport().get_visible_rect().size
		darkener.material.set_shader_parameter("screen_size", screen_size)
		
		if target_node != null:
			_move_spotlight(target_node)
		else:
			var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_method(_set_spotlight_radius, darkener.material.get_shader_parameter("radius_px"), 0.0, 0.5)

func _move_spotlight(target_node: Control):
	var target_radius: float = 200.0 
	
	# If it's a wide container like the hand, make the hole bigger!
	if target_node.name == "ButtonGrid":
		target_radius = 280.0
		
	# Find the global center of the UI element
	var center_pos = target_node.global_position + (target_node.size / 2.0)
	var screen_size = get_viewport().get_visible_rect().size
	
	# Convert pixel position to UV coordinates (0.0 to 1.0 format)
	var target_uv = center_pos / screen_size
	
	var start_uv = darkener.material.get_shader_parameter("center")
	var start_rad = darkener.material.get_shader_parameter("radius_px")
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_spotlight_center, start_uv, target_uv, 0.6)
	tween.tween_method(_set_spotlight_radius, start_rad, target_radius, 0.6)

# --- Tween Helper Functions ---
func _set_spotlight_center(uv: Vector2):
	darkener.material.set_shader_parameter("center", uv)

func _set_spotlight_radius(r: float):
	darkener.material.set_shader_parameter("radius_px", r)

func _on_continue_pressed():
	visible = false
	get_tree().paused = false
	
	# Optional: Reset the spotlight so it sweeps in from the center next time
	if darkener.material:
		darkener.material.set_shader_parameter("radius_px", 0.0) 
		
	emit_signal("tutorial_message_closed")
