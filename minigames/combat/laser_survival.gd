extends MiniGameBase3D

# Rotating laser beams sweep the arena from the centre. Dodge to survive.
# Last alive wins.  (3D)

const SPIN := 0.85
const BEAM_HALF := 0.8

var _angle := 0.0
var _pivot: Node3D

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(build_arena())
	spawn_avatars(corner_spawns(2.5))
	for p in players:
		avatars[p.id].speed = 7.0

	# a rotating "plus" of beams (two crossed bars = 4 arms)
	_pivot = Node3D.new()
	add_child(_pivot)
	var length := ARENA_HX * 2.4
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1, 0.25, 0.3)
	bmat.emission_enabled = true
	bmat.emission = Color(1, 0.25, 0.3)
	for bar_rot in [0.0, PI * 0.5]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(length, 0.3, BEAM_HALF * 2.0)
		bar.mesh = bm
		bar.material_override = bmat
		bar.rotation.y = bar_rot
		bar.position = Vector3(0, 0.4, 0)
		_pivot.add_child(bar)
	make_label("Dodge the lasers — survive!", Vector2(440, 96), 24)

func _game_process(delta: float) -> void:
	_angle += SPIN * delta
	_pivot.rotation.y = -_angle   # match the detection convention below
	for p in players:
		if not p.alive:
			continue
		var rel := avatars[p.id].global_position
		rel.y = 0.0
		for a in [_angle, _angle + PI, _angle + PI * 0.5, _angle + PI * 1.5]:
			var dir := Vector3(cos(a), 0, sin(a))
			var along := rel.dot(dir)
			var perp := absf(rel.dot(Vector3(-dir.z, 0, dir.x)))
			if along > 0.0 and perp < BEAM_HALF:
				eliminate(p.id)
				break

func _compute_results() -> Dictionary:
	return survivor_results(3)
