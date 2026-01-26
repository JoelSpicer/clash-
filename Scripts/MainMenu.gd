extends Control

func _ready():
	# Connect buttons dynamically or via editor signals
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	
	_attach_sfx($VBoxContainer/StartButton)
	_attach_sfx($VBoxContainer/QuitButton)
	_attach_sfx($VBoxContainer/CompendiumButton)
	
	var btn_compendium = find_child("CompendiumButton") # Or reference it directly if you prefer
	if btn_compendium:
		btn_compendium.pressed.connect(_on_compendium_pressed)
	
func _on_start_pressed():
	# Assumes your main arena scene is saved here
	#get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
	#get_tree().change_scene_to_file("res://Scenes/CharacterSelect.tscn")
	SceneLoader.change_scene("res://Scenes/CharacterSelect.tscn")
	
func _on_quit_pressed():
	get_tree().quit()

func _on_compendium_pressed():
	get_tree().change_scene_to_file("res://Scenes/compendium.tscn")

func _attach_sfx(btn: BaseButton):
	if not btn: return
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))
	btn.pressed.connect(func(): AudioManager.play_sfx("ui_click"))
