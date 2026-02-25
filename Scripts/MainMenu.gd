extends Control

@onready var title_label = $TitleLabel # Make sure this path is correct now that you moved it!
@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton


# --- BACKGROUND VARS ---
@onready var layers = [$BackgroundContainer/Layer1, $BackgroundContainer/Layer2]
var bg_list: Array[Texture2D] = []
var current_layer_idx = 0
var active_bg_index = 0

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
	var start_pos = final_pos - Vector2(0, 800) # Start 800px higher
	
	title_label.position = start_pos
	title_label.modulate.a = 0.0 # Start invisible
	title_label.scale = Vector2(2.0, 2.0) # Start giant
	
	# Hide buttons initially so they can pop in later
	var buttons_container = $VBoxContainer
	buttons_container.modulate.a = 0.0
	
	# 2. THE TWEEN
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Run even if paused
	
	# A. FALLING (Fast and Heavy)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(title_label, "position", final_pos, 0.4) # Fall duration
	tween.tween_property(title_label, "modulate:a", 1.0, 0.2) # Fade in quickly
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.4) # Shrink to normal
	
	# B. IMPACT (Sequence: Wait for fall to finish -> Shake)
	tween.set_parallel(false) # Switch back to sequential
	tween.tween_callback(func(): 
		# Play heavy impact sound
		AudioManager.play_sfx("hit_heavy") 
		_shake_screen(10.0, 0.4) # Shake the whole menu
	)
	
	# C. SQUASH & STRETCH (The "Jelly" impact)
	tween.set_parallel(true)
	# Flatten it (squash)
	tween.tween_property(title_label, "scale", Vector2(1.2, 0.8), 0.1).set_trans(Tween.TRANS_BOUNCE)
	# Return to normal
	tween.chain().tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# D. REVEAL BUTTONS
	tween.parallel().tween_property(buttons_container, "modulate:a", 1.0, 0.5)

# A generic shaker for the UI
func _shake_screen(intensity: float, duration: float):
	var original_pos = self.position # Assumes this Control is usually at (0,0)
	var shake_tween = create_tween()
	
	# Shake heavily at first, then dampen
	shake_tween.tween_method(func(val):
		var offset = Vector2(randf_range(-val, val), randf_range(-val, val))
		self.position = original_pos + offset
	, intensity, 0.0, duration) # Tween from intensity down to 0

func _on_start_pressed():
	AudioManager.play_sfx("ui_click") # Added SFX
	SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")
	
func _on_quit_pressed():
	get_tree().quit()

func _on_compendium_pressed():
	SceneLoader.change_scene("res://Scenes/compendium.tscn")
