extends Node3D

# ── Capture celebration VFX ───────────────────────────────────────────────────
# One-shot confetti + gold-coin bursts in the 3D world, fired when the PLAYER
# claims land or wins. Pure GPUParticles3D (GPU-side, freed after their lifetime),
# unshaded + emissive so coins bloom past the scene HDR threshold. Mobile thins the
# particle counts. Kept world-space so the burst stays where the land was captured.

var _fade_grad: GradientTexture1D       # shared white→transparent alpha ramp

func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_fade_grad = GradientTexture1D.new()
	_fade_grad.gradient = g

# Confetti (kingdom colour + bright accents) + a gold coin pop at a world point.
func burst(pos: Vector3, color: Color) -> void:
	var mul: float = 0.5 if DeviceMode.is_mobile else 1.0
	var accents := [color, Color("fff3c4"), Color("ff5d8f"), Color("4cd2ff")]
	for c in accents:
		_confetti(pos, c, int(8 * mul))
	_coins(pos, int(10 * mul))

# A bigger sustained shower for the victory orbit.
func fireworks(pos: Vector3, color: Color) -> void:
	var accents := [color, Color("ffd95a"), Color("ff5d8f"), Color("8affc1"), Color("c9a6ff")]
	for c in accents:
		_confetti(pos + Vector3(0, 2.0, 0), c, 22)
	_coins(pos, 18)

func _confetti(pos: Vector3, color: Color, amount: int) -> void:
	if amount <= 0:
		return
	var p := GPUParticles3D.new()
	add_child(p)
	p.global_position = pos + Vector3(0, 0.5, 0)
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.4
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.35
	m.direction = Vector3(0, 1, 0)
	m.spread = 60.0
	m.initial_velocity_min = 3.5
	m.initial_velocity_max = 7.0
	m.gravity = Vector3(0, -9.5, 0)
	m.angular_velocity_min = -540.0
	m.angular_velocity_max = 540.0
	m.scale_min = 0.6
	m.scale_max = 1.2
	m.color = color
	m.color_ramp = _fade_grad
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qm
	p.draw_pass_1 = quad
	p.emitting = true
	_free_after(p, p.lifetime + 0.5)

func _coins(pos: Vector3, amount: int) -> void:
	if amount <= 0:
		return
	var p := GPUParticles3D.new()
	add_child(p)
	p.global_position = pos + Vector3(0, 0.4, 0)
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 1.1
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.25
	m.direction = Vector3(0, 1, 0)
	m.spread = 35.0
	m.initial_velocity_min = 4.5
	m.initial_velocity_max = 7.5
	m.gravity = Vector3(0, -12.0, 0)
	m.angular_velocity_min = -720.0
	m.angular_velocity_max = 720.0
	m.scale_min = 0.7
	m.scale_max = 1.1
	m.color = Color(1, 1, 1, 1)
	m.color_ramp = _fade_grad
	p.process_material = m
	# Flattened gold disc = a coin; emissive so it catches the bloom.
	var coin := CylinderMesh.new()
	coin.top_radius = 0.12
	coin.bottom_radius = 0.12
	coin.height = 0.03
	coin.radial_segments = 8
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("ffcf3f")
	cm.emission_enabled = true
	cm.emission = Color("ffcf3f")
	cm.emission_energy_multiplier = 1.6
	cm.vertex_color_use_as_albedo = true
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	coin.material = cm
	p.draw_pass_1 = coin
	p.emitting = true
	_free_after(p, p.lifetime + 0.5)

func _free_after(n: Node, secs: float) -> void:
	var t := get_tree().create_timer(secs)
	t.timeout.connect(n.queue_free)
