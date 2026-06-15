class_name AIController
extends Node

# Drives CPU players by writing into InputManager (the same seam touch/keyboard use),
# so every mini-game gets AI opponents with no per-game changes. Behaviour is a
# smoothed wander + periodic action taps, biased toward the nearest opponent (or arena
# centre) by a difficulty-scaled amount. Not brilliant, but competitive — exactly the
# pattern proven by tools/play_bot.gd.

var game: Node                    # MiniGameBase3D being played
var ai_ids: Array = []            # player ids this controller drives
var difficulty: int = 1

# per-id wander / tap state
var _phase := {}
var _turn := {}
var _next_tap := {}
var _tap_state := {}

# difficulty-tuned knobs
var _seek := 0.45          # 0..1 bias toward the seek target
var _tap_lo := 0.22
var _tap_hi := 0.55
var _coherence := 0.8      # heading stickiness (lower = flailier)

func setup(p_game: Node, p_ids: Array, p_difficulty: int) -> void:
	game = p_game
	difficulty = p_difficulty
	for raw in p_ids:
		var id := int(raw)
		ai_ids.append(id)
		_phase[id] = randf() * TAU
		_turn[id] = randf_range(-1.0, 1.0)
		_next_tap[id] = randf_range(0.2, 0.6)
		_tap_state[id] = false
	match difficulty:
		0:  # easy — flaily, slow taps, barely seeks
			_seek = 0.15; _tap_lo = 0.45; _tap_hi = 1.0; _coherence = 0.5
		2:  # hard — deliberate, fast taps, strong seek
			_seek = 0.75; _tap_lo = 0.12; _tap_hi = 0.30; _coherence = 1.0
		_:  # normal
			_seek = 0.45; _tap_lo = 0.22; _tap_hi = 0.55; _coherence = 0.8

func _physics_process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	# Hold neutral during the countdown / after the round ends.
	if game.has_method("is_playing") and not game.is_playing():
		for id in ai_ids:
			InputManager.set_move(id, Vector2.ZERO)
			if _tap_state[id]:
				_tap_state[id] = false
				InputManager.set_action(id, false)
		return
	for id in ai_ids:
		_drive(id, delta)

func _drive(id: int, delta: float) -> void:
	# Wander: a heading that slowly meanders.
	_turn[id] = clampf(_turn[id] + randf_range(-1.0, 1.0) * delta * 2.0, -1.5, 1.5)
	_phase[id] += _turn[id] * delta * (2.0 * _coherence + 0.4)
	var dir := Vector2(cos(_phase[id]), sin(_phase[id]))

	var seek_dir := _seek_dir(id)
	if seek_dir != Vector2.ZERO:
		dir = dir.lerp(seek_dir, _seek)
		if dir.length() > 0.01:
			dir = dir.normalized()
	InputManager.set_move(id, dir)

	# Action taps (run/fire/throw/jump depending on the game).
	_next_tap[id] -= delta
	if _next_tap[id] <= 0.0:
		_tap_state[id] = not _tap_state[id]
		InputManager.set_action(id, _tap_state[id])
		_next_tap[id] = randf_range(_tap_lo, _tap_hi) if _tap_state[id] else randf_range(0.05, 0.12)

# Direction (in XZ→2D) toward the nearest living opponent, else toward arena centre.
func _seek_dir(id: int) -> Vector2:
	if game == null or not game.has_method("get_avatar"):
		return Vector2.ZERO
	var me = game.get_avatar(id)
	if me == null or not is_instance_valid(me):
		return Vector2.ZERO
	var my_pos: Vector3 = me.global_position

	var best := Vector2.ZERO
	var best_d := INF
	if "avatars" in game:
		for other_id in game.avatars:
			if other_id == id:
				continue
			var av = game.avatars[other_id]
			if av == null or not is_instance_valid(av):
				continue
			if "dead" in av and av.dead:
				continue
			var d: float = my_pos.distance_to(av.global_position)
			if d < best_d:
				best_d = d
				var to: Vector3 = av.global_position - my_pos
				best = Vector2(to.x, to.z)
	if best == Vector2.ZERO:
		best = Vector2(-my_pos.x, -my_pos.z)   # head back toward centre
	if best.length() < 0.01:
		return Vector2.ZERO
	return best.normalized()

func _exit_tree() -> void:
	# Release the inputs we were writing so a later human on this id isn't stuck.
	for id in ai_ids:
		InputManager.set_move(id, Vector2.ZERO)
		InputManager.set_action(id, false)
