extends Control

# --- CONFIGURATION ---
var slides: Array = []
var current_index: int = 0
var is_transitioning: bool = false

# --- NODES ---
@onready var bg_current = $Background
@onready var bg_fader = $BackgroundFader
@onready var content_container = $ContentContainer
@onready var title_label = $UI_Layer/TitleLabel
@onready var btn_left = $UI_Layer/LeftArrow
@onready var btn_right = $UI_Layer/RightArrow
@onready var btn_back = $UI_Layer/BackButton

func _ready():
	# 1. DEFINE YOUR SLIDES HERE
	# Easy to add more later! Just append a new dictionary.
	slides = [
		{
			"title": "THE CIRCUIT (Story)",
			"scene_path": "res://Scenes/MenuArcade.tscn",
			"bg_path": "res://Art/Background/LockerRoom.png" # You need this art
		},
		{
			"title": "QUICK CLASH (PvP / PvE)",
			"scene_path": "res://Scenes/MenuQuick.tscn",
			"bg_path": "res://Art/Background/Street.png"
		},
		{
			"title": "GAME SETTINGS",
			"scene_path": "res://Scenes/MenuSettings.tscn",
			"bg_path": "res://Art/Background/Dojo.png"
		},
		{
			"title": "COMPENDIUM",
			"scene_path": "res://Scenes/compendium.tscn", # Reusing your existing scene!
			"bg_path": "res://Art/Background/Library.png"
		}
	]
	
	# 2. Setup Buttons
	btn_left.pressed.connect(func(): _change_slide(-1))
	btn_right.pressed.connect(func(): _change_slide(1))
	btn_back.pressed.connect(_on_back_pressed)
	
	# 3. Load Initial Slide (Arcade)
	_load_slide_content(0)
	_snap_background(0)

func _change_slide(direction: int):
	if is_transitioning: return
	is_transitioning = true
	AudioManager.play_sfx("ui_hover", 0.5) # Whoosh sound
	
	# 1. Calculate new index (Looping)
	var _old_index = current_index
	current_index += direction
	
	if current_index >= slides.size(): current_index = 0
	elif current_index < 0: current_index = slides.size() - 1
	
	# 2. VISUAL TRANSITION
	var slide_data = slides[current_index]
	title_label.text = slide_data.title
	
# A. Crossfade Background
	var new_bg = load(slide_data.bg_path)
	
	if new_bg:
		bg_fader.texture = new_bg
		bg_fader.modulate.a = 0.0
		bg_fader.visible = true # <--- FORCE VISIBILITY ON
		
		# Create the tween
		var t_bg = create_tween()
		t_bg.tween_property(bg_fader, "modulate:a", 1.0, 0.4)
		await t_bg.finished
		
		# Swap and reset
		bg_current.texture = new_bg
		bg_fader.modulate.a = 0.0
		# bg_fader.visible = false # Optional: Hide it again if you want
	else:
		print("ERROR: Could not load background at path: ", slide_data.bg_path)
	# B. Slide Content (The "Carousel" movement)
	# We instance the new scene OFF SCREEN, slide it in, then delete the old one.
	
	var old_content = content_container.get_child(0) if content_container.get_child_count() > 0 else null
	var new_scene = load(slide_data.scene_path).instantiate()
	
	# Determine direction
	var screen_width = get_viewport_rect().size.x
	var enter_pos = Vector2(screen_width, 0) if direction > 0 else Vector2(-screen_width, 0)
	var exit_pos = Vector2(-screen_width, 0) if direction > 0 else Vector2(screen_width, 0)
	
	# Setup New Content
	new_scene.position = enter_pos
	content_container.add_child(new_scene)
	
	# Animate
	var t_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	t_slide.tween_property(new_scene, "position", Vector2.ZERO, 0.4)
	if old_content:
		t_slide.tween_property(old_content, "position", exit_pos, 0.4)
	
	await t_slide.finished
	
	if old_content: old_content.queue_free()
	is_transitioning = false

# Used for the very first load (instant, no animation)
func _load_slide_content(idx: int):
	var data = slides[idx]
	title_label.text = data.title
	
	for child in content_container.get_children():
		child.queue_free()
		
	var scene = load(data.scene_path).instantiate()
	content_container.add_child(scene)

func _snap_background(idx: int):
	var tex = load(slides[idx].bg_path)
	if tex: bg_current.texture = tex

func _on_back_pressed():
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
