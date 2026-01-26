extends CanvasLayer

@onready var anim = $AnimationPlayer
@onready var overlay = $BlackOverlay

func _ready():
	# Ensure we start invisible and don't block mouse clicks
	overlay.visible = false
	overlay.modulate.a = 0

func change_scene(path: String):
	# 1. Block input and Fade to Black
	anim.play("fade_in")
	await anim.animation_finished
	
	# 2. Actual Scene Change
	get_tree().change_scene_to_file(path)
	
	# 3. Optional: Pause briefly to ensure the new scene initializes fully
	# (Prevents one-frame stutters on heavy scenes)
	await get_tree().create_timer(0.1).timeout
	
	# 4. Fade back in
	anim.play("fade_out")
	await anim.animation_finished
