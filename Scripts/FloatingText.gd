extends Node2D

@onready var label = $Label

func _ready():
	# Ensure it sits on top of other UI elements
	z_index = 20

func setup(text_value: String, color: Color, start_pos: Vector2):
	# 1. Setup Initial State
	position = start_pos
	
	if label:
		label.text = text_value
		label.modulate = color
	
	# 2. Randomize Movement (The "Drift")
	var drift_x = randf_range(-60, 60)
	var float_height = -100 # How high it goes
	var duration = 1.0
	
	# 3. Create Animation Tween
	var tween = create_tween()
	tween.set_parallel(true) # Run all tweens at once
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# MOVEMENT: Drift sideways and float up
	tween.tween_property(self, "position", start_pos + Vector2(drift_x, float_height), duration)
	
	# SCALE: Pop in (Start big, shrink to normal)
	scale = Vector2(1.5, 1.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
	
	# FADE: Disappear at the end
	# Wait 0.5s, then fade out over the remaining 0.5s
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.5)
	
	# 4. Cleanup
	await tween.finished
	queue_free()
