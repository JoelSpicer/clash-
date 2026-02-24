extends CanvasLayer

@onready var filter = $ScreenFilter

func _ready():
	# Ensure it doesn't block mouse clicks
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Set default look
	reset_visuals()

func reset_visuals():
	if filter.material:
		var tween = create_tween()
		tween.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			filter.material.get_shader_parameter("saturation"), 1.0, 0.5)

func apply_finisher_effect():
	if filter.material:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		# Snap saturation to 0 quickly
		tween.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			1.0, 0.0, 0.1)

# Helper to check if we are ready
func is_ready():
	return filter != null
