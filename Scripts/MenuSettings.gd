extends Control

@onready var master_slider: HSlider = $CenterContainer/VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/VBoxContainer/SFXSlider

@onready var brightness_slider: HSlider = $CenterContainer/VBoxContainer/BrightnessSlider
@onready var contrast_slider: HSlider = $CenterContainer/VBoxContainer/ContrastSlider
@onready var fullscreen_toggle: CheckButton = $CenterContainer/VBoxContainer/FullscreenToggle

@onready var token_label: Label = $CenterContainer/VBoxContainer/TokenLabel
@onready var reset_tokens_btn: Button = $CenterContainer/VBoxContainer/ResetTokensBtn
@onready var add_tokens_btn: Button = $CenterContainer/VBoxContainer/AddTokensBtn
@onready var minus_tokens_btn: Button = $CenterContainer/VBoxContainer/MinusTokensBtn
@onready var wipe_save_btn: Button = $CenterContainer/VBoxContainer/WipeSaveBtn
@onready var reset_tutorials_btn: Button = $CenterContainer/VBoxContainer/ResetTutorialsBtn
@onready var reset_trials_btn: Button = $CenterContainer/VBoxContainer/ResetTrialsBtn


func _ready() -> void:
	if master_slider:
		_setup_audio_slider(master_slider, "Master")
	if music_slider:
		_setup_audio_slider(music_slider, "Music")
	if sfx_slider:
		_setup_audio_slider(sfx_slider, "SFX")

	if brightness_slider:
		var saved_bright: float = SettingsManager.get_saved_visual("brightness", GlobalCinematics.user_brightness)
		_setup_visual_slider(brightness_slider, "Brightness", -0.5, 0.5, saved_bright)
	if contrast_slider:
		var saved_contrast: float = SettingsManager.get_saved_visual("contrast", GlobalCinematics.user_contrast)
		_setup_visual_slider(contrast_slider, "Contrast", 0.5, 1.5, saved_contrast)
	if fullscreen_toggle:
		fullscreen_toggle.set_pressed_no_signal(bool(SettingsManager.settings_data.video.get("fullscreen", false)))
		fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

	if token_label and RunManager.meta_data:
		_update_token_display()

	if reset_tokens_btn:
		reset_tokens_btn.pressed.connect(_on_reset_tokens_pressed)
	if add_tokens_btn:
		add_tokens_btn.pressed.connect(_on_add_tokens_pressed)
	if minus_tokens_btn:
		minus_tokens_btn.pressed.connect(_on_minus_tokens_pressed)
	if wipe_save_btn:
		wipe_save_btn.pressed.connect(_on_wipe_save_pressed)
	if reset_tutorials_btn:
		reset_tutorials_btn.pressed.connect(_on_reset_tutorials_pressed)
	if reset_trials_btn:
		reset_trials_btn.pressed.connect(_on_reset_trials_pressed)


func _setup_audio_slider(slider: HSlider, bus_name: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05

	if SettingsManager.has_method("get_saved_volume"):
		slider.value = SettingsManager.get_saved_volume(bus_name)
	else:
		var bus_idx: int = AudioServer.get_bus_index(bus_name)
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))

	if not slider.value_changed.is_connected(_on_audio_changed):
		slider.value_changed.connect(_on_audio_changed.bind(bus_name))


func _setup_visual_slider(slider: HSlider, type: String, min_v: float, max_v: float, start_val: float) -> void:
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.05
	slider.value = start_val

	if not slider.value_changed.is_connected(_on_visual_changed):
		slider.value_changed.connect(_on_visual_changed.bind(type))


func _update_token_display() -> void:
	if token_label and RunManager.meta_data:
		token_label.text = "Circuit Tokens: " + str(RunManager.meta_data.circuit_tokens)


func _on_reset_tokens_pressed() -> void:
	if RunManager.meta_data:
		RunManager.meta_data.circuit_tokens = 0
		RunManager._save_global_data()
		_update_token_display()
		print("DEBUG: Circuit Tokens reset to 0.")


func _on_add_tokens_pressed() -> void:
	if RunManager.meta_data:
		RunManager.meta_data.circuit_tokens += 1
		RunManager._save_global_data()
		_update_token_display()
		print("DEBUG: Added 1 Circuit Token.")


func _on_minus_tokens_pressed() -> void:
	if RunManager.meta_data:
		RunManager.meta_data.circuit_tokens = maxi(0, RunManager.meta_data.circuit_tokens - 1)
		RunManager._save_global_data()
		_update_token_display()
		print("DEBUG: Removed 1 Circuit Token.")


func _on_wipe_save_pressed() -> void:
	if RunManager.has_method("wipe_global_save"):
		RunManager.wipe_global_save()
		_update_token_display()


func _on_audio_changed(value: float, bus_name: String) -> void:
	if SettingsManager.has_method("update_volume"):
		SettingsManager.update_volume(bus_name, value)
	else:
		var bus_idx: int = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		AudioServer.set_bus_mute(bus_idx, value < 0.05)


func _on_visual_changed(value: float, type: String) -> void:
	if type == "Brightness":
		SettingsManager.update_visual("brightness", value)
	elif type == "Contrast":
		SettingsManager.update_visual("contrast", value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	SettingsManager.update_fullscreen(enabled)


func _on_reset_tutorials_pressed() -> void:
	if RunManager.meta_data:
		RunManager.meta_data.seen_menu_tutorials.clear()
		if RunManager.has_method("_save_global_data"):
			RunManager._save_global_data()
		print("DEBUG: All menu tutorials have been reset!")


func _on_reset_trials_pressed() -> void:
	if RunManager.meta_data:
		RunManager.meta_data.completed_trials.clear()
		if RunManager.has_method("_save_global_data"):
			RunManager._save_global_data()
		print("DEBUG: All Dojo Trials progress has been reset!")
