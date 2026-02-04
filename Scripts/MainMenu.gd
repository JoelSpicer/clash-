extends Control

func _ready():
	# Connect buttons dynamically or via editor signals
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	
	_attach_sfx($VBoxContainer/StartButton)
	_attach_sfx($VBoxContainer/QuitButton)
	_attach_sfx($VBoxContainer/CompendiumButton)
	AudioManager.play_music("menu_theme")
	var btn_compendium = find_child("CompendiumButton") # Or reference it directly if you prefer
	if btn_compendium:
		btn_compendium.pressed.connect(_on_compendium_pressed)
	
func _on_start_pressed():
	# Assumes your main arena scene is saved here
	#SceneLoader.change_scene("res://Scenes/MainScene.tscn")
	#SceneLoader.change_scene("res://Scenes/CharacterSelect.tscn")
	#SceneLoader.change_scene("res://Scenes/CharacterSelect.tscn")
	SceneLoader.change_scene("res://Scenes/CarouselHub.tscn")
	
func _on_quit_pressed():
	get_tree().quit()

func _on_compendium_pressed():
	SceneLoader.change_scene("res://Scenes/compendium.tscn")

func _attach_sfx(btn: BaseButton):
	if not btn: return
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))
	btn.pressed.connect(func(): AudioManager.play_sfx("ui_click"))
