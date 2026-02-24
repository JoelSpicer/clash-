extends CanvasLayer

@onready var filter = $ScreenFilter

# Default User Settings
var user_brightness: float = 0.0
var user_contrast: float = 1.0

func _ready():
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_visuals()

# --- NEW: SETTINGS FUNCTIONS ---
func set_brightness(value: float):
	user_brightness = value
	if filter.material:
		filter.material.set_shader_parameter("brightness", user_brightness)

func set_contrast(value: float):
	user_contrast = value
	if filter.material:
		filter.material.set_shader_parameter("contrast", user_contrast)

func reset_visuals():
	if filter.material:
		# Reset Saturation (Gameplay effect)
		var tween = create_tween()
		tween.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			filter.material.get_shader_parameter("saturation"), 1.0, 0.5)
			
		# Ensure User Settings are re-applied (in case they were tweened)
		filter.material.set_shader_parameter("brightness", user_brightness)
		filter.material.set_shader_parameter("contrast", user_contrast)

func apply_finisher_effect():
	if filter.material:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			1.0, 0.0, 0.1)
