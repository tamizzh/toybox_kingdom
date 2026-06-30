extends RefCounted

# ── Strategic brain for one AI kingdom ───────────────────────────────────────
# Two sortie kinds:
#   EXPAND  — leave home, carve a rectangle of neutral/enemy land, return home.
#             Heading rotates each sortie so the kingdom grows like overlapping
#             petals.
#   CONQUER — encircle a nearby RIVAL's castle and return home to close the loop.
#             The enclosure capture takes the land between us and them; the match's
#             level-gated _check_conquests then takes the castle itself. This is
#             what actually eliminates rivals (without it, AIs only ever conquered
#             each other by accident and matches drifted to the timeout tiebreaker).
# While exposed (mid-trail) it bolts home if a rival gets close — but when it has
# COMMITTED to a conquest it tolerates far more danger so attacks actually land.
# No per-frame grid scans: a few waypoints + steering, so 8-20 of these are cheap.

var rng := RandomNumberGenerator.new()
var difficulty := 1
var heading := 0.0

var _wps: Array[Vector3] = []
var _wi := 0
var _attacking := false   # true while running a CONQUER sortie (commit, don't flinch)

# difficulty knobs (set in setup)
var _depth_lo := 8.0
var _depth_hi := 14.0
var _width := 6.0
var _danger := 5.0      # flee rivals within this world distance while exposed
var _aggr := 0.30       # chance a planned sortie is a CONQUER instead of EXPAND
var _established_min := 120  # territory required before attempting a conquest
var _castle_guard := 0.0     # >0: retreat when any rival enters this radius of our home
var speed_mult := 1.0        # applied to AI_SPEED in kingdom_match; >1 = faster bot

# Stuck detection: if position barely changes over 60 decide() calls (~4 s), force replan.
var _stuck_calls := 0
var _stuck_pos := Vector3.ZERO

# diff 0/1/2 sets the personality base; level (campaign stage 0-9 or endless island 0-19)
# applies a continuous multiplier so bots genuinely escalate each level — not just at tier
# boundaries. At level 9 even a "timid" bot performs like a mid-level "normal" bot would,
# and a "bold" bot becomes very aggressive (high aggr, small danger radius, deep bites).
func setup(diff: int, seed_val: int, level: int = 0) -> void:
	difficulty = diff
	rng.seed = seed_val
	heading = rng.randf() * TAU
	match diff:
		0:  # timid — was cautious; now plays like old "normal"
			_depth_lo = 9.0;  _depth_hi = 15.0; _width = 6.0; _danger = 5.0; _aggr = 0.32
		2:  # bold — very greedy, almost fearless, presses hard
			_depth_lo = 16.0; _depth_hi = 28.0; _width = 11.0; _danger = 1.8; _aggr = 0.82
		_:  # normal — plays like old "bold"
			_depth_lo = 13.0; _depth_hi = 22.0; _width = 9.0;  _danger = 3.0; _aggr = 0.58
	# Continuous level scaling: s goes 0→1 over levels 0→9. Endless levels 0-19 are clamped.
	var s: float = clampf(float(level) / 9.0, 0.0, 1.0)
	_aggr            = minf(_aggr + s * 0.25, 0.92)
	_danger          = maxf(_danger - s * 2.5, 1.0)
	_depth_lo       += s * 5.0
	_depth_hi       += s * 8.0
	_width           = minf(_width + s * 3.0, 13.0)
	_established_min = int(120.0 - s * 80.0)  # floor = 40 territory
	_castle_guard    = s * 10.0                # high-level bots aggressively guard home
	speed_mult       = 1.0 + s * 0.30         # up to 30% faster at max level

func reset() -> void:
	_wps.clear()
	_wi = 0
	_attacking = false
	_stuck_calls = 0

