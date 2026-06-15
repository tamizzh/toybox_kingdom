extends MiniGameBase3D

# A marker sweeps the 3D arena floor. Tap to lock it as close to the target as you can.
# Closest each round scores.

const SWEEP_HALF := 8.0    # half-width of the sweep range in world-X
const SWEEP_SPEED := 2.2   # radians per second (sin wave)

var _pos := 0.0            # 0..1 sweep position
var _target := 0.5
var _tapped := {}
var _lockpos := {}
var _cooling := false

# 3D sweep strip and target marker
var _sweep_strip: MeshInstance3D
var _sweep_mat: StandardMaterial3D
var _target_strip: MeshInstance3D
var _lock_nodes: Array = []
var _glow_t: float = 0.0

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "STOP"
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))

	# ── Target marker: a bright green strip at a fixed X position ─────────────
	var tgt_mat := StandardMaterial3D.new()
	tgt_mat.albedo_color = Palette.SAFE
	tgt_mat.emission_enabled = true
	tgt_mat.emission = Palette.SAFE
	tgt_mat.emission_energy_multiplier = 3.0
	_target_strip = MeshInstance3D.new()
	var tbm := BoxMesh.new()
	tbm.size = Vector3(0.55, 0.12, ARENA_HZ * 2.0)
	_target_strip.mesh = tbm
	_target_strip.material_override = tgt_mat
	_target_strip.position = Vector3(0, 0.06, 0)   # will be set in _new_round
	add_child(_target_strip)

	# ── Sweep strip: a bright red/yellow strip that moves across the floor ─────
	_sweep_mat = StandardMaterial3D.new()
	_sweep_mat.albedo_color = Palette.DANGER
	_sweep_mat.emission_enabled = true
	_sweep_mat.emission = Palette.DANGER
	_sweep_mat.emission_energy_multiplier = 3.5
	_sweep_strip = MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(0.45, 0.14, ARENA_HZ * 2.0)
	_sweep_strip.mesh = sbm
	_sweep_strip.material_override = _sweep_mat
	_sweep_strip.position = Vector3(0, 0.07, 0)
	add_child(_sweep_strip)

	spawn_avatars(corner_spawns(3.0))
	for p in players:
		avatars[p.id].speed = 4.0

	_new_round()

func _new_round() -> void:
	_tapped = {}
	_lockpos = {}
	for n in _lock_nodes:
		n.queue_free()
	_lock_nodes = []
	_target = randf_range(0.20, 0.80)
	_target_strip.position.x = (_target - 0.5) * SWEEP_HALF * 2.0

func _game_process(delta: float) -> void:
	_glow_t += delta
	_pos = (sin(elapsed * SWEEP_SPEED) + 1.0) * 0.5
	var world_x := (_pos - 0.5) * SWEEP_HALF * 2.0
	_sweep_strip.position.x = world_x

	# Pulse sweep emission
	_sweep_mat.emission_energy_multiplier = 2.5 + 1.2 * sin(_glow_t * 6.0)

	# Change color to gold when close to target
	var dist := absf(_pos - _target)
	if dist < 0.08:
		_sweep_mat.albedo_color = Palette.WARN
		_sweep_mat.emission     = Palette.WARN
	else:
		_sweep_mat.albedo_color = Palette.DANGER
		_sweep_mat.emission     = Palette.DANGER

	if _cooling:
		return

	for p in players:
		if not _tapped.get(p.id, false) and InputManager.get_action_just(p.id):
			_tapped[p.id] = true
			_lockpos[p.id] = _pos
			AudioManager.play("tap")
			avatars[p.id].pop()
			# Spawn a player-colored lock marker at the locked position
			var lm := MeshInstance3D.new()
			var lbm := BoxMesh.new()
			lbm.size = Vector3(0.32, 0.16, ARENA_HZ * 2.0)
			lm.mesh = lbm
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = p.color
			lmat.emission_enabled = true
			lmat.emission = p.color
			lmat.emission_energy_multiplier = 2.0
			lm.material_override = lmat
			lm.position = Vector3(world_x, 0.08, 0)
			add_child(lm)
			_lock_nodes.append(lm)

	if _tapped.size() >= players.size():
		_award()

func _award() -> void:
	_cooling = true
	var best := -1
	var bd := 999.0
	for p in players:
		var d: float = absf(_lockpos.get(p.id, 1.0) - _target)
		if d < bd:
			bd = d
			best = p.id
	if best >= 0:
		_player(best).round_value += 1.0
		AudioManager.play("collect")
	_cool_then_new()

func _cool_then_new() -> void:
	await get_tree().create_timer(1.0).timeout
	_cooling = false
	if not _finished:
		_new_round()

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
