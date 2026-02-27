extends Control

@onready var background = $Background
@onready var content = $Content

# --- NEW CINEMATIC NODES ---
@onready var flash_overlay = $FlashOverlay
@onready var top_bar = $TopLetterbox
@onready var bottom_bar = $BottomLetterbox

# --- PLAYER 1 NODES ---
@onready var p1_container = $Content/P1_Container
@onready var p1_portrait = $Content/P1_Container/Portrait
@onready var p1_name = $Content/P1_Container/InfoBox/VBoxContainer/NameLabel
@onready var p1_class = $Content/P1_Container/InfoBox/VBoxContainer/ClassLabel
@onready var p1_hp = $Content/P1_Container/InfoBox/VBoxContainer/StatsRow/HPLabel
@onready var p1_sp = $Content/P1_Container/InfoBox/VBoxContainer/StatsRow/SPLabel
@onready var p1_bubble = $Content/P1_Container/PanelContainer/SpeechBubble

# --- PLAYER 2 NODES ---
@onready var p2_container = $Content/P2_Container
@onready var p2_portrait = $Content/P2_Container/Portrait
@onready var p2_name = $Content/P2_Container/InfoBox/VBoxContainer/NameLabel
@onready var p2_class = $Content/P2_Container/InfoBox/VBoxContainer/ClassLabel
@onready var p2_hp = $Content/P2_Container/InfoBox/VBoxContainer/StatsRow/HPLabel
@onready var p2_sp = $Content/P2_Container/InfoBox/VBoxContainer/StatsRow/SPLabel
@onready var p2_bubble = $Content/P2_Container/PanelContainer/SpeechBubble

@onready var vs_label = $Content/VsLabel
@onready var arena_label = $BottomLetterbox/ArenaLabel

func _ready():
	# 1. Hide things before setup
	p1_bubble.visible_ratio = 0.0 # Typewriter reset
	p2_bubble.visible_ratio = 0.0
	p1_bubble.get_parent().modulate.a = 0.0 # Reserve space, but make invisible
	p2_bubble.get_parent().modulate.a = 0.0
	flash_overlay.modulate.a = 0.0
	
	_setup_visuals()
	
	# Wait a frame to let Godot calculate the new Anchors
	await get_tree().process_frame
	_play_intro_animation()
	
	# The intro takes about 4 seconds total, load fight after 5
	await get_tree().create_timer(7.0).timeout
	SceneLoader.change_scene("res://Scenes/MainScene.tscn")

func _setup_visuals():
	var env_name = GameManager.current_environment_name
	if GameManager.environment_backgrounds.has(env_name):
		background.texture = GameManager.environment_backgrounds[env_name]
	arena_label.text = "- " + env_name.to_upper() + " -"

	var p1 = GameManager.next_match_p1_data
	var p2 = GameManager.next_match_p2_data
	
	if RunManager.is_arcade_mode and RunManager.player_run_data:
		p1 = RunManager.player_run_data

	# -- Player 1 Data --
	if p1:
		if p1.portrait: p1_portrait.texture = p1.portrait
		p1_name.text = p1.character_name
		p1_class.text = CharacterData.ClassType.keys()[p1.class_type] if p1.class_type >= 0 else "UNKNOWN"
		p1_hp.text = "HP: " + str(p1.max_hp)
		p1_sp.text = "SP: " + str(p1.max_sp)

	# -- Player 2 Data --
	if p2:
		if p2.portrait:
			p2_portrait.texture = p2.portrait
			p2_portrait.flip_h = true 
		p2_name.text = p2.character_name
		
		if p2.character_name == "THE JUGGERNAUT": 
			p2_class.text = "BOSS"
			p2_class.modulate = Color.RED
		else:
			p2_class.text = CharacterData.ClassType.keys()[p2.class_type] if p2.class_type >= 0 else "UNKNOWN"
		
		p2_hp.text = "HP: " + str(p2.max_hp)
		p2_sp.text = "SP: " + str(p2.max_sp)

func _play_intro_animation():
	var screen_w = get_viewport_rect().size.x
	
	# Reset states
	vs_label.scale = Vector2.ZERO
	p1_container.position.x = -p1_container.size.x
	p2_container.position.x = screen_w
	
	# Push letterboxes offscreen initially
	top_bar.position.y = -100
	bottom_bar.position.y = get_viewport_rect().size.y
	
	# --- PHASE 1: THE CRASH ---
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Characters slide in
	tween.tween_property(p1_container, "position:x", 0, 0.8)
	tween.tween_property(p2_container, "position:x", screen_w / 2, 0.8)
	
	# Cinematic bars slide in
	tween.tween_property(top_bar, "position:y", 0, 0.8)
	tween.tween_property(bottom_bar, "position:y", get_viewport_rect().size.y - 100, 0.8)
	
	# --- PHASE 2: IMPACT & FLASH (At 0.8s) ---
	tween.set_parallel(false) # Sequence mode
	tween.tween_interval(0.8)
	
	tween.tween_callback(func():
		AudioManager.play_sfx("hit_heavy")
		_shake_content(15.0, 0.5)
		
		# Flash White
		var flash_tween = create_tween()
		flash_overlay.modulate.a = 1.0
		flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.5)
	)
	
	# Pop the VS Label immediately after impact
	tween.tween_property(vs_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	# --- PHASE 3: DIALOGUE FETCH ---
	var banter = DialogueManager.get_intro_banter(GameManager.next_match_p1_data.class_type, GameManager.next_match_p2_data.class_type)
	p1_bubble.text = banter["p1"]
	p2_bubble.text = banter["p2"]
	
	# --- PHASE 4: TYPEWRITER SEQUENCE ---
	
	# Player 1 Speaks
	tween.tween_interval(0.2)
	# Fade in the background panel smoothly
	tween.tween_property(p1_bubble.get_parent(), "modulate:a", 1.0, 0.2) 
	tween.tween_callback(func():
		AudioManager.play_sfx("ui_click") # Typewriter sound
	)
	tween.tween_property(p1_bubble, "visible_ratio", 1.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	
	# Player 2 Speaks
	tween.tween_interval(0.5)
	# Fade in the background panel smoothly
	tween.tween_property(p2_bubble.get_parent(), "modulate:a", 1.0, 0.2)
	tween.tween_callback(func():
		AudioManager.play_sfx("ui_click")
	)
	tween.tween_property(p2_bubble, "visible_ratio", 1.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	
	
	
	
# Camera Shake effect for the Content layer
func _shake_content(intensity: float, duration: float):
	var original_pos = content.position
	var shake_tween = create_tween()
	
	shake_tween.tween_method(func(val):
		var offset = Vector2(randf_range(-val, val), randf_range(-val, val))
		content.position = original_pos + offset
	, intensity, 0.0, duration)
	
	shake_tween.tween_callback(func(): content.position = original_pos)
