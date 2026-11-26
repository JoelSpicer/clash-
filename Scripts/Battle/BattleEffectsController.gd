extends Node
class_name BattleEffectsController

var host_layer: CanvasLayer
var background: TextureRect
var clash_layer: Control
var left_card_display: Control
var right_card_display: Control
var p1_hud: Control
var p2_hud: Control
var momentum_tracker: Control
var p1_bark_label: PanelContainer
var p2_bark_label: PanelContainer
var floating_text_scene: PackedScene

var camera: Camera2D
var shake_strength: float = 0.0
var shake_decay: float = 5.0
var zoom_strength: float = 0.0
var zoom_decay: float = 5.0
var max_parallax: float = 15.0
var parallax_smoothness: float = 4.0
var base_bg_pos: Vector2 = Vector2.ZERO
var finisher_triggered: bool = false


func setup(
	p_host: CanvasLayer,
	p_background: TextureRect,
	p_clash_layer: Control,
	p_left_card: Control,
	p_right_card: Control,
	p_p1_hud: Control,
	p_p2_hud: Control,
	p_momentum_tracker: Control,
	p_p1_bark: PanelContainer,
	p_p2_bark: PanelContainer,
	p_floating_text_scene: PackedScene
) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host_layer = p_host
	background = p_background
	clash_layer = p_clash_layer
	left_card_display = p_left_card
	right_card_display = p_right_card
	p1_hud = p_p1_hud
	p2_hud = p_p2_hud
	momentum_tracker = p_momentum_tracker
	p1_bark_label = p_p1_bark
	p2_bark_label = p_p2_bark
	floating_text_scene = p_floating_text_scene

	if GlobalCinematics:
		GlobalCinematics.reset_visuals()

	# Hardware Camera2D for CanvasLayer zoom & shake
	camera = Camera2D.new()
	camera.position = host_layer.get_viewport().get_visible_rect().size / 2.0
	host_layer.add_child(camera)
	host_layer.follow_viewport_enabled = true

	if clash_layer:
		clash_layer.visible = false


func _process(delta: float) -> void:
	var is_frozen: bool = (finisher_triggered and get_tree().paused)

	if not is_frozen:
		if shake_strength > 0.0:
			shake_strength = lerpf(shake_strength, 0.0, shake_decay * delta)
			if shake_strength < 0.1:
				shake_strength = 0.0

		if zoom_strength > 0.0:
			zoom_strength = lerpf(zoom_strength, 0.0, zoom_decay * delta)
			if zoom_strength < 0.001:
				zoom_strength = 0.0

	if camera:
		var current_zoom: float = 1.0 + zoom_strength
		camera.zoom = Vector2(current_zoom, current_zoom)
		if shake_strength > 0.0:
			camera.offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
		else:
			camera.offset = Vector2.ZERO

	if background and not is_frozen:
		var screen_size: Vector2 = get_viewport().get_visible_rect().size
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var center: Vector2 = screen_size / 2.0
		if center.x > 0.0 and center.y > 0.0:
			var mouse_offset: Vector2 = Vector2(
				(mouse_pos.x - center.x) / center.x,
				(mouse_pos.y - center.y) / center.y
			)
			var target_pos: Vector2 = base_bg_pos - (mouse_offset * max_parallax)
			background.position = background.position.lerp(target_pos, delta * parallax_smoothness)


func update_background() -> void:
	if not background:
		return
	var env_name: String = GameManager.current_environment_name
	if GameManager.environment_backgrounds.has(env_name):
		background.texture = GameManager.environment_backgrounds[env_name]
	else:
		print("Warning: No art found for '" + env_name + "'. Using default.")


func init_background_parallax() -> void:
	if not background:
		return
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	background.pivot_offset = screen_size / 2.0
	background.scale = Vector2(1.05, 1.05)
	base_bg_pos = background.position


func apply_camera_impact(zoom_amount: float, shake_amount: float) -> void:
	zoom_strength = maxf(zoom_strength, zoom_amount)
	shake_strength = maxf(shake_strength, shake_amount)


func play_finisher_sequence() -> void:
	if finisher_triggered:
		return
	finisher_triggered = true

	HitStopManager.stop_frame(1.5)
	zoom_strength = 0.45
	shake_strength = 0.0

	if GlobalCinematics:
		GlobalCinematics.apply_finisher_effect()


func reset_finisher_state() -> void:
	finisher_triggered = false
	if GlobalCinematics:
		GlobalCinematics.reset_visuals()


