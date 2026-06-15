## Bot-driven playtest harness. Loads ONE mini-game (path passed after `--`),
## drives every player with a roaming + tapping bot so the game actually plays
## out, captures screenshots mid-round, and logs a timeline + final results.
## Run (with a window, NOT --headless):
##   godot --path . tools/play_bot.tscn -- res://minigames/<cat>/<game>.gd [num_players] [seconds]
extends Node

var game: MiniGameBase3D
var _t := 0.0
var _cap := 0.0
var _shot_idx := 0
var _slug := "game"
var _cap_secs: float = 9.0
var _phase := [0.0, 0.0, 0.0, 0.0]
var _next_tap := [0.0, 0.0, 0.0, 0.0]
var _tap_state := [false, false, false, false]
var _nplayers := 4
var _finished := false
var _last_alive := -1

func _ready() -> void:
	var uargs := OS.get_cmdline_user_args()
	if uargs.is_empty():
		push_error("usage: -- <game.gd> [num_players] [seconds]")
		get_tree().quit(); return
	var path: String = uargs[0]
	if uargs.size() > 1: _nplayers = int(uargs[1])
	if uargs.size() > 2: _cap_secs = float(uargs[2])
	_slug = path.get_file().get_basename()

	var players: Array = []
	for i in _nplayers:
		players.append(PlayerData.new(i))
	for i in _nplayers:
		_phase[i] = randf() * TAU
		_next_tap[i] = randf_range(0.2, 0.6)

	var script: GDScript = load(path)
	game = script.new()
	add_child(game)
	game.round_finished.connect(_on_finished)
	game.time_changed.connect(func(_t2): pass)
	game.status_changed.connect(func(_s): pass)
	game.start_game(players)
	print("PLAY_START ", _slug, " players=", _nplayers)

func _process(delta: float) -> void:
	if game == null:
		return
	_t += delta
	# Drive bots once the countdown has handed control to the game.
	_drive(delta)

	# Track eliminations / score snapshots.
	var alive := 0
	for p in game.players:
		if p.alive: alive += 1
	if alive != _last_alive:
		_last_alive = alive
		print("  t=%.1f alive=%d" % [_t, alive])

	# Capture two screenshots spread across the round.
	if _shot_idx < 2 and _t >= _cap_secs * (0.45 + 0.45 * _shot_idx):
		_save_shot()
	if _t >= _cap_secs and not _finished:
		print("PLAY_TIMEOUT ", _slug, " (no natural finish within %.0fs)" % _cap_secs)
		_dump_scores()
		get_tree().quit()

func _drive(delta: float) -> void:
	for i in _nplayers:
		# Roaming heading that slowly rotates, distinct per player.
		_phase[i] += delta * (0.7 + 0.25 * i)
		var dir := Vector2(cos(_phase[i]), sin(_phase[i]))
		# Bias P0 toward arena centre, others outward — creates contact/variety.
		InputManager.set_move(i, dir)
		# Tap cadence: toggle action so get_action_just fires repeatedly,
		# but hold ~60% duty so hold-to-run games still advance.
		_next_tap[i] -= delta
		if _next_tap[i] <= 0.0:
			_tap_state[i] = not _tap_state[i]
			_next_tap[i] = randf_range(0.12, 0.30) if _tap_state[i] else randf_range(0.05, 0.12)
			InputManager.set_action(i, _tap_state[i])

func _on_finished(results: Dictionary) -> void:
	if _finished: return
	_finished = true
	print("PLAY_FINISH ", _slug, " at t=%.1f" % _t)
	print("  results=", results)
	_save_shot()
	get_tree().create_timer(0.2).timeout.connect(func(): get_tree().quit())

func _dump_scores() -> void:
	for p in game.players:
		print("  p%d alive=%s round_value=%.2f finished=%s" % [p.id, p.alive, p.round_value, p.finished])

func _save_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	var out := "user://play_%s_%d.png" % [_slug, _shot_idx]
	img.save_png(out)
	print("  SHOT ", ProjectSettings.globalize_path(out))
	_shot_idx += 1
