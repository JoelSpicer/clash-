extends CanvasLayer

@onready var filter: ColorRect = $ScreenFilter

var user_brightness: float = 0.0
var user_contrast: float = 1.0

var base_vignette: float = 0.2
var danger_vignette_boost: float = 0.0

var base_aberration: float = 0.002
var danger_aberration_boost: float = 0.0


func _ready() -> void:
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_visuals()


func _update_visuals() -> void:
	if not filter or not (filter.material is ShaderMaterial):
		return
	var mat: ShaderMaterial = filter.material as ShaderMaterial
	var total_vignette: float = clampf(base_vignette + danger_vignette_boost, 0.0, 1.0)
	mat.set_shader_parameter("vignette_intensity", total_vignette)

	var total_aberration: float = clampf(base_aberration + danger_aberration_boost, 0.0, 0.1)
	mat.set_shader_parameter("aberration_amount", total_aberration)


func set_danger_vignette(active: bool) -> void:
	var target_vignette_boost: float = 0.45 if active else 0.0
	var target_aberration_boost: float = 0.008 if active else 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.tween_method(func(val: float) -> void:
		danger_vignette_boost = val
		_update_visuals()
	, danger_vignette_boost, target_vignette_boost, 1.5)

	tween.tween_method(func(val: float) -> void:
		danger_aberration_boost = val
		_update_visuals()
	, danger_aberration_boost, target_aberration_boost, 1.5)


func reset_visuals() -> void:
	danger_vignette_boost = 0.0
	danger_aberration_boost = 0.0

	if filter and filter.material is ShaderMaterial:
		var mat: ShaderMaterial = filter.material as ShaderMaterial
		var cur_sat: float = float(mat.get_shader_parameter("saturation"))
		var t: Tween = create_tween()
		t.tween_method(func(val: float) -> void: mat.set_shader_parameter("saturation", val), cur_sat, 1.0, 0.5)

		mat.set_shader_parameter("brightness", user_brightness)
		mat.set_shader_parameter("contrast", user_contrast)
		_update_visuals()


func set_brightness(value: float) -> void:
	user_brightness = value
	if filter and filter.material is ShaderMaterial:
		(filter.material as ShaderMaterial).set_shader_parameter("brightness", user_brightness)


func set_contrast(value: float) -> void:
	user_contrast = value
	if filter and filter.material is ShaderMaterial:
		(filter.material as ShaderMaterial).set_shader_parameter("contrast", user_contrast)


func apply_finisher_effect() -> void:
	if filter and filter.material is ShaderMaterial:
		var mat: ShaderMaterial = filter.material as ShaderMaterial
		var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(func(val: float) -> void: mat.set_shader_parameter("saturation", val), 1.0, 0.0, 0.1)
