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
		# Procedural checkerboard tiled floor (default): beveled slabs from
		# floor_tile.glb — gives 3D depth matching the reference art.
		var ts    := 4.0    # tile pitch (= brick width for visual alignment)
		var gap   := 0.12   # grout gap between tiles
		var tile_s := ts - gap   # rendered tile size

		var nz   := ceili(half_z / ts)   # enough rows to cover ±half_z
		var nx_t := ceili(half_x / ts)   # enough cols to cover ±half_x
		# Checkerboard: two alternating bright slate-blue shades
		var floor_a := Color("5b7da8")   # brighter slate-blue
		var floor_b := Color("46658c")   # deeper slate-blue

		for iz in range(-nz, nz):
			for ix in range(-nx_t, nx_t):
				var ti := TILE_SCENE.instantiate()
				ti.position = Vector3(
					(float(ix) + 0.5) * ts,
					-0.175,
					(float(iz) + 0.5) * ts)
				ti.scale = Vector3(tile_s / 4.0, 1.0, tile_s / 4.0)
				var checker_color := floor_a if (ix + iz) % 2 == 0 else floor_b
				_apply_color(ti, checker_color, 0.5)
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
		var wall_len := sz.z if rot_y > 0.01 else sz.x
		var n_bricks := int(round(wall_len / BRICK_W))
		if n_bricks < 1:
			n_bricks = 1
		var actual_bw := wall_len / float(n_bricks)

		for bi in n_bricks:
			var bc: Color = _BRICK_COLORS[brick_idx % _BRICK_COLORS.size()]
			brick_idx += 1

			# Offset from wall centre along the wall-length axis
			var offset := -wall_len * 0.5 + (float(bi) + 0.5) * actual_bw

			# Brick centre relative to StaticBody3D
			var bpos: Vector3
			if rot_y > 0.01:
				bpos = Vector3(0, 0, offset)
			else:
				bpos = Vector3(offset, 0, 0)

			# Scale bricks to the (smaller) wall height/thickness — daintier border,
			# play bounds unchanged. Width (X) stays so the row still tiles.
			_add_brick(body, bpos, rot_y, bc, Vector3(1.0, wall_h / BRICK_H, t / BRICK_D))

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

static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s|%.3f" % [color.to_html(), roughness]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_material_cache[key] = m
	return m
