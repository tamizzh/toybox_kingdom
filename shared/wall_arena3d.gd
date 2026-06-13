class_name WallArena3D
extends RefCounted

# Builds a 3D play area: a visual floor plus four static box walls that keep
# avatars inside. Avatars use no gravity (top-down), so the floor is visual only.

static func build(half_x: float, half_z: float, wall_h: float = 2.0, t: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Arena3D"

	# --- floor (visual only) ----------------------------------------------
	var floor := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(half_x * 2.0, 0.4, half_z * 2.0)
	floor.mesh = pm
	floor.position = Vector3(0, -0.2, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.17, 0.18, 0.22)
	fmat.roughness = 1.0
	floor.material_override = fmat
	root.add_child(floor)

	# --- four walls (static collision, layer 2) ---------------------------
	var specs := [
		[Vector3(0, wall_h * 0.5, -half_z - t * 0.5), Vector3(half_x * 2.0 + t * 2.0, wall_h, t)],
		[Vector3(0, wall_h * 0.5,  half_z + t * 0.5), Vector3(half_x * 2.0 + t * 2.0, wall_h, t)],
		[Vector3(-half_x - t * 0.5, wall_h * 0.5, 0), Vector3(t, wall_h, half_z * 2.0)],
		[Vector3( half_x + t * 0.5, wall_h * 0.5, 0), Vector3(t, wall_h, half_z * 2.0)],
	]
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.11, 0.11, 0.14)
	for spec in specs:
		var pos: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		var wall := StaticBody3D.new()
		wall.position = pos
		wall.collision_layer = 2
		wall.collision_mask = 0
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		c.shape = b
		wall.add_child(c)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = wmat
		wall.add_child(mi)
		root.add_child(wall)

	return root
