extends Control

@onready var title_label = $TitleLabel # Make sure this path is correct now that you moved it!
@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	# Connect buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	var btn_compendium = find_child("CompendiumButton")
	if btn_compendium:
		btn_compendium.pressed.connect(_on_compendium_pressed)
	
	AudioManager.play_music("menu_theme")
	
	# --- RUN THE ANIMATION ---
	_play_crash_intro()

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
