extends Label

func setup(text_value: String, color: Color, start_pos: Vector2):
	text = text_value
	modulate = color
	position = start_pos
	
	# Reset pivot for scaling
	pivot_offset = size / 2
	
	# Animation Sequence
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. Float Up
	tween.tween_property(self, "position:y", start_pos.y - 80, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 2. Fade Out
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	
	# 3. Scale Punch (Optional "Juice")
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Cleanup
	await tween.finished
	queue_free()