# Desired move direction in XZ (as Vector2); ZERO = idle.
func decide(agent, m) -> Vector2:
	var pos: Vector3 = agent.avatar.global_position

	# Stuck detector: every 60 calls (~4 s) check if we've moved at least 2 units.
	# If not, the bot is trapped in a degenerate loop — force a fresh plan.
	_stuck_calls += 1
	if _stuck_calls >= 60:
		if pos.distance_to(_stuck_pos) < 2.0:
			_wps.clear()
			_wi = 0
			_attacking = false
			heading += PI * 0.75  # jump to a very different direction
		_stuck_calls = 0
		_stuck_pos = pos

	# Exposed + threatened -> run home to bank what we have. When COMMITTED to a
	# conquest we tolerate much closer rivals (the target ruler is right there) so
	# the attack can actually close instead of aborting the moment they're nearby.
	var flee_at: float = _danger * (0.35 if _attacking else 1.0)
	var trail_len: int = m.grid.trail_length(agent.kid)
	var home_w: Vector3 = m._c2w(agent.home.x, agent.home.y, 0.0)
	if trail_len > 0 and m.nearest_enemy_dist_sq(agent) < flee_at * flee_at:
		return _steer(pos, home_w)
	# Castle defense: at higher levels, if ANY rival enters our home zone while we're
	# exposed, abort the sortie and rush back to protect the castle.
	if _castle_guard > 0.0 and trail_len > 0 and not _attacking:
		for o in m._rulers:
			if o == agent or o.eliminated or not o.alive:
				continue
			var op: Vector3 = o.avatar.global_position
			if Vector2(op.x - home_w.x, op.z - home_w.z).length_squared() < _castle_guard * _castle_guard:
				_wps.clear()
				_wi = 0
				return _steer(pos, home_w)

	# Powerup opportunism: divert toward a nearby pickup when the trail is short
	# (safe to detour) and we're not mid-conquest. Difficulty scales detour radius.
	if not _attacking and trail_len < 6 and m._powerup_cells.size() > 0:
		var best_pos := Vector3.ZERO
		var best_d := _depth_hi * 0.9   # only grab what's roughly "on the way"
		for pc in m._powerup_cells.keys():
			var pw: Vector3 = m._c2w(pc.x, pc.y, 0.0)
			var d := Vector2(pw.x - pos.x, pw.z - pos.z).length()
			if d < best_d:
				best_d = d
				best_pos = pw
		if best_pos != Vector3.ZERO:
			return _steer(pos, best_pos)

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

# Choose the next sortie: CONQUER a rival castle if we're established and the dice
# say so, otherwise EXPAND off our own edge.
func _plan(agent, m) -> void:
	_attacking = false
	# Only attack once we have a real base to anchor the loop and respawn from.
	# _established_min shrinks with level so high-level bots press the attack sooner.
	var established: bool = m.grid.territory_count(agent.kid) > _established_min
	if established and rng.randf() < _aggr:
		var target = _pick_target(agent, m)
		if target != null:
			_plan_conquest(agent, m, target)
			return
	_plan_expand(agent, m)

