extends Node

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Must run even when paused
	GameManager.damage_dealt.connect(_on_damage)

func _on_damage(_target, amount, is_blocked):
	if is_blocked: return # No freeze on blocks
	
	# Only freeze on significant hits (e.g. damage >= 3)
	if amount >= 3:
		stop_frame(0.15)
	elif amount > 0:
		stop_frame(0.05)

func stop_frame(duration: float):
	# Freeze the game logic
	get_tree().paused = true
	
	# Wait using a timer that ignores the pause
	await get_tree().create_timer(duration, true, false, true).timeout
	
	# Unfreeze
	get_tree().paused = false
