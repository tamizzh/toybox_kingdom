## Quick mascot verification: spawn 3 Avatar3D mascots facing the camera,
## print the raw GLB AABB, then screenshot.
##   godot --path . res://toybox_kingdoms/tools/shot_mascot.tscn
extends Node3D

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 720)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.74, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.78, 0.9)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.4
	add_child(sun)

	# ── Measure raw GLB AABB before any game-code wrapping ──
	var raw := load("res://assets/mascot.glb") as PackedScene
	var raw_inst := raw.instantiate() as Node3D
	add_child(raw_inst)
	await get_tree().process_frame
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(raw_inst, meshes)
	# Print full node tree + list any AnimationPlayer
	print("--- GLB node tree ---")
	_print_tree(raw_inst, 0)
	print("--- end tree ---")

	if meshes.size() > 0:
		# Transform each mesh's local AABB into world space before merging
		var first_world := meshes[0].global_transform * meshes[0].get_aabb()
		var aabb := first_world
		for mi in meshes.slice(1):
			aabb = aabb.merge(mi.global_transform * mi.get_aabb())
		print("GLB AABB pos:    ", aabb.position)
		print("GLB AABB size:   ", aabb.size)
		print("GLB AABB end:    ", aabb.end)
		print("  center X: ", aabb.position.x + aabb.size.x * 0.5)
		print("  center Y: ", aabb.position.y + aabb.size.y * 0.5)
		print("  center Z: ", aabb.position.z + aabb.size.z * 0.5)
		print("  min_y (feet at scale 1.0): ", aabb.position.y)
		print("  y-lift for scale 1.0: ", -aabb.position.y)
		print("  x-offset to center: ", -(aabb.position.x + aabb.size.x * 0.5))
		print("  z-offset to center: ", -(aabb.position.z + aabb.size.z * 0.5))
	else:
		print("GLB AABB: no mesh instances found")
	raw_inst.queue_free()

	# ── Spawn three Avatar3D instances in a row ──
	for i in 3:
		var p := PlayerData.new(i)
		var av := Avatar3D.new()
		add_child(av)
		av.setup(p)
		av.auto_input = false
		av.global_position = Vector3(0, 0, (i - 1) * 1.8)
		av.face(Vector2.RIGHT)
		# Stop walk anim for the static preview so blobs stand in rest pose
		var ap := av._anim
		if ap:
			ap.stop(true)
			ap.seek(0.0, true)

	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.global_position = Vector3(6.5, 1.1, 0)
	cam.look_at(Vector3(0, 0.7, 0), Vector3.UP)
	cam.make_current()

	await get_tree().create_timer(1.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_mascot.png")
	img.save_png(out)
	print("MASCOT_SHOT_SAVED: ", out)
	get_tree().quit()

func _print_tree(node: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var extra := ""
	if node is AnimationPlayer:
		extra = " [animations: " + str((node as AnimationPlayer).get_animation_list()) + "]"
	print(indent, node.name, " (", node.get_class(), ")", extra)
	for child in node.get_children():
		_print_tree(child, depth + 1)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var r := _find_anim_player(child)
		if r:
			return r
	return null

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)
