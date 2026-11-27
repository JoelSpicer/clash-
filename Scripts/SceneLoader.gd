extends CanvasLayer

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var overlay: ColorRect = $BlackOverlay


func _ready() -> void:
	overlay.visible = false
	overlay.modulate.a = 0.0


func change_scene(path: String) -> void:
	anim.play("fade_in")
	await anim.animation_finished

	get_tree().change_scene_to_file(path)

	await get_tree().create_timer(0.1).timeout

	anim.play("fade_out")
	await anim.animation_finished
