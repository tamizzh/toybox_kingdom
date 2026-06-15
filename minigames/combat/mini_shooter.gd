extends MiniGameBase3D

# Free-for-all shooter in 3D. Aim + move with the stick, tap to fire. Two hits = out.
# Last alive wins.

const BULLET := preload("res://shared/bullet3d.gd")

var _facing := {}
var _cool := {}
var _hp := {}

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	add_child(build_arena())
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		_facing[p.id] = Vector3(1, 0, 0)
		_cool[p.id] = 0.0
		_hp[p.id] = 2
		avatars[p.id].speed = 6.6
	make_label("Aim + fire! Two hits and you're out.", Vector2(410, 96), 24)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = Vector3(mv.x, 0, mv.y).normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action_just(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = 0.32
			_shoot(p)

func _shoot(p: PlayerData) -> void:
	var av = avatars[p.id]
	var b := BULLET.new()
	add_child(b)
	b.global_position = av.global_position + _facing[p.id] * 1.6 + Vector3(0, 0.9, 0)
	b.setup(p.id, _facing[p.id], p.color, 22.0)
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
