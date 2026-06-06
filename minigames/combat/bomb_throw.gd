extends MiniGameBase

# Throw timed bombs in your facing direction; explosions eliminate anyone close.
# Last alive wins.

const FUSE := 1.4
const RADIUS := 95.0

var _facing := {}
var _cool := {}
var _bombs: Array = []

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		_facing[p.id] = Vector2.RIGHT
		_cool[p.id] = 0.0
		avatars[p.id].speed = 290.0
	make_label("Tap to throw bombs — don't get caught!", Vector2(400, 116), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = mv.normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action_just(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 1.0
			_throw(p)
	var keep := []
	for b in _bombs:
		b["fuse"] -= delta
		b["vel"] *= 0.95
		b["pos"] += b["vel"] * delta
		b["node"].position = b["pos"] - Vector2(13, 13)
		if b["fuse"] <= 0.0:
			_explode(b)
			b["node"].queue_free()
		else:
			keep.append(b)
	_bombs = keep

func _throw(p: PlayerData) -> void:
	var n := make_rect(Rect2(0, 0, 26, 26), Palette.WARN, -3)
	_bombs.append({
		"pos": avatars[p.id].position,
		"vel": _facing[p.id] * 270.0,
		"fuse": FUSE,
		"node": n,
	})

func _explode(b: Dictionary) -> void:
	var flash := make_rect(Rect2(0, 0, RADIUS * 2, RADIUS * 2), Color(1, 0.6, 0.2, 0.5), -1)
	flash.position = b["pos"] - Vector2(RADIUS, RADIUS)
	get_tree().create_timer(0.18).timeout.connect(flash.queue_free)
	for p in players:
		if p.alive and avatars[p.id].position.distance_to(b["pos"]) < RADIUS:
			eliminate(p.id)

func _compute_results() -> Dictionary:
	return survivor_results(3)
