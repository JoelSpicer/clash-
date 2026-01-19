extends Node

# --- SOUND LIBRARY ---
# Replace these paths with your actual files later!
# If you don't have files yet, the game will just print a warning instead of crashing.
var sounds = {
	# UI
	"ui_hover": preload("res://Audio/UI/hover.wav"),
	"ui_click": preload("res://Audio/UI/click.wav"),
	"game_start": preload("res://Audio/UI/game_start.ogg"),
	
	# COMBAT
	"hit_light": preload("res://Audio/Combat/hit_light.wav"),
	"hit_heavy": preload("res://Audio/Combat/hit_heavy.wav"),
	"block": preload("res://Audio/Combat/block.wav"),
	"clash": preload("res://Audio/Combat/clash.wav"),
	"clash_win": preload("res://Audio/Combat/clash_win.wav"),
	"buff": preload("res://Audio/Combat/buff.wav"),
}

# --- PLAYER POOL ---
# We create 10 players so up to 10 sounds can happen at once.
var pool_size = 10
var sfx_players: Array[AudioStreamPlayer] = []

func _ready():
	# Create the pool of players
	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX" # Make sure you have an 'SFX' bus in Audio tab, or default to 'Master'
		add_child(p)
		sfx_players.append(p)

# --- PUBLIC FUNCTION ---
func play_sfx(key: String, pitch_variance: float = 0.0):
	if not sounds.has(key):
		print_debug("Audio Key not found: " + key)
		return
		
	var stream = sounds[key]
	if not stream: return # File might be missing
	
	# Find a free player
	var player = _get_available_player()
	if player:
		player.stream = stream
		
		# Add random pitch variation for "Juice" (e.g., 0.9 to 1.1)
		if pitch_variance > 0:
			player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
		else:
			player.pitch_scale = 1.0
			
		player.play()

func _get_available_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	
	# If all are busy, steal the oldest one (index 0) and move it to back
	var p = sfx_players.pop_front()
	sfx_players.append(p)
	return p
