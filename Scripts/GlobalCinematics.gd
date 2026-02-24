extends CanvasLayer

@onready var filter = $ScreenFilter

# Default User Settings
var user_brightness: float = 0.0
var user_contrast: float = 1.0
var danger_vignette_boost: float = 0.0
var vignette_intensity: float = 0.2
var danger_aberration_boost: float = 0.0

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

# Inside GlobalCinematics.gd

func reset_visuals():
	# 1. Kill any active "Danger" tweens running on the cinematic system
	# This prevents the pulse loop from fighting us
	var tween = create_tween()
	tween.kill()
	
	# 2. Reset the boost variables
	danger_vignette_boost = 0.0
	danger_aberration_boost = 0.0
	
	if filter.material:
		# 3. EXISTING: Reset Saturation
		var t = create_tween()
		t.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			filter.material.get_shader_parameter("saturation"), 1.0, 0.5)
			
		# 4. EXISTING: User Settings
		filter.material.set_shader_parameter("brightness", user_brightness)
		filter.material.set_shader_parameter("contrast", user_contrast)
		
		# 5. NEW: Reset Danger Effects
		# We must manually call this to apply the 0.0 boost we just set
		_update_vignette_shader() 
		filter.material.set_shader_parameter("aberration_amount", 0.0)

func apply_finisher_effect():
	if filter.material:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			1.0, 0.0, 0.1)

func set_danger_vignette(active: bool):
	var target_vignette = 0.45 if active else 0.0
	var target_aberration = 0.008 if active else 0.0 # Subtle but effective
	
	var tween = create_tween()
	tween.set_parallel(true) # Let both animations happen at once
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate Vignette
	tween.tween_method(func(val): 
		danger_vignette_boost = val
		_update_vignette_shader(),
		danger_vignette_boost, target_vignette, 1.5
	)
	
	# NEW: Animate Chromatic Aberration
	tween.tween_method(func(val):
		danger_aberration_boost = val
		if filter.material:
			filter.material.set_shader_parameter("aberration_amount", val)
	, danger_aberration_boost, target_aberration, 1.5)

func _update_vignette_shader():
	if filter and filter.material:
		# We combine the base menu value with the temporary adrenaline boost
		var total_vignette = clamp(vignette_intensity + danger_vignette_boost, 0.0, 1.0)
		
		# Make sure the shader parameter string "vignette_intensity" 
		# matches the 'uniform' name inside your .gdshader file!
		filter.material.set_shader_parameter("vignette_intensity", total_vignette)

# Call this from your Options Menu to change the permanent vignette level
func change_base_vignette(new_val: float):
	vignette_intensity = new_val
	_update_vignette_shader()
