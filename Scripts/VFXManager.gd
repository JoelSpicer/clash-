extends CanvasLayer


func _ready() -> void:
	layer = 5
	GameManager.clash_resolved.connect(_on_clash_resolved)
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.healing_received.connect(_on_healing_received)
	GameManager.wall_crush_occurred.connect(_on_wall_crush)
	GameManager.status_applied.connect(_on_status_applied)

	print("VFX Manager Initialized")
	if DisplayServer.get_name() != "headless":
		_warm_up_particles()


func _create_clash_particles() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 30
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 300.0
	mat.initial_velocity_max = 500.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 4.0
	mat.scale_max = 4.0
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color.YELLOW)
	grad.set_color(1, Color(1, 0.5, 0, 0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p


func _create_block_particles() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 1
	p.lifetime = 0.4
	p.one_shot = true
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	var grad: Gradient = Gradient.new()
	grad.remove_point(0)
	grad.add_point(0.5, Color(1, 1, 1, 0))
	grad.add_point(0.65, Color(1, 1, 1, 1))
	grad.add_point(0.7, Color(1, 1, 1, 0))
	tex.gradient = grad
	p.texture = tex
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, 0, 0)
	mat.color = Color(0.2, 0.8, 1.0, 0.8)
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.2))
	var curve_tex: CurveTexture = CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	p.process_material = mat
	return p


func _create_hit_particles() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 15
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 200.0
	mat.initial_velocity_max = 400.0
	mat.gravity = Vector3(0, 900, 0)
	mat.scale_min = 3.0
	mat.scale_max = 5.0
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 0.1, 0.1))
	grad.set_color(1, Color(0.5, 0, 0, 0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p


func _create_heal_particles() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 8
	p.lifetime = 1.0
	p.one_shot = true
	var img: Image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 40.0
	mat.gravity = Vector3(0, -100, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.2, 1.0, 0.2))
	grad.set_color(1, Color(0.2, 1.0, 0.2, 0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p


func _create_dodge_particles() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.8
	var img: Image = Image.create(16, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 40.0
	mat.gravity = Vector3(0, -50, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.8, 0.9, 1.0, 0.5))
	grad.set_color(1, Color(1, 1, 1, 0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p


func _create_super_particles() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 50
	p.lifetime = 1.5
	p.one_shot = true
	p.explosiveness = 0.0
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(40, 10, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 0.0
	mat.initial_velocity_min = 100.0
	mat.initial_velocity_max = 200.0
	mat.gravity = Vector3(0, 0, 0)
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 0.8, 0.2))
	grad.set_color(1, Color(0.5, 0, 0.5, 0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p


func _get_target_pos(id: int) -> Vector2:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var y_pos: float = screen_size.y * 0.4
	return Vector2(screen_size.x * 0.25, y_pos) if id == 1 else Vector2(screen_size.x * 0.75, y_pos)


func _spawn_vfx(particle_node: GPUParticles2D, pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		particle_node.free()
		return
	particle_node.position = pos
	add_child(particle_node)
	particle_node.emitting = true
	await get_tree().create_timer(particle_node.lifetime + 0.1).timeout
	if is_instance_valid(particle_node):
		particle_node.queue_free()


func _on_clash_resolved(_winner_id: int, _p1_card: ActionData, _p2_card: ActionData, _log_info: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	_spawn_vfx(_create_clash_particles(), center)

	if GameManager.state.p1_action_queue and GameManager.state.p1_action_queue.is_super:
		_trigger_super_visuals(1)
	if GameManager.state.p2_action_queue and GameManager.state.p2_action_queue.is_super:
		_trigger_super_visuals(2)


func _trigger_super_visuals(player_id: int) -> void:
	var dark: ColorRect = ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color.BLACK
	dark.modulate.a = 0.0
	add_child(dark)

	var tween: Tween = create_tween()
	tween.tween_property(dark, "modulate:a", 0.5, 0.2)
	tween.tween_property(dark, "modulate:a", 0.0, 0.5).set_delay(0.5)

	var pos: Vector2 = _get_target_pos(player_id)
	pos.y += 100.0
	_spawn_vfx(_create_super_particles(), pos)

	await tween.finished
	dark.queue_free()


func _on_damage_dealt(target_id: int, amount: int, is_blocked: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var pos: Vector2 = _get_target_pos(target_id)
	if is_blocked:
		_spawn_vfx(_create_block_particles(), pos)
		await get_tree().create_timer(0.1).timeout
		_spawn_vfx(_create_block_particles(), pos)
	elif amount > 0:
		_spawn_vfx(_create_hit_particles(), pos)


func _on_healing_received(target_id: int, _amount: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_spawn_vfx(_create_heal_particles(), _get_target_pos(target_id))


func _on_status_applied(target_id: int, status: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if status == "DODGED":
		_spawn_vfx(_create_dodge_particles(), _get_target_pos(target_id))


func _create_wall_debris() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = 20
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	var img: Image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.LIGHT_GRAY)
	p.texture = ImageTexture.create_from_image(img)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(1, -0.5, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 300.0
	mat.initial_velocity_max = 600.0
	mat.gravity = Vector3(0, 1500, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.angular_velocity_min = -300.0
	mat.angular_velocity_max = 300.0
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.7, 0.7, 0.7))
	grad.set_color(1, Color(0.7, 0.7, 0.7, 0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p


func _on_wall_crush(target_id: int, _damage: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var p: GPUParticles2D = _create_wall_debris()
	var mat: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	var spawn_pos: Vector2

	if target_id == 1:
		spawn_pos = Vector2(0, screen_size.y * 0.5)
		mat.direction = Vector3(1, -0.5, 0)
	else:
		spawn_pos = Vector2(screen_size.x, screen_size.y * 0.5)
		mat.direction = Vector3(-1, -0.5, 0)

	_spawn_vfx(p, spawn_pos)


func _warm_up_particles() -> void:
	var particles_to_test: Array[GPUParticles2D] = [
		_create_clash_particles(),
		_create_block_particles(),
		_create_hit_particles(),
		_create_heal_particles(),
		_create_dodge_particles(),
		_create_super_particles(),
		_create_wall_debris()
	]

	for p: GPUParticles2D in particles_to_test:
		p.position = Vector2(-9999, -9999)
		p.modulate.a = 0.0
		p.one_shot = true
		add_child(p)
		p.emitting = true
		get_tree().create_timer(0.5).timeout.connect(p.queue_free)

	print("VFX Shaders Pre-Compiled!")
