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
	"menu_theme": preload("res://Audio/Music/MenuTheme.mp3"),
	"battle_theme": preload("res://Audio/Music/BattleTheme.mp3"),
}

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
