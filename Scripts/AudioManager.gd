extends Node

# --- ASSET LIBRARY ---
# Note: These now point to your .tres resources, NOT .wav files!
var sounds = {
	# SFX (Keep these pointing to .wav)
	"ui_hover": preload("res://Audio/UI/hover.wav"),
	"ui_click": preload("res://Audio/UI/click.wav"),
	"hit_light": preload("res://Audio/Combat/hit_light.wav"),
	"hit_heavy": preload("res://Audio/Combat/hit_heavy.wav"),
	"block": preload("res://Audio/Combat/block.wav"),
	"clash": preload("res://Audio/Combat/clash.wav"),
	
	# MUSIC (Point these to the .tres files you made in Phase 3)
	"menu_theme": preload("res://Audio/Music/SongMenus.tres"),
	"music_ring": preload("res://Audio/Music/SongRing.tres"),
	"music_dojo": preload("res://Audio/Music/SongDojo.tres"),
	"music_street": preload("res://Audio/Music/SongStreet.tres"),
	"battle_theme": preload("res://Audio/Music/SongRing.tres"),
}

var is_danger_mode: bool = false
var heartbeat_player: AudioStreamPlayer

# --- NODES ---
# This connects to the OvaniPlayer child node we added in Phase 1
@onready var music_player = $MusicPlayer 

# --- SFX POOL ---
var pool_size = 10
var sfx_players: Array[AudioStreamPlayer] = []
var current_music_key: String = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS 

	# 1. Setup SFX Pool (Unchanged)
	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	
	# 2. Setup Heartbeat (Unchanged)
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.stream = preload("res://Audio/SFX/heartbeat.wav")
	heartbeat_player.bus = "SFX"
	heartbeat_player.volume_db = 5.0 
	add_child(heartbeat_player)

# --- PUBLIC FUNCTION: MUSIC ---
func play_music(key: String, fade_duration: float = 2.0):
	if not sounds.has(key):
		print("Music track not found: " + key)
		return
		
	if current_music_key == key: return
	current_music_key = key
	
	var song_resource = sounds[key]
	
	if music_player:
		# CORRECT FUNCTION NAME:
		music_player.PlaySongNow(song_resource, fade_duration)

func set_music_intensity(target_val: float, fade_time: float = 2.0):
	if music_player:
		# The plugin handles the lerp automatically!
		music_player.FadeIntensity(clamp(target_val, 0.0, 1.0), fade_time)

func stop_music(fade_duration: float = 2.0):
	if music_player:
		# CHANGE THIS:
		# music_player.Stop(fade_duration)
		
		# TO THIS:
		music_player.StopSongsNow(fade_duration)
		
	current_music_key = ""


# --- PUBLIC FUNCTION: LOCATION MUSIC ---
func play_location_music(env_name: String):
	var target_key = "battle_theme"
	match env_name.to_lower():
		"ring": target_key = "music_ring"
		"dojo": target_key = "music_dojo"
		"street": target_key = "music_street"
	
	play_music(target_key, 2.0)

# --- PUBLIC FUNCTION: SFX (Keep exactly as is) ---
func play_sfx(key: String, pitch_variance: float = 0.0):
	if not sounds.has(key): return
	var stream = sounds[key]
	var player = _get_available_player()
	if player:
		player.stream = stream
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance) if pitch_variance > 0 else 1.0
		player.play()

func _get_available_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing: return p
	var p = sfx_players.pop_front()
	sfx_players.append(p)
	return p

func set_danger_mode(active: bool):
	if active == is_danger_mode: return
	is_danger_mode = active
	
	if active:
		# 1. Start the heartbeat
		heartbeat_player.play()
		_pulse_vignette()
		# 2. Maybe lower the volume slightly to make the scene feel 'quiet' and 'scary'
		music_player.FadeVolume(-5.0, 1.0) 
	else:
		# 1. Stop heartbeat
		heartbeat_player.stop()
		# 2. Restore full volume
		music_player.FadeVolume(0.0, 1.0)

# This is the function RunManager is looking for!
# Inside AudioManager.gd

# Inside AudioManager.gd

func reset_audio_state():
	set_danger_mode(false) 
	set_music_intensity(0.0, 0.5)
	
	if GlobalCinematics.has_method("set_danger_vignette"):
		GlobalCinematics.set_danger_vignette(false)
		
	# CHANGE THIS AS WELL:
	if music_player: 
		# music_player.Stop(0.5)  <-- WRONG
		music_player.StopSongsNow(0.5) # <-- CORRECT

# Inside AudioManager.gd

func _pulse_vignette():
	if not is_danger_mode: return
	
	# Pulse the vignette intensity up and down slightly
	var tween = create_tween()
	tween.tween_method(func(v): 
		GlobalCinematics.danger_vignette_boost = v
		# CHANGE THIS: Was _update_vignette_shader()
		GlobalCinematics._update_visuals() 
	, 0.45, 0.55, 0.4).set_trans(Tween.TRANS_SINE) # Pulse up
	
	tween.tween_method(func(v): 
		GlobalCinematics.danger_vignette_boost = v
		# CHANGE THIS: Was _update_vignette_shader()
		GlobalCinematics._update_visuals()
	, 0.55, 0.45, 0.4).set_trans(Tween.TRANS_SINE) # Pulse down
	
	# Loop the pulse as long as we are in danger
	tween.tween_callback(_pulse_vignette)
