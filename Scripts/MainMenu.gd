extends Control

@onready var title_label: Control = $TitleLabel
@onready var start_button: BaseButton = $VBoxContainer/StartButton
@onready var quit_button: BaseButton = $VBoxContainer/QuitButton


# --- BACKGROUND VARS ---
@onready var layers: Array[TextureRect] = [$BackgroundContainer/Layer1, $BackgroundContainer/Layer2]
var bg_list: Array[Texture2D] = []
var current_layer_idx: int = 0
var active_bg_index: int = 0

@onready var bg_container: Control = $BackgroundContainer

# --- PARALLAX SETTINGS ---
var max_parallax: float = 20.0
var parallax_smoothness: float = 4.0 
var base_bg_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 1. SETUP UI
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	var btn_compendium: BaseButton = find_child("CompendiumButton") as BaseButton
	if btn_compendium: btn_compendium.pressed.connect(_on_compendium_pressed)
	
	AudioManager.play_music("menu_theme")
	
	# 2. RUN TITLE ANIMATION
	_play_crash_intro()
	
	# 3. START BACKGROUND SLIDESHOW
	_init_slideshow()
	
	# --- SETUP PARALLAX VISUALS ---
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var screen_size: Vector2 = get_viewport_rect().size
	
	# Set pivot to center and scale the ENTIRE container up
	if bg_container:
		bg_container.pivot_offset = screen_size / 2.0
		bg_container.scale = Vector2(1.05, 1.05)
		base_bg_pos = bg_container.position
	# ------------------------------
	

func _process(delta: float) -> void:
	# --- APPLY PARALLAX TO BACKGROUND CONTAINER ---
	if bg_container:
		var screen_size: Vector2 = get_viewport_rect().size
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var center: Vector2 = screen_size / 2.0
		
		# Calculate offset
		var offset_x: float = (mouse_pos.x - center.x) / center.x
		var offset_y: float = (mouse_pos.y - center.y) / center.y
		var mouse_offset: Vector2 = Vector2(offset_x, offset_y)
		
		# Apply target position to the parent container!
		var target_pos: Vector2 = base_bg_pos - (mouse_offset * max_parallax)
		bg_container.position = bg_container.position.lerp(target_pos, delta * parallax_smoothness)

func _init_slideshow() -> void:
	if GameManager.environment_backgrounds.size() > 0:
		bg_list.assign(GameManager.environment_backgrounds.values())
		bg_list.shuffle() # Random order
		
		# Set initial image
		layers[0].texture = bg_list[0]
		_animate_pan_zoom(layers[0])
		
		# Start the loop
		get_tree().create_timer(7.0).timeout.connect(_cycle_background)

func _cycle_background() -> void:
	if not is_inside_tree() or bg_list.is_empty(): return
	# Pick the next image
	active_bg_index = (active_bg_index + 1) % bg_list.size()
	var next_texture: Texture2D = bg_list[active_bg_index]
	
	# Identify Front (fading in) and Back (fading out) layers
	var front_layer: TextureRect = layers[1 - current_layer_idx] # The one currently hidden
	var back_layer: TextureRect = layers[current_layer_idx]      # The one currently visible
	
	# 1. Setup the Front Layer
	front_layer.texture = next_texture
	front_layer.modulate.a = 0.0
	front_layer.show()
	
	# 2. Start the "Ken Burns" movement on the new layer immediately
	_animate_pan_zoom(front_layer)
	
	# 3. Crossfade Tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(front_layer, "modulate:a", 1.0, 1.5) # Fade In
	tween.tween_property(back_layer, "modulate:a", 0.0, 1.5)  # Fade Out
	
	# 4. Flip the index for next time
	current_layer_idx = 1 - current_layer_idx
	
	# 5. Schedule next cycle
	tween.chain().tween_callback(func() -> void:
		get_tree().create_timer(5.0).timeout.connect(_cycle_background)
	)

func _animate_pan_zoom(layer: TextureRect) -> void:
	# RESET the layer's transform so it starts fresh
	layer.pivot_offset = layer.size / 2
	layer.scale = Vector2(1.05, 1.05) # Start slightly zoomed in
	layer.rotation_degrees = 0
	
	# Randomize movement direction
	var target_scale: Vector2 = Vector2(1.15, 1.15) # Zoom in more
	var target_rot: float = randf_range(-2.0, 2.0) # Slight tilt
	
	# Subtle Pan (Moving the pivot effectively moves the image opposite)
	var pan_x: float = randf_range(-20.0, 20.0)
	var pan_y: float = randf_range(-20.0, 20.0)
	var start_pos: Vector2 = layer.position
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Move slowly over 7 seconds (longer than the swap time so it never stops moving)
	tween.tween_property(layer, "scale", target_scale, 9.0)
	tween.tween_property(layer, "rotation_degrees", target_rot, 9.0)
	tween.tween_property(layer, "position", start_pos + Vector2(pan_x, pan_y), 90.0)

func _play_crash_intro() -> void:
	# 1. SETUP STATE
	var final_pos: Vector2 = title_label.position
	var start_pos: Vector2 = final_pos - Vector2(0, 800) 
	
	title_label.position = start_pos
	title_label.modulate.a = 0.0 
	title_label.scale = Vector2(3.0, 3.0) 
	
	var buttons_container: Control = $VBoxContainer
	buttons_container.modulate.a = 0.0
	
	# 2. THE TWEEN
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	# A. THE SLAM
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(title_label, "position", final_pos, 0.35)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.1)
	
	# B. THE IMPACT (Flash + Shake + Dust)
	tween.set_parallel(false) 
	tween.tween_callback(func() -> void: 
		AudioManager.play_sfx("hit_heavy") 
		_shake_screen(25.0, 0.5)
		_trigger_camera_flash()
		_trigger_dust_slam()
		_trigger_glitch_effect()
	)
	
	# C. REVEAL BUTTONS
	tween.tween_property(buttons_container, "modulate:a", 1.0, 0.5)

# --- NEW: EXPLOSIVE FLASH EFFECT ---
func _trigger_camera_flash() -> void:
	# 1. Create a white rectangle that covers the whole screen
	var flash: ColorRect = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block clicks
	add_child(flash)
	
	# 2. Animate it fading out instantly
	var f_tween: Tween = create_tween()
	# Start fully bright, then vanish in 0.3 seconds
	f_tween.tween_property(flash, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	f_tween.tween_callback(flash.queue_free) # Clean up the node when done

# A generic shaker for the UI
func _shake_screen(intensity: float, duration: float) -> void:
	var original_pos: Vector2 = self.position # Assumes this Control is usually at (0,0)
	var shake_tween: Tween = create_tween()
	
	# Shake heavily at first, then dampen
	shake_tween.tween_method(func(val: float) -> void:
		var offset: Vector2 = Vector2(randf_range(-val, val), randf_range(-val, val))
		self.position = original_pos + offset
	, intensity, 0.0, duration) # Tween from intensity down to 0

func _trigger_dust_slam() -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
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
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.8, 0.8, 0.8, 0.6)) # Light gray
	grad.set_color(1, Color(0.8, 0.8, 0.8, 0.0)) # Transparent
	particles.color_ramp = grad
	
	# Start emitting and auto-delete
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

# --- NEW: CHROMATIC / DIGITAL GLITCH ---
func _trigger_glitch_effect() -> void:
	pass

func _on_start_pressed() -> void:
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
	else:
		# If they HAVE seen it, skip the tutorial and go straight to the game
		SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")
	
func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_compendium_pressed() -> void:
	SceneLoader.change_scene("res://Scenes/compendium.tscn")
