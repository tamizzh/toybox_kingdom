extends MiniGameBase3D

# Throw timed bombs in your facing direction; explosions eliminate anyone close.
# Last alive wins.  (3D)

const FUSE := 1.4
const RADIUS := 3.2

var _facing := {}
var _cool := {}
var _bombs: Array = []

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(WallArena3D.build(ARENA_HX, ARENA_HZ))
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		_facing[p.id] = Vector3(1, 0, 0)
		_cool[p.id] = 0.0
		avatars[p.id].speed = 6.8
	make_label("Tap to throw bombs — don't get caught!", Vector2(400, 96), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = Vector3(mv.x, 0, mv.y).normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action_just(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 1.0
			_throw(p)
	var keep := []
	for b in _bombs:
		b["fuse"] -= delta
		b["vel"] *= 0.95
		b["pos"] += b["vel"] * delta
		b["node"].position = b["pos"]
		if b["fuse"] <= 0.0:
			_explode(b)
			b["node"].queue_free()
		else:
			keep.append(b)
	_bombs = keep

func _throw(p: PlayerData) -> void:
	var n := spawn_marker(Vector3.ZERO, Vector3(0.6, 0.6, 0.6), Palette.WARN, true)
	_bombs.append({
		"pos": avatars[p.id].global_position + Vector3(0, 0.5, 0),
		"vel": _facing[p.id] * 8.0,
		"fuse": FUSE,
		"node": n,
	})

func _explode(b: Dictionary) -> void:
	var flash := spawn_marker(b["pos"], Vector3(RADIUS * 2, 0.3, RADIUS * 2),
		Color(1, 0.6, 0.2, 0.5), true)
	get_tree().create_timer(0.18).timeout.connect(flash.queue_free)
	for p in players:
		if p.alive and avatars[p.id].global_position.distance_to(b["pos"]) < RADIUS:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
