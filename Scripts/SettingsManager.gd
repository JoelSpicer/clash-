extends Node

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

# Store current values in memory
var settings_data = {
	"audio": {
		"Master": 1.0,
		"Music": 1.0,
		"SFX": 1.0
	},
	"video": {
		"fullscreen": false
	}
}

func _ready():
	load_settings()

func load_settings():
	var err = config.load(SAVE_PATH)
	
	# If file doesn't exist (first run), apply defaults and save
	if err != OK:
		apply_all_settings()
		save_settings()
		return
	
	# Load Audio
	settings_data.audio.Master = config.get_value("audio", "Master", 1.0)
	settings_data.audio.Music = config.get_value("audio", "Music", 1.0)
	settings_data.audio.SFX = config.get_value("audio", "SFX", 1.0)
	
	# Load Video (Future proofing)
	settings_data.video.fullscreen = config.get_value("video", "fullscreen", false)
	
	apply_all_settings()

func save_settings():
	# Write memory to file
	config.set_value("audio", "Master", settings_data.audio.Master)
	config.set_value("audio", "Music", settings_data.audio.Music)
	config.set_value("audio", "SFX", settings_data.audio.SFX)
	
	config.set_value("video", "fullscreen", settings_data.video.fullscreen)
	
	config.save(SAVE_PATH)

func apply_all_settings():
	_apply_volume("Master", settings_data.audio.Master)
	_apply_volume("Music", settings_data.audio.Music)
	_apply_volume("SFX", settings_data.audio.SFX)
	
	# Video
	# DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings_data.video.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

# --- PUBLIC FUNCTIONS ---

func update_volume(bus_name: String, linear_value: float):
	# 1. Update Memory
	if settings_data.audio.has(bus_name):
		settings_data.audio[bus_name] = linear_value
		
	# 2. Apply Immediately
	_apply_volume(bus_name, linear_value)
	
	# 3. Save to Disk
	save_settings()

func get_saved_volume(bus_name: String) -> float:
	return settings_data.audio.get(bus_name, 1.0)

# --- INTERNAL HELPERS ---

func _apply_volume(bus_name: String, linear_val: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
		AudioServer.set_bus_mute(bus_idx, linear_val < 0.05)
