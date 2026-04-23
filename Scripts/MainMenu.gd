extends Control

@onready var title_label = $TitleLabel # Make sure this path is correct now that you moved it!
@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton


# --- BACKGROUND VARS ---
@onready var layers = [$BackgroundContainer/Layer1, $BackgroundContainer/Layer2]
var bg_list: Array[Texture2D] = []
var current_layer_idx = 0
var active_bg_index = 0

@onready var bg_container = $BackgroundContainer # <--- NEW REFERENCE

# --- PARALLAX SETTINGS ---
var max_parallax: float = 20.0
var parallax_smoothness: float = 4.0 
var base_bg_pos: Vector2 = Vector2.ZERO

func _ready():
	# 1. SETUP UI
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	var btn_compendium = find_child("CompendiumButton")
	if btn_compendium: btn_compendium.pressed.connect(_on_compendium_pressed)
	
	AudioManager.play_music("menu_theme")
	
	# 2. RUN TITLE ANIMATION
	_play_crash_intro()
	
	# 3. START BACKGROUND SLIDESHOW
	_init_slideshow()
	
	# --- SETUP PARALLAX VISUALS ---
	await get_tree().process_frame
	var screen_size = get_viewport_rect().size
	
	# Set pivot to center and scale the ENTIRE container up
	if bg_container:
		bg_container.pivot_offset = screen_size / 2.0
		bg_container.scale = Vector2(1.05, 1.05)
		base_bg_pos = bg_container.position
	# ------------------------------
	

func _process(delta):
	# --- APPLY PARALLAX TO BACKGROUND CONTAINER ---
	if bg_container:
		var screen_size = get_viewport_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		var center = screen_size / 2.0
		
		# Calculate offset
		var offset_x = (mouse_pos.x - center.x) / center.x
		var offset_y = (mouse_pos.y - center.y) / center.y
		var mouse_offset = Vector2(offset_x, offset_y)
		
		# Apply target position to the parent container!
		var target_pos = base_bg_pos - (mouse_offset * max_parallax)
		bg_container.position = bg_container.position.lerp(target_pos, delta * parallax_smoothness)

func _init_slideshow():
	if GameManager.environment_backgrounds.size() > 0:
		# CHANGE THIS LINE:
		# bg_list = GameManager.environment_backgrounds.values()
		
		# TO THIS:
		bg_list.assign(GameManager.environment_backgrounds.values())
		
		bg_list.shuffle() # Random order
		
		# Set initial image
		layers[0].texture = bg_list[0]
		_animate_pan_zoom(layers[0])
		
		# Start the loop
		get_tree().create_timer(7.0).timeout.connect(_cycle_background)

func _cycle_background():
	# Pick the next image
	active_bg_index = (active_bg_index + 1) % bg_list.size()
	var next_texture = bg_list[active_bg_index]
	
	# Identify Front (fading in) and Back (fading out) layers
	var front_layer = layers[1 - current_layer_idx] # The one currently hidden
	var back_layer = layers[current_layer_idx]      # The one currently visible
	
	# 1. Setup the Front Layer
	front_layer.texture = next_texture
	front_layer.modulate.a = 0.0
	front_layer.show()
	
	# 2. Start the "Ken Burns" movement on the new layer immediately
	_animate_pan_zoom(front_layer)
	
	# 3. Crossfade Tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(front_layer, "modulate:a", 1.0, 1.5) # Fade In
	tween.tween_property(back_layer, "modulate:a", 0.0, 1.5)  # Fade Out
	
	# 4. Flip the index for next time
	current_layer_idx = 1 - current_layer_idx
	
	# 5. Schedule next cycle
	tween.chain().tween_callback(func():
		get_tree().create_timer(5.0).timeout.connect(_cycle_background)
	)

func _animate_pan_zoom(layer: TextureRect):
	# RESET the layer's transform so it starts fresh
	layer.pivot_offset = layer.size / 2
	layer.scale = Vector2(1.05, 1.05) # Start slightly zoomed in
	layer.rotation_degrees = 0
	
	# Randomize movement direction
	var target_scale = Vector2(1.15, 1.15) # Zoom in more
	var target_rot = randf_range(-2.0, 2.0) # Slight tilt
	
	# Subtle Pan (Moving the pivot effectively moves the image opposite)
	# We use a random offset for the pan
	var pan_x = randf_range(-20.0, 20.0)
	var pan_y = randf_range(-20.0, 20.0)
	var start_pos = layer.position
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Move slowly over 7 seconds (longer than the swap time so it never stops moving)
	tween.tween_property(layer, "scale", target_scale, 9.0)
	tween.tween_property(layer, "rotation_degrees", target_rot, 9.0)
	tween.tween_property(layer, "position", start_pos + Vector2(pan_x, pan_y), 90)

