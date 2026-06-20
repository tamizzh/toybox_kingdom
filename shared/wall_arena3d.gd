class_name WallArena3D
extends RefCounted

# Builds a 3D toy-box arena matching the reference art style:
#   Floor  : dark stone tiles (4-unit grid) — ~6 tiles across, ~4 deep
#   Walls  : ONE row of large chunky blocks (4×3×1.5 units each) from brick.glb
#            ~6-7 blocks on long sides, ~4 on short sides (matches reference)
#   Colour : 4-colour palette cycling per block (red / yellow / blue / green)
#
# Brick model baked at exact Godot dims (X=4, Y=3, Z=1.5) so bevel stays uniform.
# Z-aligned (East/West) walls rotate bricks 90° around Y.

const BRICK_SCENE := preload("res://assets/models/brick.glb")
const TILE_SCENE  := preload("res://assets/models/floor_tile.glb")
const CRATE_SCENE := preload("res://assets/models/crate.glb")

# Toy-box surface shaders (see shaders/).
const _BLOCK_SHADER := preload("res://shaders/toy_block.gdshader")
const _FLOOR_SHADER := preload("res://shaders/slate_floor.gdshader")
const _STAR_TEX     := preload("res://assets/star_overlay.png")
const _SLATE_NOISE  := preload("res://assets/slate_noise.png")
const _BLOB_TEX     := preload("res://assets/blob_shadow.png")

const _BRICK_COLORS := [
	Color("e83030"),  # red
	Color("f5c020"),  # yellow
	Color("1878f0"),  # blue
	Color("28c050"),  # green
]

# Brick physical dimensions in Godot units (must match gen_brick.py output)
const BRICK_W := 4.0   # width along the wall (Godot X for N/S walls)
const BRICK_H := 3.0   # height
const BRICK_D := 1.5   # depth into arena (= wall thickness t)

# Rendered toy-cube dimensions (decoupled from the thin collision wall). Smaller
# width → more cubes per side; taller + deeper → chunky molded-plastic look.
const BLOCK_W     := 3.2   # target rendered block width along the wall
const BLOCK_VIS_H := 2.2   # rendered block height
const BLOCK_VIS_D := 1.5   # rendered block depth
static var _material_cache: Dictionary = {}

