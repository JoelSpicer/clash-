extends Control

@onready var background = $Background
@onready var p1_portrait = $Content/P1_Container/Portrait
@onready var p1_name = $Content/P1_Container/NameLabel
@onready var p1_class = $Content/P1_Container/ClassLabel

@onready var p2_portrait = $Content/P2_Container/Portrait
@onready var p2_name = $Content/P2_Container/NameLabel
@onready var p2_class = $Content/P2_Container/ClassLabel

@onready var vs_label = $Content/VsLabel
@onready var arena_label = $ArenaLabel

@onready var p1_container = $Content/P1_Container
@onready var p2_container = $Content/P2_Container

func _ready():
	# 1. SETUP DATA
	_setup_visuals()
	
	# 2. START ANIMATION
	_play_intro_animation()
	
	# 3. TIMER TO START FIGHT
	# Wait 3.5 seconds, then load the actual game
	await get_tree().create_timer(3.5).timeout
	SceneLoader.change_scene("res://Scenes/MainScene.tscn")

func _setup_visuals():
	# -- Background --
	var env_name = GameManager.current_environment_name
	if GameManager.environment_backgrounds.has(env_name):
		background.texture = GameManager.environment_backgrounds[env_name]
	arena_label.text = "- " + env_name.to_upper() + " -"

	# -- Player 1 --
	var p1 = GameManager.next_match_p1_data
	if p1:
		p1_portrait.texture = p1.portrait
		p1_name.text = p1.character_name
		p1_class.text = CharacterData.ClassType.keys()[p1.class_type]

	# -- Player 2 --
	var p2 = GameManager.next_match_p2_data
	if p2:
		p2_portrait.texture = p2.portrait
		p2_portrait.flip_h = true # Face left
		p2_name.text = p2.character_name
		# Handle Bosses/Presets vs Randoms
		if p2.character_name == "THE JUGGERNAUT": # Example detection
			p2_class.text = "BOSS"
			p2_class.modulate = Color.RED
		else:
			p2_class.text = CharacterData.ClassType.keys()[p2.class_type]

func _play_intro_animation():
	# hide VS label initially
	vs_label.scale = Vector2.ZERO
	
	# Get screen width
	var width = get_viewport_rect().size.x
	
	# Start positions (Off screen)
	p1_container.position.x = -width / 2
	p2_container.position.x = width / 2
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Slam players in
	tween.tween_property(p1_container, "position:x", 0.0, 0.8)
	tween.tween_property(p2_container, "position:x", 0.0, 0.8)
	
	# Pop the VS Label after 0.5s
	tween.tween_property(vs_label, "scale", Vector2.ONE, 0.5).set_delay(0.6).set_trans(Tween.TRANS_ELASTIC)
	
	# Optional: Play a sound
	# AudioManager.play_sfx("impact_heavy", 1.0)
