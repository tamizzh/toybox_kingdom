## Prints the AABB of the mascot GLB so we can compute the correct y-offset.
##   godot --headless --path . res://toybox_kingdoms/tools/aabb_check.tscn
extends Node3D

func _ready() -> void:
	var scene : PackedScene = load("res://assets/mascot.glb")
	var inst : Node3D = scene.instantiate()
	add_child(inst)

	# Collect overall AABB from all MeshInstance3D children (recursive)
	var combined := AABB()
	var first := true
	_collect_aabb(inst, combined, first)

	print("MASCOT AABB position: ", combined.position)
	print("MASCOT AABB size:     ", combined.size)
	print("MASCOT AABB end:      ", combined.end)
	print("min_y (at scale 1.0): ", combined.position.y)
	print("Suggested y-lift at scale 1.6: ", -combined.position.y * 1.6)
	print("Center X offset: ", combined.position.x + combined.size.x * 0.5)
	print("Center Z offset: ", combined.position.z + combined.size.z * 0.5)
	get_tree().quit()

func _collect_aabb(node: Node, combined: AABB, first: bool) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh:
			var local_aabb := mesh_inst.get_aabb()
			# transform to this scene root's local space
			var world_aabb := mesh_inst.global_transform * local_aabb
			if first:
				combined = world_aabb
				first = false
			else:
				combined = combined.merge(world_aabb)
	for child in node.get_children():
		_collect_aabb(child, combined, first)
