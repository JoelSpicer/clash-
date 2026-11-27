extends Control

@export var skip_splash: bool = false
@export var next_scene: String = "res://Scenes/MainMenu.tscn"

@onready var logo: CanvasItem = $Logo
var _exiting: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--server"):
		return

	if skip_splash:
		_go_to_menu()
		return

	logo.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.tween_property(logo, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(1.0)
	tween.tween_property(logo, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_go_to_menu)


func _go_to_menu() -> void:
	if _exiting:
		return
	_exiting = true
	SceneLoader.change_scene(next_scene)


func _input(event: InputEvent) -> void:
	if skip_splash or _exiting:
		return

	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_go_to_menu()
