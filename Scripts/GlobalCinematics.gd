extends CanvasLayer

@onready var filter = $ScreenFilter

# --- SETTINGS ---
var user_brightness: float = 0.0
var user_contrast: float = 1.0

# --- VIGNETTE VARS ---
var base_vignette: float = 0.2        # Standard Menu/Game look
var danger_vignette_boost: float = 0.0

# --- ABERRATION VARS (NEW) ---
var base_aberration: float = 0.002    # Subtle constant effect (Try 0.002 - 0.004)
var danger_aberration_boost: float = 0.0

func _ready():
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_visuals()

# --- CENTRAL UPDATE FUNCTION ---
# This ensures Base Settings + Danger Boosts always combine correctly
func _update_visuals():
	if not filter or not filter.material: return
	
	# 1. Calculate & Apply Vignette
	var total_vignette = clamp(base_vignette + danger_vignette_boost, 0.0, 1.0)
	filter.material.set_shader_parameter("vignette_intensity", total_vignette)
	
	# 2. Calculate & Apply Aberration
	var total_aberration = clamp(base_aberration + danger_aberration_boost, 0.0, 0.1)
	filter.material.set_shader_parameter("aberration_amount", total_aberration)

# --- DANGER LOGIC (UPDATED) ---
func set_danger_vignette(active: bool):
	var target_vignette_boost = 0.45 if active else 0.0
	var target_aberration_boost = 0.008 if active else 0.0 
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate Vignette Boost
	tween.tween_method(func(val): 
		danger_vignette_boost = val
		_update_visuals() # Call the central update
	, danger_vignette_boost, target_vignette_boost, 1.5)
	
	# Animate Aberration Boost
	tween.tween_method(func(val):
		danger_aberration_boost = val
		_update_visuals() # Call the central update
	, danger_aberration_boost, target_aberration_boost, 1.5)

# --- RESET LOGIC (UPDATED) ---
func reset_visuals():
	# 1. Stop active tweens so they don't overwrite us
	var tween = create_tween()
	tween.kill()
	
	# 2. Reset Boosts to 0
	danger_vignette_boost = 0.0
	danger_aberration_boost = 0.0
	
	if filter.material:
		# 3. Reset Gameplay Effects (Saturation)
		var t = create_tween()
		t.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			filter.material.get_shader_parameter("saturation"), 1.0, 0.5)
			
		# 4. Re-apply User Settings
		filter.material.set_shader_parameter("brightness", user_brightness)
		filter.material.set_shader_parameter("contrast", user_contrast)
		
		# 5. Apply Base Visuals (Vignette + Aberration)
		_update_visuals()

# --- SETTINGS HELPERS ---
func set_brightness(value: float):
	user_brightness = value
	if filter.material: filter.material.set_shader_parameter("brightness", user_brightness)

func set_contrast(value: float):
	user_contrast = value
	if filter.material: filter.material.set_shader_parameter("contrast", user_contrast)

func apply_finisher_effect():
	if filter.material:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(func(val): filter.material.set_shader_parameter("saturation", val), 
			1.0, 0.0, 0.1)
