extends Control

@onready var background = $Background
@onready var p1_container = $Content/P1_Container
@onready var p1_portrait = $Content/P1_Container/Portrait
@onready var p1_name = $Content/P1_Container/NameLabel
@onready var p1_class = $Content/P1_Container/ClassLabel

@onready var p2_container = $Content/P2_Container
@onready var p2_portrait = $Content/P2_Container/Portrait
@onready var p2_name = $Content/P2_Container/NameLabel
@onready var p2_class = $Content/P2_Container/ClassLabel

@onready var vs_label = $Content/VsLabel
@onready var arena_label = $ArenaLabel

@onready var p1_bubble = $Content/P1_Container/PanelContainer/SpeechBubble # Adjust path if needed
@onready var p2_bubble = $Content/P2_Container/PanelContainer/SpeechBubble

func _ready():
	_setup_visuals()
	
	# Wait a frame to let Godot calculate the new Anchors we set
	await get_tree().process_frame
	_play_intro_animation()
	
	# Wait 3.5 seconds, then load the fight
	await get_tree().create_timer(5.0).timeout
	SceneLoader.change_scene("res://Scenes/MainScene.tscn")

func _setup_visuals():
	# -- Background --
	var env_name = GameManager.current_environment_name
	if GameManager.environment_backgrounds.has(env_name):
		background.texture = GameManager.environment_backgrounds[env_name]
	arena_label.text = "Stage:\n" + "- " + env_name.to_upper() + " -"

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
		p2_portrait.flip_h = true 
		p2_name.text = p2.character_name
		if p2.character_name == "THE JUGGERNAUT": 
			p2_class.text = "BOSS"
			p2_class.modulate = Color.RED
		else:
			p2_class.text = CharacterData.ClassType.keys()[p2.class_type]

func _play_intro_animation():
	vs_label.scale = Vector2.ZERO
	
	# Get exact screen width
	var screen_w = get_viewport_rect().size.x
	
	# 1. DEFINE TARGETS (Where they should end up)
	# P1 is anchored to Left (0)
	var p1_target_x = 0
	# P2 is anchored to Center (Width / 2)
	var p2_target_x = screen_w / 2
	
	# 2. DEFINE START POSITIONS (Where they start)
	# Start P1 way off the left side
	p1_container.position.x = -p1_container.size.x
	# Start P2 way off the right side
	p2_container.position.x = screen_w
	
	# 3. ANIMATE
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(p1_container, "position:x", p1_target_x, 0.8)
	tween.tween_property(p2_container, "position:x", p2_target_x, 0.8)
	
	# Pop the VS Label
	tween.tween_property(vs_label, "scale", Vector2.ONE, 0.5).set_delay(0.6).set_trans(Tween.TRANS_ELASTIC)
	
	# --- NEW: TRIGGER DIALOGUE ---
	var p1_type = GameManager.next_match_p1_data.class_type
	var p2_type = GameManager.next_match_p2_data.class_type
	
	var banter = DialogueManager.get_intro_banter(p1_type, p2_type)
	
	# Set text
	p1_bubble.text = banter["p1"] # Assuming Bubble is a Panel with a Label child
	p2_bubble.text = banter["p2"]
	
	# Sequence: 
	# 1. Slide In (0.8s) -> 2. Show P1 Text (1.5s) -> 3. Show P2 Text (1.5s) -> 4. Fight
	
	await get_tree().create_timer(1.0).timeout
	p1_bubble.visible = true
	AudioManager.play_sfx("ui_hover") # Or a "speech" sound
	
	await get_tree().create_timer(1.5).timeout
	p2_bubble.visible = true
	AudioManager.play_sfx("ui_hover")
