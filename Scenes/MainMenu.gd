extends Control

func _ready():
	# Connect buttons dynamically or via editor signals
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	# Assumes your main arena scene is saved here
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func _on_quit_pressed():
	get_tree().quit()
