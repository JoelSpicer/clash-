extends Node

var _stop_id: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Must run even when paused
	GameManager.damage_dealt.connect(_on_damage)

func _on_damage(_target, amount, is_blocked):
	if is_blocked: return # No freeze on blocks
	
	# Only freeze on significant hits
	if amount >= 3:
		stop_frame(0.15)
	elif amount > 0:
		stop_frame(0.05)

func stop_frame(duration: float):
	# 1. Increment ID
	# This invalidates any previous timers that are currently waiting.
	_stop_id += 1
	var current_id = _stop_id
	
	# 2. Freeze
	get_tree().paused = true
	
	# 3. Wait
	# We use a timer that ignores the game pause state
	await get_tree().create_timer(duration, true, false, true).timeout
	
	# 4. Check ID
	# Only unpause if WE are still the active timer. 
	# If stop_frame() was called again while we were waiting (e.g. by the Finisher),
	# _stop_id will be higher, and we will do nothing.
	if _stop_id == current_id:
		get_tree().paused = false