func play_clash_animation(p1_card: ActionData, p2_card: ActionData) -> void:
	clash_layer.visible = true

	if p1_card != null:
		left_card_display.call("set_card_data", p1_card)
		left_card_display.visible = true
	else:
		left_card_display.visible = false

	if p2_card != null:
		right_card_display.call("set_card_data", p2_card)
		right_card_display.visible = true
	else:
		right_card_display.visible = false

	var card_size: Vector2 = Vector2(250, 350)
	left_card_display.custom_minimum_size = card_size
	right_card_display.custom_minimum_size = card_size
	left_card_display.pivot_offset = card_size / 2.0
	right_card_display.pivot_offset = card_size / 2.0

	var center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	left_card_display.position = Vector2(-400.0, center.y - (card_size.y / 2.0))
	right_card_display.position = Vector2(center.x * 2.0 + 400.0, center.y - (card_size.y / 2.0))

	# 1. Smash inward
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(left_card_display, "position:x", center.x - (card_size.x / 2.0), 0.25)
	tween.tween_property(right_card_display, "position:x", center.x - (card_size.x / 2.0), 0.25)
	await tween.finished

	# 2. Impact shake + SFX
	apply_camera_impact(0.1, 30.0)
	AudioManager.play_sfx("hit_heavy", 0.1)

	# 3. White impact flash
	var flash: ColorRect = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	clash_layer.add_child(flash)

	var f_tween: Tween = create_tween()
	f_tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	f_tween.tween_callback(flash.queue_free)

	# 4. Recoil bounce
	var bounce_tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(left_card_display, "position:x", center.x - card_size.x - 20.0, 0.3)
	bounce_tween.tween_property(right_card_display, "position:x", center.x + 20.0, 0.3)

	HitStopManager.stop_frame(0.2)
	await get_tree().create_timer(1.2).timeout

	clash_layer.visible = false
	GameManager.clash_animation_finished.emit()


func play_wall_crush_shake(target_id: int) -> void:
	apply_camera_impact(0.05, 15.0)
	if not momentum_tracker:
		return
	var original_x: float = momentum_tracker.position.x
	var shake_dir: float = -10.0 if target_id == 1 else 10.0
	var tween: Tween = create_tween()
	tween.tween_property(momentum_tracker, "position:x", original_x + shake_dir, 0.05)
	tween.tween_property(momentum_tracker, "position:x", original_x, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func spawn_floating_text(target_id: int, text: String, color: Color, y_offset: float = 0.0) -> void:
	if not floating_text_scene or not host_layer:
		return
	var pos: Vector2 = _get_clash_text_pos(target_id)
	pos.y += y_offset
	var popup: Node = floating_text_scene.instantiate()
	host_layer.add_child(popup)
	popup.call("setup", text, color, pos)


func show_bark(player_id: int, text: String) -> void:
	var bubble: PanelContainer = p1_bark_label if player_id == 1 else p2_bark_label
	if not bubble:
		return
	var text_label: Label = bubble.get_child(0) as Label
	if text_label:
		text_label.text = text

	bubble.modulate.a = 0.0
	bubble.pivot_offset = Vector2(bubble.size.x / 2.0, bubble.size.y)
	bubble.scale = Vector2(0.5, 0.5)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bubble, "modulate:a", 1.0, 0.2)
	tween.tween_property(bubble, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.1)
	tween.chain().tween_interval(1.5)
	tween.chain().tween_property(bubble, "modulate:a", 0.0, 0.3)


func show_player_identity_flash() -> void:
	if not host_layer:
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	if multiplayer.is_server() or OS.get_cmdline_args().has("--server"):
		return

	var my_id: int = multiplayer.get_unique_id()
	var is_p1: bool = (my_id == GameManager.p1_network_id)

	var flash_label: Label = Label.new()
	flash_label.text = "YOU ARE PLAYER 1\n(LEFT SIDE)" if is_p1 else "YOU ARE PLAYER 2\n(RIGHT SIDE)"
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash_label.add_theme_font_size_override("font_size", 64)
	flash_label.add_theme_color_override("font_color", Color.CYAN if is_p1 else Color.RED)
	flash_label.add_theme_color_override("font_outline_color", Color.BLACK)
	flash_label.add_theme_constant_override("outline_size", 12)
	flash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host_layer.add_child(flash_label)
	host_layer.move_child(flash_label, 1)

	flash_label.scale = Vector2(0.5, 0.5)
	flash_label.modulate.a = 0.0
	flash_label.pivot_offset = get_viewport().get_visible_rect().size / 2.0

	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_label, "scale", Vector2(1.0, 1.0), 0.4)
	tween.parallel().tween_property(flash_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.5)
	tween.tween_property(flash_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(flash_label.queue_free)


func _get_clash_text_pos(target_id: int) -> Vector2:
	var hud: Control = p1_hud if target_id == 1 else p2_hud
	var pos: Vector2 = hud.global_position + (hud.size / 2.0)
	var center_offset: float = 100.0
	pos.y += 75.0
	if target_id == 1:
		pos.x += center_offset
	else:
		pos.x -= center_offset
	return pos
