extends Node3D

# ── The thing that makes it NOT Paper.io: a castle that visibly grows ─────────
# A procedural toy castle that rebuilds itself as the kingdom's territory crosses
# thresholds: lone keep -> walls -> corner towers -> citadel. Stone body in cream,
# roofs and banners in the kingdom's colour. Pops with a little bounce on upgrade.

var color: Color = Color.WHITE
var tier: int = 0

const BASE_Y := 0.07         # sits on the flat land slab
const STONE := Color("d8cdb5")

func set_color(c: Color) -> void:
	color = c

func update_tier(t: int) -> void:
	if t == tier:
		return
	var upgraded := t > tier
	tier = t
	_rebuild()
	if upgraded:
		_pop()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	# Keep (taller at the citadel tier).
	var keep_h := 1.5 if tier < 4 else 2.1
	_box(Vector3(1.3, keep_h, 1.3), Vector3(0, BASE_Y + keep_h * 0.5, 0), STONE)
	_cone(0.95, 0.8, Vector3(0, BASE_Y + keep_h + 0.4, 0), color)
	_flag(Vector3(0, BASE_Y + keep_h + 0.8, 0))

	if tier >= 2:
		_wall_ring(2.0, 0.7)

	if tier >= 3:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_tower(Vector3(sx * 2.0, 0, sz * 2.0), 1.7)

	if tier >= 4:
		# citadel: a second stacked block + corner banners
		_box(Vector3(0.9, 0.9, 0.9), Vector3(0, BASE_Y + 2.1, 0), STONE)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_flag(Vector3(sx * 2.0, BASE_Y + 1.9, sz * 2.0), 0.5)

func _wall_ring(half: float, h: float) -> void:
	var t := 0.28
	var y := BASE_Y + h * 0.5
	var span := half * 2.0 + t
	_box(Vector3(span, h, t), Vector3(0, y, -half), STONE)
	_box(Vector3(span, h, t), Vector3(0, y,  half), STONE)
	_box(Vector3(t, h, span), Vector3(-half, y, 0), STONE)
	_box(Vector3(t, h, span), Vector3( half, y, 0), STONE)

func _tower(pos: Vector3, h: float) -> void:
	_cyl(0.4, h, pos + Vector3(0, BASE_Y + h * 0.5, 0), STONE)
	_cone(0.5, 0.6, pos + Vector3(0, BASE_Y + h + 0.3, 0), color)

func _flag(top: Vector3, scale: float = 1.0) -> void:
	_box(Vector3(0.06, 0.7 * scale, 0.06), top + Vector3(0, 0.35 * scale, 0), Color("8a7f6a"))
	_box(Vector3(0.42 * scale, 0.26 * scale, 0.04),
		top + Vector3(0.22 * scale, 0.56 * scale, 0), color)

# ── primitive helpers ─────────────────────────────────────────────────────────
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m

func _box(size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)

func _cone(bottom_r: float, h: float, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = bottom_r
	cyl.height = h
	cyl.radial_segments = 4
	mi.mesh = cyl
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation.y = PI * 0.25
	add_child(mi)

func _cyl(r: float, h: float, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	mi.mesh = cyl
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)

func _pop() -> void:
	scale = Vector3(0.86, 0.86, 0.86)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector3.ONE, 0.35)
