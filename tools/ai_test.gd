## Solo-vs-CPU smoke test. Sets up a 1-human + N-CPU match, mounts a game with a real
## AIController, runs a few seconds, and reports whether CPU avatars actually moved.
## Run:  godot --path . tools/ai_test.tscn -- <slug> <cpu_count> <difficulty> <secs>
extends Node

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var slug: String = a[0] if a.size() > 0 else "tank_battle"
	var cpus: int = int(a[1]) if a.size() > 1 else 3
	var diff: int = int(a[2]) if a.size() > 2 else 2
	var secs: float = float(a[3]) if a.size() > 3 else 6.0

	var entry := {}
	for g in MiniGameRegistry.GAMES:
		if MiniGameRegistry.slug(g) == slug:
			entry = g
			break

	GameManager.setup_match(1, cpus, diff)
	var players := GameManager.players
	print("PLAYERS: ", players.map(func(p): return "id%d ai=%s" % [p.id, p.is_ai]))

	var game: MiniGameBase3D = load(entry.script).new()
	game.game_title = entry.title
	game.round_duration = 9999.0
	game.category = entry.get("category", "")
	game.slug = slug
	if "tagline" in game:
		game.tagline = entry.get("tagline", "")
	add_child(game)
	game.round_finished.connect(func(_r): pass)
	game.time_changed.connect(func(_t): pass)
	game.status_changed.connect(func(_s): pass)
	game.start_game(players)

	var ai_ids: Array = []
	for p in players:
		if p.is_ai:
			ai_ids.append(p.id)
	var ai := AIController.new()
	game.add_child(ai)
	ai.setup(game, ai_ids, diff)

	# Wait out the countdown, snapshot start positions.
	await get_tree().create_timer(3.2).timeout
	var start_pos := {}
	for id in ai_ids:
		var av = game.get_avatar(id)
		if av:
			start_pos[id] = av.global_position

	await get_tree().create_timer(secs).timeout

	for id in ai_ids:
		var av = game.get_avatar(id)
		if av and start_pos.has(id):
			var moved: float = start_pos[id].distance_to(av.global_position)
			print("CPU %d moved %.2f units, dead=%s" % [id, moved, ("dead" in av and av.dead)])

	# Overlap check: min pairwise distance between living avatars (capsule r=0.48,
	# so non-overlapping pairs should stay >= ~0.9 apart).
	var live := []
	for p in players:
		var av = game.get_avatar(p.id)
		if av and is_instance_valid(av) and not ("dead" in av and av.dead):
			live.append(av)
	var min_d := INF
	for i in live.size():
		for j in range(i + 1, live.size()):
			min_d = minf(min_d, live[i].global_position.distance_to(live[j].global_position))
	if min_d != INF:
		print("MIN_PAIR_DIST: %.2f (>=~0.9 means no overlap)" % min_d)

	var img := get_viewport().get_texture().get_image()
	var path := "user://ai_%s.png" % slug
	img.save_png(path)
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path(path))
	get_tree().quit()
