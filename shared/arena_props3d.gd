class_name ArenaProps3D
extends RefCounted

# Scatters cheerful decorative props (bushes, flowers, barrels, rocks) in the band
# OUTSIDE the brick walls, plus a soft grassy ground plane for them to sit on.
# Matches the lush garden border around the arena in the reference art
# (snake_target / race_target). Everything is built from primitives (no GLB
# pipeline) and placed deterministically from a seed so an arena looks identical
# every round but different per game.

const _GREENS := [Color("4fb05a"), Color("63c46d"), Color("3f9e4c"), Color("78cf76")]
const _FLOWERS := [Color("ff5d8f"), Color("ffd23f"), Color("ff8c42"),
	Color("c46bff"), Color("ff5a5a"), Color("ffffff")]
const _GROUND := Color("5aa83f")   # bright lush lawn green
# Dappled patch shades scattered over the lawn for a richer, less-flat look
const _GRASS_PATCH := [Color("66b84a"), Color("4f9c38"), Color("72c252"), Color("5aa83f")]
const _WOOD := Color("9a5f2c")
const _WOOD_BAND := Color("4a3320")
const _ROCK := Color("8b919c")
static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

# Build the outer grassy ground plane (sits just under the tiled floor), with a
# dapple of lighter/darker grass patches scattered over it for a lush, varied lawn.
static func ground(half_x: float, half_z: float, color: Color = _GROUND) -> Node3D:
	var root := Node3D.new()
	root.name = "Ground"
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(Vector3((half_x + 16.0) * 2.0, 0.2, (half_z + 16.0) * 2.0))
	mi.position = Vector3(0, -0.12, 0)
	mi.material_override = _mat(color, 0.9)
	root.add_child(mi)

	# Dappled grass patches — flat thin discs of varied green over the outer band.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var ox := half_x + 1.5
	var oz := half_z + 1.5
	for i in 90:
		# pick a point in the band outside the arena (reject the play area)
		var px := rng.randf_range(-(half_x + 15.0), half_x + 15.0)
		var pz := rng.randf_range(-(half_z + 15.0), half_z + 15.0)
		if absf(px) < ox + 0.5 and absf(pz) < oz + 0.5:
			continue
		var patch := MeshInstance3D.new()
		var r := rng.randf_range(1.2, 3.2)
		patch.mesh = _cylinder_mesh(r, r, 0.06)
		patch.material_override = _mat(_GRASS_PATCH[rng.randi() % _GRASS_PATCH.size()], 0.9)
		patch.position = Vector3(px, -0.01, pz)
		patch.scale = Vector3(1.0, 1.0, rng.randf_range(0.7, 1.3))
		root.add_child(patch)
	return root

# Scatter props around the outside of the arena. Returns a node to add to the scene.
static func scatter(half_x: float, half_z: float, seed_val: int = 1337) -> Node3D:
	var root := Node3D.new()
	root.name = "ArenaProps"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var t := 1.5
	var ox := half_x + t   # outer wall plane (X)
	var oz := half_z + t   # outer wall plane (Z)
	var lo := 1.1
	var hi := 5.5

	# North / South borders (props spread along X, just beyond ±oz) — two staggered
	# rows so the border reads as a dense, lush garden rather than a sparse line.
	var nx := 20
	for s in [-1.0, 1.0]:
		for i in nx:
			var x := lerpf(-ox - 4.0, ox + 4.0, (float(i) + rng.randf_range(0.10, 0.90)) / nx)
			var z: float = s * (oz + rng.randf_range(lo, hi))
			_place(root, rng, Vector3(x, 0, z))
	# East / West borders (props spread along Z, just beyond ±ox)
	var nz := 14
	for s in [-1.0, 1.0]:
		for i in nz:
			var z := lerpf(-oz - 4.0, oz + 4.0, (float(i) + rng.randf_range(0.10, 0.90)) / nz)
			var x: float = s * (ox + rng.randf_range(lo, hi))
			_place(root, rng, Vector3(x, 0, z))
	return root

static func _place(root: Node3D, rng: RandomNumberGenerator, pos: Vector3) -> void:
	var pick := rng.randf()
	var node: Node3D
	if pick < 0.26:
		node = _bush(rng)
	elif pick < 0.50:
		node = _flower(rng)
	elif pick < 0.68:
		node = _grass_tuft(rng)
	elif pick < 0.80:
		node = _tree(rng)
	elif pick < 0.88:
		node = _rock(rng)
	elif pick < 0.95:
		node = _barrel(rng)
	else:
		node = _banner(rng)
	node.position = pos
	node.rotation.y = rng.randf_range(0.0, TAU)
	var sc := rng.randf_range(0.85, 1.35)
	node.scale = Vector3(sc, sc, sc)
	root.add_child(node)