# Lay out the next rectangular EXPAND sortie off the home blob's edge.
# Retries up to 4 times with rotated headings if world_clamp collapses all
# waypoints near home (narrow island peninsula — the real stuck cause).
func _plan_expand(agent, m, _retry: int = 0) -> void:
	var H: Vector3 = m._c2w(agent.home.x, agent.home.y, 0.0)

	# Rotate heading, then bias it toward the land interior so the AI doesn't
	# immediately march into the ocean. If m.land_inward_dir returns a non-zero vector
	# (we're near the coast), blend the random heading with the inward direction.
	heading += rng.randf_range(0.5, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
	var inward: Vector2 = m.land_inward_dir(H)
	if inward.length() > 0.01:
		var inward_angle := atan2(inward.y, inward.x)
		# Blend: pull heading 60 % toward the inward direction, keep 40 % random variety.
		var diff := fmod(inward_angle - heading + 3.0 * PI, TAU) - PI
		heading += diff * 0.60

	var grow: float = sqrt(float(m.grid.territory_count(agent.kid))) * 0.25
	var depth: float = rng.randf_range(_depth_lo, _depth_hi) + grow
	var d := Vector2(cos(heading), sin(heading))
	var p := Vector2(-d.y, d.x)
	var dW := Vector3(d.x, 0.0, d.y)
	var pW := Vector3(p.x, 0.0, p.y)
	# world_clamp now iterates the SDF gradient until each waypoint lands on land.
	var c1: Vector3 = m.world_clamp(H + dW * depth)
	var c2: Vector3 = m.world_clamp(c1 + pW * _width)
	var c3: Vector3 = m.world_clamp(H + pW * _width)

	# Guard: if the farthest waypoint is still very close to home, the island is
	# too narrow in this direction. Rotate 90° and retry (up to 4 times).
	var max_d := maxf(Vector2(c1.x - H.x, c1.z - H.z).length(),
		maxf(Vector2(c2.x - H.x, c2.z - H.z).length(),
			 Vector2(c3.x - H.x, c3.z - H.z).length()))
	if max_d < 2.5 and _retry < 4:
		heading += PI * 0.5
		_plan_expand(agent, m, _retry + 1)
		return

	_wps = [c1, c2, c3, H]
	_wi = 0

# Trace a rectangle CENTERED on the home->target axis that engulfs the target
# castle, then re-enter home to close the loop. Everything inside (the enemy land
# between us and their keep) is captured; the castle falls if our tier is high
# enough (_check_conquests handles the gate).
func _plan_conquest(agent, m, target) -> void:
	_attacking = true
	var H: Vector3 = m._c2w(agent.home.x, agent.home.y, 0.0)
	var T: Vector3 = target["pos"]
	var axis := Vector2(T.x - H.x, T.z - H.z)
	var dist: float = axis.length()
	if dist < 0.5:
		_plan_expand(agent, m)
		return
	var d := axis / dist
	var p := Vector2(-d.y, d.x)
	var dW := Vector3(d.x, 0.0, d.y)
	var pW := Vector3(p.x, 0.0, p.y)
	var span: float = _width                      # half-width of the band (each side of the axis)
	var reach: float = dist + 5.0                 # go a little PAST the castle so it sits inside
	# H -> step to one side -> out past the keep -> across to the far side -> back -> home.
	var c1: Vector3 = m.world_clamp(H + pW * span)
	var c2: Vector3 = m.world_clamp(c1 + dW * reach)
	var c3: Vector3 = m.world_clamp(c2 - pW * (span * 2.0))
	var c4: Vector3 = m.world_clamp(c3 - dW * reach)
	_wps = [c1, c2, c3, c4, H]
	_wi = 0

# Pick the best rival castle to encircle: nearest one we can actually take (tier
# <= ours). If none are takeable, fall back to the nearest castle anyway — even a
# held castle's surrounding land transfers to us, which still squeezes the rival.
func _pick_target(agent, m):
	var H: Vector3 = m._c2w(agent.home.x, agent.home.y, 0.0)
	var my_tier: int = (agent.castle.tier if agent.castle != null else 1) + agent.defense
	var best = null
	var best_score := INF
	var best_any = null
	var best_any_d := INF
	for o in m._rulers:
		if o == agent or o.eliminated:
			continue
		for c in o.castles:
			var cell: Vector2i = c["cell"]
			var wpos: Vector3 = m._c2w(cell.x, cell.y, 0.0)
			var d: float = Vector2(wpos.x - H.x, wpos.z - H.z).length()
			var c_tier: int = (c["node"].tier if c["node"] != null else 1) + o.defense
			# track nearest overall as the fallback
			if d < best_any_d:
				best_any_d = d
				best_any = {"pos": wpos, "cell": cell, "tier": c_tier}
			# prefer takeable castles; score = distance, lighter for weaker keeps.
			# Also discount rivals currently mid-trail (exposed = easier to kill).
			if my_tier >= c_tier:
				var trail_bonus: float = float(m.grid.trail_length(o.kid)) * 0.8
				var score := d + float(c_tier) * 2.0 - trail_bonus
				if score < best_score:
					best_score = score
					best = {"pos": wpos, "cell": cell, "tier": c_tier}
	return best if best != null else best_any
