extends Node

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

# Store current values in memory
var settings_data: Dictionary = {
	"audio": {
		"Master": 1.0,
		"Music": 1.0,
		"SFX": 1.0
	},
	"video": {
		"fullscreen": false,
		"brightness": 0.0,
		"contrast": 1.0
	}
}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var err: Error = config.load(SAVE_PATH)
	
	# If file doesn't exist (first run), apply defaults and save
	if err != OK:
		apply_all_settings()
		save_settings()
		return
	
	# Load Audio
	settings_data.audio.Master = config.get_value("audio", "Master", 1.0)
	settings_data.audio.Music = config.get_value("audio", "Music", 1.0)
	settings_data.audio.SFX = config.get_value("audio", "SFX", 1.0)
	
	# Load Video
	settings_data.video.fullscreen = config.get_value("video", "fullscreen", false)
	settings_data.video.brightness = config.get_value("video", "brightness", 0.0)
	settings_data.video.contrast = config.get_value("video", "contrast", 1.0)
	
	apply_all_settings()

func save_settings() -> void:
	# Write memory to file
	config.set_value("audio", "Master", settings_data.audio.Master)
	config.set_value("audio", "Music", settings_data.audio.Music)
	config.set_value("audio", "SFX", settings_data.audio.SFX)
	
	config.set_value("video", "fullscreen", settings_data.video.fullscreen)
	config.set_value("video", "brightness", settings_data.video.brightness)
	config.set_value("video", "contrast", settings_data.video.contrast)
	
	config.save(SAVE_PATH)

func apply_all_settings() -> void:
	_apply_volume("Master", settings_data.audio.Master)
	_apply_volume("Music", settings_data.audio.Music)
	_apply_volume("SFX", settings_data.audio.SFX)
	
	# Defer visual application so GlobalCinematics autoload finishes _ready() first
	call_deferred("_apply_visuals")

func _apply_visuals() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("--server"):
		if settings_data.video.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if GlobalCinematics:
		GlobalCinematics.set_brightness(float(settings_data.video.brightness))
		GlobalCinematics.set_contrast(float(settings_data.video.contrast))

# --- PUBLIC FUNCTIONS ---

func update_volume(bus_name: String, linear_value: float) -> void:
	if settings_data.audio.has(bus_name):
		settings_data.audio[bus_name] = linear_value
	_apply_volume(bus_name, linear_value)
	save_settings()

func update_visual(key: String, value: float) -> void:
	if settings_data.video.has(key):
		settings_data.video[key] = value
	if GlobalCinematics:
		if key == "brightness":
			GlobalCinematics.set_brightness(value)
		elif key == "contrast":
			GlobalCinematics.set_contrast(value)
	save_settings()

func update_fullscreen(enabled: bool) -> void:
	settings_data.video.fullscreen = enabled
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func get_saved_volume(bus_name: String) -> float:
	return float(settings_data.audio.get(bus_name, 1.0))

func get_saved_visual(key: String, default_val: float) -> float:
	return float(settings_data.video.get(key, default_val))

# --- INTERNAL HELPERS ---

func _apply_volume(bus_name: String, linear_val: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
		AudioServer.set_bus_mute(bus_idx, linear_val < 0.05)
