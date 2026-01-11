extends CanvasLayer

func _ready():
	layer = 5 
	GameManager.clash_resolved.connect(_on_clash_resolved)
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.healing_received.connect(_on_healing_received)
	
	# NEW: Listen for status updates to trigger Dodge effects
	GameManager.status_applied.connect(_on_status_applied)
	
	print("VFX Manager Initialized")

# ==============================================================================
# 1. PARTICLE GENERATORS (Templates)
# ==============================================================================

# ... (Keep _create_clash_particles as is) ...
func _create_clash_particles() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.amount = 30
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180
	mat.initial_velocity_min = 300
	mat.initial_velocity_max = 500
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 4.0
	mat.scale_max = 4.0
	var grad = Gradient.new()
	grad.set_color(0, Color.YELLOW)
	grad.set_color(1, Color(1, 0.5, 0, 0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p

# ... (Keep _create_block_particles as is) ...
func _create_block_particles() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.amount = 1; p.lifetime = 0.4; p.one_shot = true
	var tex = GradientTexture2D.new()
	tex.width = 128; tex.height = 128; tex.fill = GradientTexture2D.FILL_RADIAL
	var grad = Gradient.new()
	grad.remove_point(0)
	grad.add_point(0.5, Color(1, 1, 1, 0))
	grad.add_point(0.65, Color(1, 1, 1, 1))
	grad.add_point(0.7, Color(1, 1, 1, 0))
	tex.gradient = grad
	p.texture = tex
	var mat = ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, 0, 0)
	mat.color = Color(0.2, 0.8, 1.0, 0.8)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.5)); curve.add_point(Vector2(1, 1.2))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	p.process_material = mat
	return p

# ... (Keep _create_hit_particles as is) ...
func _create_hit_particles() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.amount = 15; p.lifetime = 0.6; p.one_shot = true; p.explosiveness = 0.9
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0); mat.spread = 45
	mat.initial_velocity_min = 200; mat.initial_velocity_max = 400
	mat.gravity = Vector3(0, 900, 0); mat.scale_min = 3.0; mat.scale_max = 5.0
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 0.1, 0.1)); grad.set_color(1, Color(0.5, 0, 0, 0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p

# ... (Keep _create_heal_particles as is) ...
func _create_heal_particles() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.amount = 8; p.lifetime = 1.0; p.one_shot = true
	var img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 40.0; mat.gravity = Vector3(0, -100, 0)
	mat.scale_min = 2.0; mat.scale_max = 4.0
	var grad = Gradient.new()
	grad.set_color(0, Color(0.2, 1.0, 0.2)); grad.set_color(1, Color(0.2, 1.0, 0.2, 0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	return p

# --- NEW: DODGE PARTICLES (Ghostly Wind) ---
func _create_dodge_particles() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.8
	
	# Texture: Horizontal Streak
	var img = Image.create(16, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0) # Just float
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 40.0
	mat.gravity = Vector3(0, -50, 0) # Rise slightly
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	
	# Color: White -> Transparent
	var grad = Gradient.new()
	grad.set_color(0, Color(0.8, 0.9, 1.0, 0.5)) # Misty Blue-White
	grad.set_color(1, Color(1, 1, 1, 0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	
	p.process_material = mat
	return p

# --- NEW: SUPER PARTICLES (Rising Aura) ---
func _create_super_particles() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.amount = 50
	p.lifetime = 1.5
	p.one_shot = true
	p.explosiveness = 0.0 # Stream
	
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(40, 10, 1) # Floor area
	mat.direction = Vector3(0, -1, 0) # Up
	mat.spread = 0
	mat.initial_velocity_min = 100
	mat.initial_velocity_max = 200
	mat.gravity = Vector3(0, 0, 0)
	
	# Color: Gold/Purple
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 0.8, 0.2)) # Gold
	grad.set_color(1, Color(0.5, 0, 0.5, 0)) # Purple fade
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	
	p.process_material = mat
	return p

# ==============================================================================
# SPAWN LOGIC
# ==============================================================================

func _get_target_pos(id: int) -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	var y_pos = screen_size.y * 0.4 
	if id == 1: return Vector2(screen_size.x * 0.25, y_pos)
	else: return Vector2(screen_size.x * 0.75, y_pos)

func _spawn_vfx(particle_node: GPUParticles2D, pos: Vector2):
	particle_node.position = pos
	add_child(particle_node)
	particle_node.emitting = true
	await get_tree().create_timer(particle_node.lifetime + 0.1).timeout
	particle_node.queue_free()

func _on_clash_resolved(winner_id, _text):
	# 1. Standard Clash Explosion
	var center = get_viewport().get_visible_rect().size / 2
	_spawn_vfx(_create_clash_particles(), center)
	
	# 2. CHECK FOR SUPER MOVES (Visual Juiciness)
	# We peek at the GameManager to see if a Super was used
	if GameManager.p1_action_queue and GameManager.p1_action_queue.is_super:
		_trigger_super_visuals(1)
	if GameManager.p2_action_queue and GameManager.p2_action_queue.is_super:
		_trigger_super_visuals(2)

func _trigger_super_visuals(player_id: int):
	# Darken screen slightly
	var dark = ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color.BLACK
	dark.modulate.a = 0.0
	add_child(dark)
	
	var tween = create_tween()
	tween.tween_property(dark, "modulate:a", 0.5, 0.2)
	tween.tween_property(dark, "modulate:a", 0.0, 0.5).set_delay(0.5)
	
	# Play Rising Aura
	var pos = _get_target_pos(player_id)
	# Shift aura down to feet
	pos.y += 100 
	_spawn_vfx(_create_super_particles(), pos)
	
	await tween.finished
	dark.queue_free()

func _on_damage_dealt(target_id: int, amount: int, is_blocked: bool):
	var pos = _get_target_pos(target_id)
	
	if is_blocked:
		_spawn_vfx(_create_block_particles(), pos)
		await get_tree().create_timer(0.1).timeout
		_spawn_vfx(_create_block_particles(), pos)
	elif amount > 0:
		_spawn_vfx(_create_hit_particles(), pos)

func _on_healing_received(target_id: int, _amount: int):
	var pos = _get_target_pos(target_id)
	_spawn_vfx(_create_heal_particles(), pos)

# NEW: Specific handler for Dodge
func _on_status_applied(target_id: int, status: String):
	if status == "DODGED":
		var pos = _get_target_pos(target_id)
		_spawn_vfx(_create_dodge_particles(), pos)
