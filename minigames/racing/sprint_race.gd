extends MiniGameBase3D

# MASH your button to run (+X). Each tap gives a burst of speed that quickly
# decays, so the fastest tapper wins. First across the line takes it.  (3D)

const TAP_IMPULSE := 3.0    # speed gained per tap
const MAX_SPEED := 11.0     # cap so mashing has a ceiling
const FRICTION := 8.0       # how fast speed bleeds off — forces you to keep tapping

var _finish_x: float
var _start_x: float
var _order: Array = []
var _spd := {}              # id -> current run speed

func _setup_round() -> void:
	win_condition = WinType.FAST_TIME
	action_label = "RUN"
	# No interior crates — they would block the running lanes.
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))
	_start_x = -ARENA_HX + 1.5
	_finish_x = ARENA_HX - 1.0

	# ── Finish line: bold green wall + checkerboard strip ──────────────────
	# Tall bright green post strip
	spawn_marker(Vector3(_finish_x, 0.8, 0),
				 Vector3(0.5, 1.6, ARENA_HZ * 2.0), Palette.SAFE)
	# Bright checkered overlay (alternating white/green tile marks)
	for i in int(ARENA_HZ):
		var col := Palette.SAFE if i % 2 == 0 else Palette.ACCENT
		spawn_marker(Vector3(_finish_x, 0.06, -ARENA_HZ + i * 2.0 + 1.0),
					 Vector3(0.5, 0.12, 1.8), col)

	# ── Start line: white strip ─────────────────────────────────────────────
	spawn_marker(Vector3(_start_x, 0.06, 0), Vector3(0.3, 0.12, ARENA_HZ * 2.0),
				 Color(1, 1, 1, 0.55))

	# ── Per-player lane stripes on the floor ────────────────────────────────
	var lane_z := _lane_zs(players.size())
	for i in players.size():
		var pc := Palette.player_color(players[i].id)
		spawn_marker(Vector3((_finish_x + _start_x) * 0.5, 0.04, lane_z[i]),
					 Vector3(_finish_x - _start_x, 0.08, 0.25), Color(pc, 0.40))

	spawn_avatars(lane_spawns(_start_x))
	for p in players:
		_spd[p.id] = 0.0
		avatars[p.id].auto_input = false
		avatars[p.id].face(Vector2(1, 0))

func _lane_zs(n: int) -> Array:
	var step := ARENA_HZ * 1.4 / maxf(n, 1)
	var out := []
	for i in n:
		out.append(-ARENA_HZ * 0.7 + step * (i + 0.5))
	return out

func _game_process(delta: float) -> void:
	for p in players:
		if p.finished:
			continue
		var av = avatars[p.id]
		if InputManager.get_action_just(p.id):
			_spd[p.id] = minf(MAX_SPEED, _spd[p.id] + TAP_IMPULSE)
			av.pop()
		_spd[p.id] = maxf(0.0, _spd[p.id] - FRICTION * delta)
		if _spd[p.id] > 0.01:
			av.global_position.x += _spd[p.id] * delta
			av.face(Vector2(1, 0))
		if av.global_position.x >= _finish_x:
			p.finished = true
			_order.append(p.id)
	if _order.size() >= players.size():
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	var ranking := _order.duplicate()
	var rest := []
	for p in players:
		if not p.finished:
			rest.append(p)
	rest.sort_custom(func(a, b): return avatars[a.id].global_position.x > avatars[b.id].global_position.x)
	for p in rest:
		ranking.append(p.id)
	return award_by_rank(ranking)