func _play_crash_intro():
	# 1. SETUP STATE
	var final_pos = title_label.position
	var start_pos = final_pos - Vector2(0, 800) 
	
	title_label.position = start_pos
	title_label.modulate.a = 0.0 
	title_label.scale = Vector2(3.0, 3.0) 
	
	var buttons_container = $VBoxContainer
	buttons_container.modulate.a = 0.0
	
	# 2. THE TWEEN
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	# A. THE SLAM
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(title_label, "position", final_pos, 0.35)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.1)
	
	# B. THE IMPACT (Flash + Shake + Dust)
	tween.set_parallel(false) 
	tween.tween_callback(func(): 
		AudioManager.play_sfx("hit_heavy") 
		_shake_screen(25.0, 0.5)
		_trigger_camera_flash()
		_trigger_dust_slam() # <--- NEW CALL
		_trigger_glitch_effect()
	)
	
	# C. REVEAL BUTTONS
	tween.tween_property(buttons_container, "modulate:a", 1.0, 0.5)

# --- NEW: EXPLOSIVE FLASH EFFECT ---
func _trigger_camera_flash():
	# 1. Create a white rectangle that covers the whole screen
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block clicks
	add_child(flash)
	
	# 2. Animate it fading out instantly
	var f_tween = create_tween()
	# Start fully bright, then vanish in 0.3 seconds
	f_tween.tween_property(flash, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	f_tween.tween_callback(flash.queue_free) # Clean up the node when done

# A generic shaker for the UI
func _shake_screen(intensity: float, duration: float):
	var original_pos = self.position # Assumes this Control is usually at (0,0)
	var shake_tween = create_tween()
	
	# Shake heavily at first, then dampen
	shake_tween.tween_method(func(val):
		var offset = Vector2(randf_range(-val, val), randf_range(-val, val))
		self.position = original_pos + offset
	, intensity, 0.0, duration) # Tween from intensity down to 0

func _trigger_dust_slam():
	var particles = CPUParticles2D.new()
	add_child(particles)
	
	# Position it at the bottom-center of the Title Label
	particles.position = title_label.position + Vector2(title_label.size.x / 2, title_label.size.y * 0.8)
	
	# Visual Settings
	particles.amount = 30
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.spread = 180.0 # Full circle burst
	particles.gravity = Vector2.ZERO # No falling, just expanding
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 400.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	
	# Color Gradient (Dusty gray to transparent)
	var grad = Gradient.new()
	grad.set_color(0, Color(0.8, 0.8, 0.8, 0.6)) # Light gray
	grad.set_color(1, Color(0.8, 0.8, 0.8, 0.0)) # Transparent
	particles.color_ramp = grad
	
	# Start emitting and auto-delete
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

# --- NEW: CHROMATIC / DIGITAL GLITCH ---
func _trigger_glitch_effect():
	pass
	#var layer1 = $BackgroundContainer/Layer1 
	#var layer2 = $BackgroundContainer/Layer2 
	#
	## We'll use a fast loop to "jitter" the images
	#var glitch_tween = create_tween()
	#
	#for i in range(8): # 8 rapid frames of glitching
		#glitch_tween.tween_callback(func():
			## 1. Random Offset (Simulates shifting scanlines)
			#var offset = Vector2(randf_range(-40, 40), randf_range(-10, 10))
			#layer1.position = offset 
			#
			## 2. Color Scrambling (Briefly turn one layer Red or Blue)
			#if randf() > 0.5:
				#layer1.modulate = Color(10, 0.5, 0.5, 1) # Over-bright Red
			#else:
				#layer1.modulate = Color(0.5, 0.5, 10, 1) # Over-bright Blue
				#
			## 3. Show the second layer briefly for a "ghosting" effect
			#layer2.show() 
			#layer2.modulate.a = 0.5 
			#layer2.position = -offset
		#)
		#glitch_tween.tween_interval(0.03) # 30ms per glitch frame
		#
	## 4. RESET everything back to normal
	#glitch_tween.chain().tween_callback(func():
		#layer1.position = Vector2.ZERO 
		#layer1.modulate = Color.WHITE 
		#layer2.hide() 
		#layer2.modulate.a = 0.0 
	#)

func _on_start_pressed():
	AudioManager.play_sfx("ui_click") 
	
	# 1. Safety check to ensure save data is loaded
	if not RunManager.meta_data:
		SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")
		return
		
	# 2. Check if the "intro" tutorial has been seen
	if not RunManager.meta_data.seen_menu_tutorials.has("intro_begin"):
		# Mark it as seen and save the game immediately
		RunManager.meta_data.seen_menu_tutorials["intro_begin"] = true
		RunManager._save_global_data()
		
		# Trigger your custom Tutorial Manager
		TutorialManager.setup_and_start_tutorial("begin")
		
		# IMPORTANT: How does your TutorialManager handle finishing?
		# If it emits a signal when the player clicks "Finish Tutorial", 
		# you should await that signal before changing the scene like this:
		#
		# await TutorialManager.tutorial_completed 
		# SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")
		
	else:
		# If they HAVE seen it, skip the tutorial and go straight to the game
		SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")
	
func _on_quit_pressed():
	get_tree().quit()

func _on_compendium_pressed():
	SceneLoader.change_scene("res://Scenes/Multi.tscn")
