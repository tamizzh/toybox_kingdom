class_name WallArena
extends RefCounted

# Builds a bordered arena (floor visual + 4 static walls on physics layer 2)
# as a single Node2D the caller adds to its tree.

static func build(rect: Rect2, thickness: float = 60.0) -> Node2D:
	var root := Node2D.new()

	# With an illustrated arena background, skip the opaque floor + drawn border so
	# the art fills the screen; otherwise paint the flat dark floor as before.
	if not MiniGameBase.has_arena_art:
		var floor := ColorRect.new()
		floor.color = Palette.ARENA_FLOOR
		floor.position = rect.position
		floor.size = rect.size
		floor.z_index = -50
		floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(floor)

		var line := Line2D.new()
		line.width = 5.0
		line.default_color = Palette.WALL
		line.z_index = -40
		line.points = PackedVector2Array([
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y),
			rect.position,
		])
		root.add_child(line)

	var defs := [
		Rect2(rect.position.x, rect.position.y - thickness, rect.size.x, thickness),
		Rect2(rect.position.x, rect.position.y + rect.size.y, rect.size.x, thickness),
		Rect2(rect.position.x - thickness, rect.position.y - thickness, thickness, rect.size.y + 2.0 * thickness),
		Rect2(rect.position.x + rect.size.x, rect.position.y - thickness, thickness, rect.size.y + 2.0 * thickness),
	]
	for d in defs:
		root.add_child(_wall(d))
	return root

static func _wall(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	body.add_child(cs)
	return body
