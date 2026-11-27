extends Node

var sounds: Dictionary = {
	"ui_hover": preload("res://Audio/UI/hover.wav"),
	"ui_click": preload("res://Audio/UI/click.wav"),
	"hit_light": preload("res://Audio/Combat/hit_light.wav"),
	"hit_heavy": preload("res://Audio/Combat/hit_heavy.wav"),
	"block": preload("res://Audio/Combat/block.wav"),
	"clash": preload("res://Audio/Combat/clash.wav"),
	"menu_theme": preload("res://Audio/Music/SongMenus.tres"),
	"music_ring": preload("res://Audio/Music/SongRing.tres"),
	"music_dojo": preload("res://Audio/Music/SongDojo.tres"),
	"music_street": preload("res://Audio/Music/SongStreet.tres"),
	"battle_theme": preload("res://Audio/Music/SongRing.tres"),
}

var is_danger_mode: bool = false
var heartbeat_player: AudioStreamPlayer

@onready var music_player: OvaniPlayer = $MusicPlayer

var pool_size: int = 10
var sfx_players: Array[AudioStreamPlayer] = []
var current_music_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for _i: int in range(pool_size):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	heartbeat_player.stream = preload("res://Audio/SFX/heartbeat.wav")
	heartbeat_player.bus = "SFX"
	heartbeat_player.volume_db = 5.0
	add_child(heartbeat_player)


func play_music(key: String, fade_duration: float = 2.0) -> void:
	if not sounds.has(key):
		print("Music track not found: " + key)
		return

	if current_music_key == key:
		return
	current_music_key = key

	var song_resource: OvaniSong = sounds[key] as OvaniSong
	if music_player and song_resource:
		music_player.PlaySongNow(song_resource, fade_duration)


func set_music_intensity(target_val: float, fade_time: float = 2.0) -> void:
	if music_player:
		music_player.FadeIntensity(clampf(target_val, 0.0, 1.0), fade_time)


func stop_music(fade_duration: float = 2.0) -> void:
	if music_player:
		music_player.StopSongsNow(fade_duration)
	current_music_key = ""


func play_location_music(env_name: String) -> void:
	var target_key: String = "battle_theme"
	match env_name.to_lower():
		"ring": target_key = "music_ring"
		"dojo": target_key = "music_dojo"
		"street": target_key = "music_street"
	play_music(target_key, 2.0)


func play_sfx(key: String, pitch_variance: float = 0.0) -> void:
	if not sounds.has(key):
		return
	var stream: AudioStream = sounds[key] as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_available_player(stream)
	if player:
		if player.stream != stream:
			player.stream = stream
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance) if pitch_variance > 0.0 else 1.0
		player.play()


func _get_available_player(preferred_stream: AudioStream = null) -> AudioStreamPlayer:
	if preferred_stream != null:
		for p: AudioStreamPlayer in sfx_players:
			if not p.playing and p.stream == preferred_stream:
				return p
	for p: AudioStreamPlayer in sfx_players:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = sfx_players.pop_front()
	sfx_players.append(p)
	return p


func set_danger_mode(active: bool) -> void:
	if active == is_danger_mode:
		return
	is_danger_mode = active

	if active:
		heartbeat_player.play()
		_pulse_vignette()
		if music_player:
			music_player.FadeVolume(-5.0, 1.0)
	else:
		if heartbeat_player and heartbeat_player.playing:
			heartbeat_player.stop()
		if music_player:
			music_player.FadeVolume(0.0, 1.0)


func reset_audio_state() -> void:
	set_danger_mode(false)
	set_music_intensity(0.0, 0.5)

	if GlobalCinematics.has_method("set_danger_vignette"):
		GlobalCinematics.set_danger_vignette(false)

	if music_player:
		music_player.StopSongsNow(0.5)
	current_music_key = ""


func _pulse_vignette() -> void:
	if not is_danger_mode:
		return

	var tween: Tween = create_tween()
	tween.tween_method(func(v: float) -> void:
		GlobalCinematics.danger_vignette_boost = v
		GlobalCinematics._update_visuals()
	, 0.45, 0.55, 0.4).set_trans(Tween.TRANS_SINE)

	tween.tween_method(func(v: float) -> void:
		GlobalCinematics.danger_vignette_boost = v
		GlobalCinematics._update_visuals()
	, 0.55, 0.45, 0.4).set_trans(Tween.TRANS_SINE)

	tween.tween_callback(_pulse_vignette)
