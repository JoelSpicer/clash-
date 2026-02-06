extends Node

# --- ASSET LIBRARY ---
var sounds = {
	# SFX (Keep your existing ones)
	"ui_hover": preload("res://Audio/UI/hover.wav"),
	"ui_click": preload("res://Audio/UI/click.wav"),
	"hit_light": preload("res://Audio/Combat/hit_light.wav"),
	"hit_heavy": preload("res://Audio/Combat/hit_heavy.wav"),
	"block": preload("res://Audio/Combat/block.wav"),
	"clash": preload("res://Audio/Combat/clash.wav"),
	
	# MUSIC (Add your music files here)
	"menu_theme": preload("res://Audio/Music/MenuTheme.wav"),
	"battle_theme": preload("res://Audio/Music/BattleTheme.wav"),
}

var is_danger_mode: bool = false
var heartbeat_player: AudioStreamPlayer

# --- SFX POOL ---
var pool_size = 10
var sfx_players: Array[AudioStreamPlayer] = []

# --- MUSIC SYSTEM ---
var music_player_1: AudioStreamPlayer
var music_player_2: AudioStreamPlayer
var active_music_player: AudioStreamPlayer = null
var current_music_key: String = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure audio keeps playing if game pauses

	# 1. Setup SFX Pool
	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
		
	# 2. Setup Music Players (Dual for crossfading)
	music_player_1 = AudioStreamPlayer.new()
	music_player_1.bus = "Music"
	add_child(music_player_1)
	
	music_player_2 = AudioStreamPlayer.new()
	music_player_2.bus = "Music"
	add_child(music_player_2)
	
	active_music_player = music_player_1
	
	# NEW: Setup Heartbeat
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.stream = preload("res://Audio/SFX/heartbeat.wav") # Make sure file exists!
	heartbeat_player.bus = "SFX"
	heartbeat_player.volume_db = 5.0 # Subtle background thump
	add_child(heartbeat_player)
	
# --- PUBLIC FUNCTION: SFX ---
func play_sfx(key: String, pitch_variance: float = 0.0):
	if not sounds.has(key):
		# Optional: Comment out print to avoid spam if files are missing
		# print_debug("Audio Key not found: " + key)
		return
		
	var stream = sounds[key]
	if not stream: return 
	
	var player = _get_available_player()
	if player:
		player.stream = stream
		if pitch_variance > 0:
			player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
		else:
			player.pitch_scale = 1.0
		player.play()

# --- PUBLIC FUNCTION: MUSIC ---
func play_music(key: String, fade_duration: float = 1.0):
	if not sounds.has(key):
		print("Music track not found: " + key)
		return
		
	# Don't restart if it's already playing
	if current_music_key == key: return
	
	current_music_key = key
	var new_stream = sounds[key]
	
	# Identify which player is free
	var next_player = music_player_2 if active_music_player == music_player_1 else music_player_1
	var old_player = active_music_player
	
	# Setup Next Player
	next_player.stream = new_stream
	next_player.volume_db = -80 # Start silent
	next_player.play()
	
	# Fade IN the new track
	var tween_in = create_tween()
	tween_in.tween_property(next_player, "volume_db", 0.0, fade_duration)
	
	# Fade OUT the old track (if playing)
	if old_player.playing:
		var tween_out = create_tween()
		tween_out.tween_property(old_player, "volume_db", -80.0, fade_duration)
		tween_out.tween_callback(old_player.stop) # Stop it when fade finishes
	
	# Swap reference
	active_music_player = next_player

func stop_music(fade_duration: float = 1.0):
	if active_music_player.playing:
		var tween = create_tween()
		tween.tween_property(active_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(active_music_player.stop)
	current_music_key = ""

# --- HELPERS ---
func _get_available_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing: return p
	
	var p = sfx_players.pop_front()
	sfx_players.append(p)
	return p

# --- DANGER STATE LOGIC ---
func set_danger_mode(active: bool):
	# Prevent spamming the same state
	if active == is_danger_mode: return
	is_danger_mode = active
	
	var music_bus_idx = AudioServer.get_bus_index("Music")
	# We assume LowPassFilter is the FIRST effect (index 0) on the Music bus
	var filter = AudioServer.get_bus_effect(music_bus_idx, 0) as AudioEffectLowPassFilter
	
	if not filter:
		print("Error: No LowPassFilter found on Music Bus!")
		return
		
	var tween = create_tween()
	
	if active:
		print(">> DANGER STATE: ON")
		# 1. Muffle Music (Tween Cutoff down to 600Hz)
		tween.tween_property(filter, "cutoff_hz", 600.0, 1.0)
		
		# 2. Start Heartbeat
		heartbeat_player.play()
		
	else:
		print(">> DANGER STATE: OFF")
		# 1. Restore Music (Tween Cutoff up to 20500Hz)
		tween.tween_property(filter, "cutoff_hz", 20500.0, 1.0)
		
		# 2. Stop Heartbeat
		heartbeat_player.stop()

# Helper to ensure music resets when switching scenes/winning
func reset_audio_state():
	set_danger_mode(false)
