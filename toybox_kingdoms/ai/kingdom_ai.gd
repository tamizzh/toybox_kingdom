extends RefCounted

# ── Strategic brain for one AI kingdom ───────────────────────────────────────
# Plans "sorties": leave home, carve a rectangle of neutral/enemy land, return to
# close the loop. The heading rotates each sortie so the kingdom grows outward
# like overlapping petals. While exposed (mid-trail) it bolts home if a rival gets
# close — the cheap version of "defend / avoid stronger". No per-frame grid scans:
# just a few waypoints and steering, so 8-20 of these are nearly free.

var rng := RandomNumberGenerator.new()
var difficulty := 1
var heading := 0.0

var _wps: Array[Vector3] = []
var _wi := 0

# difficulty knobs (set in setup)
var _depth_lo := 8.0
var _depth_hi := 14.0
var _width := 6.0
var _danger := 5.0      # flee rivals within this world distance while exposed

func setup(diff: int, seed_val: int) -> void:
	difficulty = diff
	rng.seed = seed_val
	heading = rng.randf() * TAU
	match diff:
		0:  # timid — small bites, spooks easily
			_depth_lo = 5.0; _depth_hi = 9.0;  _width = 5.0; _danger = 7.0
		2:  # bold — big greedy bites, hard to scare
			_depth_lo = 10.0; _depth_hi = 18.0; _width = 7.0; _danger = 3.5
		_:  # normal
			_depth_lo = 8.0; _depth_hi = 14.0; _width = 6.0; _danger = 5.0

func reset() -> void:
	_wps.clear()
	_wi = 0

# Desired move direction in XZ (as Vector2); ZERO = idle.
func decide(agent, m) -> Vector2:
	var pos: Vector3 = agent.avatar.global_position

	# Exposed + threatened -> run straight home to bank what we have.
	if m.grid.trail_length(agent.kid) > 0 and m.nearest_enemy_dist(agent) < _danger:
		return _steer(pos, m._c2w(agent.home.x, agent.home.y, 0.0))

	if _wi >= _wps.size():
		_plan(agent, m)
	var tgt: Vector3 = _wps[_wi]
	if Vector2(tgt.x - pos.x, tgt.z - pos.z).length() < 0.9:
		_wi += 1
		if _wi >= _wps.size():
			_plan(agent, m)
	return _steer(pos, _wps[_wi])

func _steer(pos: Vector3, tgt: Vector3) -> Vector2:
	var to := Vector2(tgt.x - pos.x, tgt.z - pos.z)
	if to.length() < 0.01:
		return Vector2.ZERO
	return to.normalized()

# Lay out the next rectangular sortie off the home blob's edge.
func _plan(agent, m) -> void:
	var H: Vector3 = m._c2w(agent.home.x, agent.home.y, 0.0)
	heading += rng.randf_range(0.5, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
	var grow: float = sqrt(float(m.grid.territory_count(agent.kid))) * 0.25  # bigger realm reaches further
	var depth: float = rng.randf_range(_depth_lo, _depth_hi) + grow
	var d := Vector2(cos(heading), sin(heading))
	var p := Vector2(-d.y, d.x)
	var dW := Vector3(d.x, 0.0, d.y)
	var pW := Vector3(p.x, 0.0, p.y)
	# Clamp the carve points inside the world so an edge-facing sortie can't pin the
	# avatar against the boundary (it just encloses a smaller bite and replans).
	var c1: Vector3 = m.world_clamp(H + dW * depth)
	var c2: Vector3 = m.world_clamp(c1 + pW * _width)
	var c3: Vector3 = m.world_clamp(H + pW * _width)
	_wps = [c1, c2, c3, H]   # out, across, back-parallel, re-enter home -> encloses a rectangle
	_wi = 0
