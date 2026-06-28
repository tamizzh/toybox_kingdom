extends Camera3D

# ── Follow camera with juice ─────────────────────────────────────────────────
# Smoothly trails the player at a 3/4 hero angle. `zoom` pulls back as the kingdom
# grows. Adds: a tiny idle sway (the diorama feels alive even when still), a quick
# zoom-PUNCH on capture (snaps in then eases back for impact), and a cinematic
# victory ORBIT that detaches from the player and circles their capital.

var target: Node3D
var offset := Vector3(0.0, 12.6, 15.2)
var follow_speed := 6.0
var zoom := 1.0          # >1 pulls the camera back
var _shake := 0.0        # current shake intensity (decays)
var _idle_t := 0.0
var _zoom_punch := 0.0   # 0..~0.06, snaps the camera in then decays
var _orbit := false
var _orbit_focus := Vector3.ZERO
var _orbit_ang := 0.0
var _intro := false      # true while a clear/arrive camera move owns the zoom (HUD must not fight it)

var _overview := false
var _overview_center := Vector3.ZERO
# Height 57 / tilt 7 at FOV 55° shows the whole island with a modest ocean border —
# tight enough that kingdoms aren't tiny, wide enough that none clip off-screen.
const OVERVIEW_POS := Vector3(0.0, 57.0, 7.0)

# While an island-transition camera move is running, the match should NOT drive `zoom`
# from territory size — let the move own it.
func intro_active() -> bool:
	return _intro

# Rise up and back away from the board as an island is cleared (zoom pulls the hero
# rig up + back along its angle). Leaves _intro set — the scene reloads right after.
func pull_out(secs: float = 1.1) -> void:
	_orbit = false
	_intro = true
	var tw := create_tween()
	tw.tween_property(self, "zoom", 6.0, secs).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

# Descend from high above down into normal framing as a new island opens.
func descend(secs: float = 1.1) -> void:
	_orbit = false
	_intro = true
	zoom = 6.0
	var tw := create_tween()
	tw.tween_property(self, "zoom", 1.0, secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: _intro = false)

func _ready() -> void:
	fov = 46.0
	make_current()

# Punchy positional shake for impact moments (claim / pop / castle capture).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

# Quick dolly-in on capture — eases back out (see _process). amount ~0.04 = 4%.
func punch_zoom(amount: float) -> void:
	_zoom_punch = maxf(_zoom_punch, amount)

# Hover above the board center so the player can see the whole map.
func start_overview(center: Vector3) -> void:
	_orbit = false
	_overview = true
	_overview_center = center

func end_overview() -> void:
	_overview = false

# Detach from the player and slowly circle a point (their capital) for the win
# cinematic. Pushes the FOV in for a tighter, more dramatic frame.
func start_victory_orbit(focus: Vector3) -> void:
	_orbit = true
	_orbit_focus = focus
	_orbit_ang = 0.0
	var tw := create_tween()
	tw.tween_property(self, "fov", 38.0, 1.4).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _overview:
		var want := _overview_center + OVERVIEW_POS
		var t := clampf(follow_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(want, t)
		look_at(_overview_center, Vector3.UP)
		return
	if _orbit:
		_orbit_ang += delta * 0.32
		var r := 15.0
		var h := 9.5
		global_position = _orbit_focus + Vector3(cos(_orbit_ang) * r, h, sin(_orbit_ang) * r)
		look_at(_orbit_focus + Vector3(0, 1.6, 0), Vector3.UP)
		return
	if target == null or not is_instance_valid(target):
		return
	_idle_t += delta
	var focus := target.global_position
	var z := zoom * (1.0 - _zoom_punch)
	var want := focus + offset * z
	# breathing idle sway so the world never feels frozen
	want += Vector3(sin(_idle_t * 0.5) * 0.16, 0.0, cos(_idle_t * 0.37) * 0.12)
	var t := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(want, t)
	_zoom_punch = move_toward(_zoom_punch, 0.0, delta * 0.16)
	if _shake > 0.001:
		global_position += Vector3(randf_range(-_shake, _shake), randf_range(-_shake, _shake),
			randf_range(-_shake, _shake))
		_shake = move_toward(_shake, 0.0, delta * 1.6)
	look_at(focus, Vector3.UP)