static func build(half_x: float, half_z: float,
				   wall_h: float = 1.6, t: float = 0.95,
				   props: bool = true, crates: bool = true,
				   floor_tex: Texture2D = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Arena3D"

	# ── grassy outer ground + decorative border props ───────────────────────────
	# A soft moss ground plane under the arena, with bushes/flowers/barrels/rocks
	# scattered in the band outside the walls (matches the garden border in the
	# reference art). Built first so it sits behind everything.
	if props:
		root.add_child(ArenaProps3D.ground(half_x, half_z))
		root.add_child(ArenaProps3D.scatter(half_x, half_z))

	# ── floor ─────────────────────────────────────────────────────────────────
	if floor_tex != null:
		# Textured floor: one flat plane covering the whole arena with the
		# illustrated category texture (racing track, soccer pitch, etc.).
		var plane := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(half_x * 2.0, half_z * 2.0)
		pm.subdivide_width  = 1
		pm.subdivide_depth  = 1
		plane.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = floor_tex
		mat.roughness      = 0.85
		mat.metallic       = 0.0
		# Brighten the texture slightly so it reads under the 3D lighting
		mat.albedo_color   = Color(1.15, 1.15, 1.15)
		plane.material_override = mat
		plane.position = Vector3(0, 0.01, 0)   # sit just above y=0 to avoid z-fight
		root.add_child(plane)
	else:
		# Procedural checkerboard tiled floor (default): plush pillow slabs from
		# floor_tile.glb (heavily rounded) — soft 3D cushions matching the
		# reference art. The wide grout gap + dark sub-floor read as soft seams.
		var ts    := 4.0    # tile pitch (= brick width for visual alignment)
		var gap   := 0.20   # grout gap between tiles (wider → pillows read separate)
		var tile_s := ts - gap   # rendered tile size

		var nz   := ceili(half_z / ts)   # enough rows to cover ±half_z
		var nx_t := ceili(half_x / ts)   # enough cols to cover ±half_x

		# Dark sub-floor under the tiles so the grout gaps read as dark seams
		# (not the green grass below) and SSAO has something to shade against.
		var sub := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(half_x * 2.0 + ts, 0.4, half_z * 2.0 + ts)
		sub.mesh = sm
		sub.position = Vector3(0, -0.205, 0)
		var subm := StandardMaterial3D.new()
		subm.albedo_color = Color("2a333f")   # dark slate grout
		subm.roughness = 0.95
		sub.material_override = subm
		root.add_child(sub)

		# Checkerboard: two alternating muted grey-blue slate shades. The actual
		# colours live in slate_floor.gdshader (slate_a / slate_b); _apply_floor
		# just flips tile_blend per cell so the noise/roughness break-up applies.
		for iz in range(-nz, nz):
			for ix in range(-nx_t, nx_t):
				var ti := TILE_SCENE.instantiate()
				# slab is 0.45 tall now → centre at -0.225 keeps the top at y=0
				ti.position = Vector3(
					(float(ix) + 0.5) * ts,
					-0.225,
					(float(iz) + 0.5) * ts)
				ti.scale = Vector3(tile_s / 4.0, 1.0, tile_s / 4.0)
				_apply_floor(ti, (ix + iz) % 2 == 0)
				root.add_child(ti)

	# ── walls ─────────────────────────────────────────────────────────────────
	# Each wall: one StaticBody3D for collision + a row of LEGO blocks.
	# N/S walls extend along X (bricks default orientation).
	# E/W walls extend along Z (bricks rotated 90° around Y).
	var specs := [
		# North (−Z)
		{"ctr": Vector3(0, wall_h * 0.5, -half_z - t * 0.5),
		 "sz":  Vector3(half_x * 2.0 + t * 2.0, wall_h, t), "rot_y": 0.0},
		# South (+Z)
		{"ctr": Vector3(0, wall_h * 0.5,  half_z + t * 0.5),
		 "sz":  Vector3(half_x * 2.0 + t * 2.0, wall_h, t), "rot_y": 0.0},
		# West  (−X)
		{"ctr": Vector3(-half_x - t * 0.5, wall_h * 0.5, 0),
		 "sz":  Vector3(t, wall_h, half_z * 2.0), "rot_y": PI * 0.5},
		# East  (+X)
		{"ctr": Vector3( half_x + t * 0.5, wall_h * 0.5, 0),
		 "sz":  Vector3(t, wall_h, half_z * 2.0), "rot_y": PI * 0.5},
	]

	var brick_idx := 0

	for spec in specs:
		var ctr: Vector3 = spec["ctr"]
		var sz:  Vector3 = spec["sz"]
		var rot_y: float = spec["rot_y"]

		# Collision box for the full wall side
		var body := StaticBody3D.new()
		body.position        = ctr
		body.collision_layer = 2
		body.collision_mask  = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size  = sz
		cs.shape = bs
		body.add_child(cs)
		root.add_child(body)

		# Brick visuals — brick width in the wall-length direction
		# For rot_y=0 bricks: length spans X (sz.x).
		# For rot_y=PI/2 bricks: length spans Z (sz.z).
		# Chunky toy cubes: more, smaller blocks than the wall-length / model-width
		# would give, rendered taller and deeper than the collision box so the
		# border reads as molded plastic cubes (reference art), independent of the
		# (thin) collision wall_h / t.
		var wall_len := sz.z if rot_y > 0.01 else sz.x
		var n_bricks := int(round(wall_len / BLOCK_W))
		if n_bricks < 1:
			n_bricks = 1
		var actual_bw := wall_len / float(n_bricks)
		# Lift so each block's base sits on the floor (y=0) regardless of wall_h.
		var by := BLOCK_VIS_H * 0.5 - wall_h * 0.5

		for bi in n_bricks:
			var bc: Color = _BRICK_COLORS[brick_idx % _BRICK_COLORS.size()]
			brick_idx += 1

			# Offset from wall centre along the wall-length axis
			var offset := -wall_len * 0.5 + (float(bi) + 0.5) * actual_bw

			# Brick centre relative to StaticBody3D
			var bpos: Vector3
			if rot_y > 0.01:
				bpos = Vector3(0, by, offset)
			else:
				bpos = Vector3(offset, by, 0)

			var sc := Vector3(actual_bw / BRICK_W, BLOCK_VIS_H / BRICK_H, BLOCK_VIS_D / BRICK_D)
			_add_brick(body, bpos, rot_y, bc, sc)

	# ── decorative crates ─────────────────────────────────────────────────────
	# Four crates at symmetric positions inside the arena — give depth / cover.
	# Scale = 2.0 so each crate is 2×2×2 units (visible at game distance).
	# Placed on the midpoints between centre and corners, collision_layer=2
	# so avatars and bullets interact with them.
	var crate_spots := [] if not crates else [
		Vector3(-half_x * 0.45,  0.0, -half_z * 0.45),
		Vector3( half_x * 0.45,  0.0, -half_z * 0.45),
		Vector3(-half_x * 0.45,  0.0,  half_z * 0.45),
		Vector3( half_x * 0.45,  0.0,  half_z * 0.45),
	]
	for pos in crate_spots:
		var body := StaticBody3D.new()
		body.position = pos + Vector3(0, 1.0, 0)
		body.collision_layer = 2
		body.collision_mask  = 0
		var cs2 := CollisionShape3D.new()
		var box2 := BoxShape3D.new()
		box2.size = Vector3(2.0, 2.0, 2.0)
		cs2.shape  = box2
		body.add_child(cs2)
		var ci := CRATE_SCENE.instantiate()
		ci.scale = Vector3(2.0, 2.0, 2.0)
		ci.position = Vector3(0, -1.0, 0)  # offset so base sits on floor
		body.add_child(ci)
		root.add_child(body)

		# Fake contact-shadow blob under the crate (SSAO substitute on Mobile).
		# Depth derived from the blob texture's aspect so it stays round, not oval.
		var blob := Decal.new()
		blob.texture_albedo = _BLOB_TEX
		blob.modulate = Color(0, 0, 0, 0.5)
		var bts := _BLOB_TEX.get_size()
		var b_aspect: float = bts.y / bts.x if bts.x > 0.0 else 1.0
		blob.size = Vector3(3.0, 1.4, 3.0 * b_aspect)
		blob.position = pos + Vector3(0, 0.06, 0)
		root.add_child(blob)

	return root


static func _add_brick(parent: Node3D, pos: Vector3, rot_y: float,
					    color: Color, scale: Vector3 = Vector3.ONE) -> void:
	var inst := BRICK_SCENE.instantiate()
	inst.position        = pos
	inst.rotation.y      = rot_y
	inst.scale           = scale
	parent.add_child(inst)
	_apply_color(inst, color, 0.38)   # glossier blocks for the toy-box sheen


static func _apply_color(node: Node, color: Color, roughness: float = 0.55) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _material(color, roughness)
	for child in node.get_children():
		_apply_color(child, color, roughness)

# Beveled molded-plastic block material (toy_block.gdshader) for the wall bricks.
static func _material(color: Color, roughness: float) -> ShaderMaterial:
	var key := "block|%s|%.3f" % [color.to_html(), roughness]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := ShaderMaterial.new()
	m.shader = _BLOCK_SHADER
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("roughness", roughness)
	m.set_shader_parameter("star_tex", _STAR_TEX)
	m.set_shader_parameter("star_strength", 0.10)
	m.set_shader_parameter("rim_strength", 0.22)
	m.set_shader_parameter("rim_power", 4.5)
	_material_cache[key] = m
	return m

# Slate floor material (slate_floor.gdshader). is_a flips between the two checker
# shades baked into the shader.
static func _apply_floor(node: Node, is_a: bool) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _floor_material(is_a)
	for child in node.get_children():
		_apply_floor(child, is_a)

static func _floor_material(is_a: bool) -> ShaderMaterial:
	var key := "floor|%s" % str(is_a)
	if _material_cache.has(key):
		return _material_cache[key]
	var m := ShaderMaterial.new()
	m.shader = _FLOOR_SHADER
	m.set_shader_parameter("tile_blend", 0.0 if is_a else 1.0)
	m.set_shader_parameter("rough_noise", _SLATE_NOISE)
	_material_cache[key] = m
	return m
