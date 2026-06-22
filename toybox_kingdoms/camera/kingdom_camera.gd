extends Camera3D

# ── DAY 4-7 SPIKE: follow camera ─────────────────────────────────────────────
# Replaces MiniGameBase3D's fixed whole-arena framing. Smoothly trails the player
# at a 3/4 hero angle. `zoom` is a hook for "pull back as the kingdom grows"
# (Day 16-19); for the grey-box it stays at 1.0 so we just follow.

var target: Node3D
var offset := Vector3(0.0, 13.2, 15.6)
var follow_speed := 6.0
var zoom := 1.0          # >1 pulls the camera back
var _shake := 0.0        # current shake intensity (decays)

func _ready() -> void:
	fov = 46.0
	make_current()

# Punchy positional shake for impact moments (claim / pop / castle capture).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var focus := target.global_position
	var want := focus + offset * zoom
	var t := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(want, t)
	if _shake > 0.001:
		global_position += Vector3(randf_range(-_shake, _shake), randf_range(-_shake, _shake),
			randf_range(-_shake, _shake))
		_shake = move_toward(_shake, 0.0, delta * 1.6)
	look_at(focus, Vector3.UP)
