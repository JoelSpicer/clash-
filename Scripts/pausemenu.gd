extends CanvasLayer

const BLOCKED_SCENES: Array[String] = [
	"MainMenu",
	"GameOverScreen",
	"SplashScreen",
	"VsScreen",
	"LeagueVictoryScreen",
]

@onready var background: ColorRect = $ColorRect

func _ready() -> void:
	# Start hidden and unpaused
	visible = false

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	# Ignore Escape while SceneLoader is mid-transition or before a scene is active
	if SceneLoader.overlay and SceneLoader.overlay.visible:
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	if current_scene.name in BLOCKED_SCENES:
		return

	_toggle_pause()

func _is_online_match() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0

func _toggle_pause() -> void:
	var new_state: bool = not visible
	visible = new_state

	# Never freeze the SceneTree during an active online match — doing so pauses
	# local heartbeats and clash animations and causes a server timeout kick.
	if _is_online_match():
		get_tree().paused = false
	else:
		get_tree().paused = new_state

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_main_menu_pressed() -> void:
	# 1. Hide overlay and guarantee the tree is unpaused before changing scenes
	visible = false
	get_tree().paused = false

	# 2. Cleanly disconnect if connected (or connecting) to an online multiplayer session
	if multiplayer.has_multiplayer_peer():
		NetworkManager.cancel_connection()

	# 3. Reset tutorial, audio, and visual states so nothing bleeds into the menu
	TutorialManager.is_tutorial_active = false
	TutorialManager.current_step = 0
	TutorialManager.active_script.clear()
	AudioManager.reset_audio_state()
	GlobalCinematics.reset_visuals()

	# 4. Wipe transient match/run flags so the next match starts fresh
	RunManager.is_boss_match = false
	RunManager.is_rival_match = false
	GameManager.next_match_p1_data = null
	GameManager.next_match_p2_data = null
	GameManager.p1_data = null
	GameManager.p2_data = null
	GameManager.editing_player_index = 1
	GameManager.p2_is_custom = false

	# 5. Return to Main Menu
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")
