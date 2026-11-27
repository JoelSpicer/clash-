extends CanvasLayer

const BLOCKED_SCENES: Array[String] = [
	"MainMenu",
	"GameOverScreen",
	"SplashScreen",
	"VsScreen",
	"LeagueVictoryScreen",
]


func _ready() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if SceneLoader.overlay and SceneLoader.overlay.visible:
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	if current_scene.name in BLOCKED_SCENES:
		return

	# Let CarouselHub dismiss its tutorial popup on Esc instead of opening PauseMenu
	if current_scene.has_method("is_tutorial_popup_visible") and bool(current_scene.call("is_tutorial_popup_visible")):
		return

	# Do not open PauseMenu over an active GameOverScreen overlay or paused TutorialLayer prompt
	if not visible and _has_blocking_overlay(current_scene):
		return

	_toggle_pause()
	get_viewport().set_input_as_handled()


func _has_blocking_overlay(root: Node) -> bool:
	var go_node: Node = root.find_child("GameOverScreen", true, false)
	if go_node is CanvasItem and (go_node as CanvasItem).visible:
		return true
	var tut_layer: Node = root.find_child("TutorialLayer", true, false)
	if tut_layer is CanvasLayer and (tut_layer as CanvasLayer).visible:
		return true
	return false


func _is_online_match() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0


func _toggle_pause() -> void:
	var new_state: bool = not visible
	visible = new_state

	# Never freeze the SceneTree during an active online match
	if _is_online_match():
		get_tree().paused = false
	else:
		get_tree().paused = new_state


func _on_resume_pressed() -> void:
	_toggle_pause()


func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false

	if multiplayer.has_multiplayer_peer():
		NetworkManager.cancel_connection()

	TutorialManager.clear_active_tutorial()
	TrialManager.clear_active_trial()
	RunManager.clear_active_run_state()
	AudioManager.reset_audio_state()
	GlobalCinematics.reset_visuals()

	GameManager.bump_match_epoch()
	GameManager.next_match_p1_data = null
	GameManager.next_match_p2_data = null
	GameManager.p1_data = null
	GameManager.p2_data = null
	GameManager.editing_player_index = 1
	GameManager.p2_is_custom = false

	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
