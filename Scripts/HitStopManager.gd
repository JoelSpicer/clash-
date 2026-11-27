extends Node

var _stop_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.damage_dealt.connect(_on_damage)


func _on_damage(_target: int, amount: int, is_blocked: bool) -> void:
	if is_blocked:
		return

	if amount >= 3:
		stop_frame(0.15)
	elif amount > 0:
		stop_frame(0.05)


func stop_frame(duration: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		return
	if Pausemenu and Pausemenu.visible:
		return

	_stop_id += 1
	var current_id: int = _stop_id

	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout

	if _stop_id == current_id and (not Pausemenu or not Pausemenu.visible):
		if GameManager.p1_data and GameManager.p2_data and (GameManager.p1_data.current_hp <= 0 or GameManager.p2_data.current_hp <= 0):
			return
		get_tree().paused = false
