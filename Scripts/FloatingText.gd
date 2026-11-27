extends Node2D

@onready var label: Label = $Label


func _ready() -> void:
	z_index = 20


func setup(text_value: String, color: Color, start_pos: Vector2) -> void:
	position = start_pos

	if label:
		label.text = text_value
		label.modulate = color

	var drift_x: float = randf_range(-60.0, 60.0)
	var float_height: float = -100.0
	var duration: float = 1.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "position", start_pos + Vector2(drift_x, float_height), duration)

	scale = Vector2(1.5, 1.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.5)

	await tween.finished
	queue_free()
