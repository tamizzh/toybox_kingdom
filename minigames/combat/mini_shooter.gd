extends MiniGameBase

# Free-for-all shooter. Aim + move with the stick, tap to fire. Two hits = out.
# Last alive wins.

const BULLET := preload("res://shared/bullet.tscn")

var _facing := {}
var _cool := {}
var _hp := {}

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	draw_background()
	add_child(WallArena.build(arena_rect))
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		_facing[p.id] = Vector2.RIGHT
		_cool[p.id] = 0.0
		_hp[p.id] = 2
		avatars[p.id].speed = 280.0
	make_label("Aim + fire! Two hits and you're out.", Vector2(410, 116), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = mv.normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action_just(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 0.32
			_shoot(p)

func _shoot(p: PlayerData) -> void:
	var b := BULLET.instantiate()
	add_child(b)
	b.position = avatars[p.id].position + _facing[p.id] * 38.0
	b.setup(p.id, _facing[p.id], p.color, 720.0)
	b.hit_player.connect(_on_hit)

func _on_hit(target: int, _owner: int) -> void:
	if not _hp.has(target):
		return
	_hp[target] -= 1
	avatars[target].pop()
	if _hp[target] <= 0:
		eliminate(target)

func _compute_results() -> Dictionary:
	return survivor_results(3)