# ── prop builders ───────────────────────────────────────────────────────────
static func _bush(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var blobs := rng.randi_range(2, 4)
	for i in blobs:
		var s := MeshInstance3D.new()
		var r := rng.randf_range(0.5, 0.95)
		s.mesh = _sphere_mesh(r, r * 2.0)
		s.material_override = _mat(_GREENS[rng.randi() % _GREENS.size()], 0.6)
		s.position = Vector3(rng.randf_range(-0.45, 0.45), r * 0.75, rng.randf_range(-0.45, 0.45))
		s.scale.y = rng.randf_range(0.8, 1.15)
		n.add_child(s)
	return n

static func _grass_tuft(rng: RandomNumberGenerator) -> Node3D:
	# A little cluster of upright grass blades — cheap lushness filler.
	var n := Node3D.new()
	var blades := rng.randi_range(4, 7)
	var col: Color = _GREENS[rng.randi() % _GREENS.size()]
	for i in blades:
		var b := MeshInstance3D.new()
		var h := rng.randf_range(0.35, 0.7)
		b.mesh = _prism_mesh(Vector3(0.12, h, 0.12))
		b.material_override = _mat(col, 0.75)
		b.position = Vector3(rng.randf_range(-0.28, 0.28), h * 0.5, rng.randf_range(-0.28, 0.28))
		b.rotation.z = rng.randf_range(-0.25, 0.25)
		n.add_child(b)
	return n

static func _flower(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(0.6, 1.0)
	# stem
	var stem := MeshInstance3D.new()
	stem.mesh = _cylinder_mesh(0.05, 0.06, h)
	stem.material_override = _mat(Color("2f8f3e"), 0.7)
	stem.position = Vector3(0, h * 0.5, 0)
	n.add_child(stem)
	# bloom: center + petals
	var col: Color = _FLOWERS[rng.randi() % _FLOWERS.size()]
	var center := MeshInstance3D.new()
	center.mesh = _sphere_mesh(0.13, 0.26)
	center.material_override = _mat(Color("ffd23f"), 0.5, true, 0.25)
	center.position = Vector3(0, h, 0)
	n.add_child(center)
	for p in 5:
		var petal := MeshInstance3D.new()
		petal.mesh = _sphere_mesh(0.14, 0.20)
		petal.material_override = _mat(col, 0.45)
		var a := TAU * float(p) / 5.0
		petal.position = Vector3(cos(a) * 0.18, h, sin(a) * 0.18)
		petal.scale = Vector3(1.0, 0.5, 1.0)
		n.add_child(petal)
	return n

static func _barrel(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(1.0, 1.3)
	var r := rng.randf_range(0.5, 0.62)
	var body := MeshInstance3D.new()
	body.mesh = _cylinder_mesh(r * 0.92, r * 0.92, h)
	body.material_override = _mat(_WOOD, 0.55)
	body.position = Vector3(0, h * 0.5, 0)
	n.add_child(body)
	for frac in [0.25, 0.75]:
		var band := MeshInstance3D.new()
		band.mesh = _cylinder_mesh(r, r, 0.12)
		band.material_override = _mat(_WOOD_BAND, 0.4, false, 0.0)
		band.position = Vector3(0, h * frac, 0)
		n.add_child(band)
	return n

static func _tree(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(1.6, 2.6)
	# trunk
	var trunk := MeshInstance3D.new()
	trunk.mesh = _cylinder_mesh(0.16, 0.22, h)
	trunk.material_override = _mat(_WOOD, 0.7)
	trunk.position = Vector3(0, h * 0.5, 0)
	n.add_child(trunk)
	# canopy: 1-2 chunky green spheres stacked
	var canopies := rng.randi_range(1, 2)
	for i in canopies:
		var leaf := MeshInstance3D.new()
		var r := rng.randf_range(0.95, 1.35) * (1.0 - 0.18 * i)
		leaf.mesh = _sphere_mesh(r, r * 2.0)
		leaf.material_override = _mat(_GREENS[rng.randi() % _GREENS.size()], 0.6)
		leaf.position = Vector3(rng.randf_range(-0.25, 0.25), h + r * 0.6 + i * 0.7,
			rng.randf_range(-0.25, 0.25))
		n.add_child(leaf)
	return n

static func _banner(rng: RandomNumberGenerator) -> Node3D:
	# Two posts with a colorful cloth strung between — a festive party banner.
	var n := Node3D.new()
	var h := rng.randf_range(1.6, 2.0)
	var span := rng.randf_range(1.8, 2.6)
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = _cylinder_mesh(0.08, 0.09, h)
		post.material_override = _mat(_WOOD, 0.7)
		post.position = Vector3(sx * span * 0.5, h * 0.5, 0)
		n.add_child(post)
	var cloth := MeshInstance3D.new()
	cloth.mesh = _box_mesh(Vector3(span, 0.55, 0.06))
	cloth.material_override = _mat(_FLOWERS[rng.randi() % _FLOWERS.size()], 0.5, true, 0.2)
	cloth.position = Vector3(0, h - 0.4, 0)
	n.add_child(cloth)
	return n

static func _rock(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var r := rng.randf_range(0.4, 0.75)
	var s := MeshInstance3D.new()
	s.mesh = _sphere_mesh(r, r * 2.0)
	s.material_override = _mat(_ROCK.lerp(Color("6f7682"), rng.randf()), 0.7)
	s.position = Vector3(0, r * 0.55, 0)
	s.scale = Vector3(1.0, rng.randf_range(0.55, 0.8), rng.randf_range(0.85, 1.15))
	n.add_child(s)
	return n

# Spinning collectible star — for games that want pickups inside the arena.
static func star(color: Color = Color("ffd23f")) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _prism_mesh(Vector3(0.7, 0.7, 0.18))
	mi.material_override = _mat(color, 0.3, true, 0.9)
	return mi

static func _mat(color: Color, rough: float = 0.45, emissive: bool = false,
		emis_e: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%.3f|%s|%.3f" % [color.to_html(), rough, str(emissive), emis_e]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emis_e
	_material_cache[key] = m
	return m

static func _sphere_mesh(radius: float, height: float) -> SphereMesh:
	var key := "sphere|%.3f|%.3f" % [radius, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	_mesh_cache[key] = mesh
	return mesh

static func _cylinder_mesh(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var key := "cyl|%.3f|%.3f|%.3f" % [top_radius, bottom_radius, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	_mesh_cache[key] = mesh
	return mesh

static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "box|%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_cache[key] = mesh
	return mesh

static func _prism_mesh(size: Vector3) -> PrismMesh:
	var key := "prism|%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := PrismMesh.new()
	mesh.size = size
	_mesh_cache[key] = mesh
	return mesh
