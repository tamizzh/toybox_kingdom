## Verification harness for the gameplay fixes. Loads several mini-games in turn,
## drives them briefly, screenshots each, and runs a headless logic assertion on
## the snake food mechanic. Run (with a window, NOT --headless):
##   godot --path . tools/verify_shots.tscn
extends Node

const GAMES := [
	"res://minigames/racing/sprint_race.gd",   # confirm: no interior crates
	"res://minigames/growth/snake_battle.gd",  # confirm: stars to grow
	"res://minigames/sports/sumo_push.gd",     # confirm: avatar 30% smaller
]

func _ready() -> void:
	_assert_snake_growth()
	for path in GAMES:
		await _capture(path)
	get_tree().quit()

# ── visual capture ────────────────────────────────────────────────────────────
func _capture(path: String) -> void:
	var players: Array = [PlayerData.new(0), PlayerData.new(1)]
	var script: GDScript = load(path)
	var game: MiniGameBase3D = script.new()
	game.round_duration = 9999.0
	add_child(game)
	game.round_finished.connect(func(_r): pass)
	game.time_changed.connect(func(_t): pass)
	game.status_changed.connect(func(_s): pass)
	game.start_game(players)

	# Let it settle + (for snake) drive snakes toward food so growth is visible.
	var is_snake := path.ends_with("snake_battle.gd")
	for _f in 150:
		if is_snake:
			_steer_snakes(game)
		await get_tree().process_frame

	var name := path.get_file().get_basename()
	var img := get_viewport().get_texture().get_image()
	var out := "user://verify_%s.png" % name
	img.save_png(out)
	print("SHOT:", name, " -> ", ProjectSettings.globalize_path(out))
	game.queue_free()
	await get_tree().process_frame

# Point each live snake at its nearest star (never reversing) so the harness
# demonstrates eating + growth on screen.
func _steer_snakes(game: Node) -> void:
	var snakes = game.get("_snakes")
	var food = game.get("_food")
	if snakes == null or food == null or food.is_empty():
		return
	for id in snakes:
		var s = snakes[id]
		var head: Vector2i = s["cells"][s["cells"].size() - 1]
		var best = food[0]
		var bd := 1 << 30
		for f in food:
			var d: int = absi(f.x - head.x) + absi(f.y - head.y)
			if d < bd:
				bd = d; best = f
		var want: Vector2i
		if absi(best.x - head.x) >= absi(best.y - head.y):
			want = Vector2i(signi(best.x - head.x), 0)
		else:
			want = Vector2i(0, signi(best.y - head.y))
		if want != Vector2i.ZERO and want != -s["dir"]:
			s["ndir"] = want

# ── headless logic assertion: eating a star grows the snake ───────────────────
func _assert_snake_growth() -> void:
	var players: Array = [PlayerData.new(0)]
	var script: GDScript = load("res://minigames/growth/snake_battle.gd")
	var game = script.new()
	game.round_duration = 9999.0
	add_child(game)
	game.start_game(players)

	var id: int = players[0].id
	var s = game._snakes[id]
	# Drain the spawn-grow so length is stable, then place a star right ahead.
	s["grow"] = 0
	var head: Vector2i = s["cells"][s["cells"].size() - 1]
	var ahead: Vector2i = head + s["dir"]
	game._food.clear()
	game._food.append(ahead)
	var len_before: int = s["cells"].size()
	game._step_snakes()      # head moves onto the star
	# After eating, grow budget should be GROW_PER_FOOD-1 (one consumed this step)
	# and the star should be gone + refilled to FOOD_COUNT.
	var grew_ok: bool = s["grow"] == game.GROW_PER_FOOD - 1
	var ate_ok: bool = not game._food.has(ahead)
	var refilled_ok: bool = game._food.size() == game.FOOD_COUNT
	# Step forward GROW_PER_FOOD times with no food to realise the growth.
	game._food.clear()
	for _i in game.GROW_PER_FOOD:
		game._step_snakes()
	var len_after: int = s["cells"].size()
	var net_growth: int = len_after - len_before
	print("SNAKE_TEST grew=%s ate=%s refilled=%s net_growth=%d (expected +%d)" % [
		grew_ok, ate_ok, refilled_ok, net_growth, game.GROW_PER_FOOD])
	print("SNAKE_TEST RESULT: ", "PASS" if (grew_ok and ate_ok and refilled_ok and net_growth == game.GROW_PER_FOOD) else "FAIL")
	game.queue_free()
