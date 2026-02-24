extends Control

# --- AUDIO REFERENCES ---
@onready var master_slider = $CenterContainer/VBoxContainer/MasterSlider
@onready var music_slider = $CenterContainer/VBoxContainer/MusicSlider
@onready var sfx_slider = $CenterContainer/VBoxContainer/SFXSlider 

# --- VISUAL REFERENCES ---
@onready var brightness_slider = $CenterContainer/VBoxContainer/BrightnessSlider
@onready var contrast_slider = $CenterContainer/VBoxContainer/ContrastSlider

func _ready():
	# 1. Setup Audio
	if master_slider: _setup_audio_slider(master_slider, "Master")
	if music_slider: _setup_audio_slider(music_slider, "Music")
	if sfx_slider: _setup_audio_slider(sfx_slider, "SFX")

	# 2. Setup Visuals
	if brightness_slider:
		_setup_visual_slider(brightness_slider, "Brightness", -0.5, 0.5, GlobalCinematics.user_brightness)
	if contrast_slider:
		_setup_visual_slider(contrast_slider, "Contrast", 0.5, 1.5, GlobalCinematics.user_contrast)

# --- SETUP HELPER: AUDIO ---
func _setup_audio_slider(slider: HSlider, bus_name: String):
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	
	# Get initial value safely
	if SettingsManager.has_method("get_saved_volume"):
		slider.value = SettingsManager.get_saved_volume(bus_name)
	else:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	
	# Connect signal using .bind() instead of a lambda function
	# This passes 'bus_name' as an extra argument to the function
	if not slider.value_changed.is_connected(_on_audio_changed):
		slider.value_changed.connect(_on_audio_changed.bind(bus_name))

# --- SETUP HELPER: VISUALS ---
func _setup_visual_slider(slider: HSlider, type: String, min_v: float, max_v: float, start_val: float):
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.05
	slider.value = start_val
	
	# Connect signal using .bind()
	if not slider.value_changed.is_connected(_on_visual_changed):
		slider.value_changed.connect(_on_visual_changed.bind(type))

# --- EVENT HANDLER: AUDIO ---
func _on_audio_changed(value: float, bus_name: String):
	if SettingsManager.has_method("update_volume"):
		SettingsManager.update_volume(bus_name, value)
	else:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		AudioServer.set_bus_mute(bus_idx, value < 0.05)

# --- EVENT HANDLER: VISUALS ---
func _on_visual_changed(value: float, type: String):
	if type == "Brightness":
		GlobalCinematics.set_brightness(value)
	elif type == "Contrast":
		GlobalCinematics.set_contrast(value)
