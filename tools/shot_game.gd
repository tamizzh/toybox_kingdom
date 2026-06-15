## Full-presentation screenshot harness: mounts a mini-game PLUS the real HUD and
## touch controls (forced on), waits for the round to get going, then saves a PNG.
## Lets us compare a live frame against snake_target.png / race_target.png.
##
## Run:  godot --path . tools/shot_game.tscn -- <slug> [player_count] [wait_secs]
## e.g.  godot --path . tools/shot_game.tscn -- snake_battle 2 3.2
extends Node

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1560, 720))

	var args := OS.get_cmdline_user_args()
	var slug: String = args[0] if args.size() > 0 else "snake_battle"
	var count: int = int(args[1]) if args.size() > 1 else 2
	var wait_s: float = float(args[2]) if args.size() > 2 else 3.2

	# Find the registry entry for this slug.
	var entry := {}
	for g in MiniGameRegistry.GAMES:
		if MiniGameRegistry.slug(g) == slug:
			entry = g
			break
	if entry.is_empty():
		push_error("shot_game: unknown slug '%s'" % slug)
		get_tree().quit()
		return

	# Players + demo scores so the chips show numbers like the reference.
	var players: Array = []
	for i in count:
		players.append(PlayerData.new(i))
	ScoreManager.setup(players, 5)
	var demo := [0, 1, 2, 3]
	for i in count:
		players[i].score = demo[i]

	# Game — mirrors GameManager.pick_game().
	var game: MiniGameBase3D = load(entry.script).new()
	game.game_title = entry.title
	game.round_duration = 9999.0
	game.category = entry.get("category", "")
	game.slug = slug
	if "tagline" in game:
		game.tagline = entry.get("tagline", "")
	game.arena_color = Palette.category_arena(game.category)
	add_child(game)
	game.round_finished.connect(func(_r): pass)
	game.time_changed.connect(func(_t): pass)
	game.status_changed.connect(func(_s): pass)
	game.start_game(players)

	# HUD overlay — mirrors main._on_round_started().
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	var hud: Control = load("res://ui/hud.tscn").instantiate()
	hud_layer.add_child(hud)
	hud.setup(players)
	hud.set_status(entry.title)
	if hud.has_method("set_subtitle"):
		hud.set_subtitle(entry.get("tagline", ""))
	hud.set_time(45.0)

	# Touch controls — force-show even on desktop so the shot matches the target.
	DeviceMode.has_touch = true
	var touch_layer := CanvasLayer.new()
	add_child(touch_layer)
	var touch: Control = load("res://ui/touch_controls.tscn").instantiate()
	touch_layer.add_child(touch)
	touch.setup(players)
	if touch.has_method("set_action_label"):
		touch.set_action_label(game.action_label if "action_label" in game else "ACTION")

	await get_tree().create_timer(wait_s).timeout

	# Spread any avatars across the arena and face the camera so they read well.
	if not game.avatars.is_empty():
		var ids := game.avatars.keys()
		var xs := [-6.0, 4.0, -2.0, 7.0]
		for i in ids.size():
			var av = game.avatars[ids[i]]
			av.global_position = Vector3(xs[i % xs.size()], 0.0, av.global_position.z)
			if av.has_method("face"):
				av.face(Vector2(0, -1))
		await get_tree().process_frame
		await get_tree().process_frame

	# Optional: trigger a win to capture the crown + confetti celebration.
	var mode: String = args[3] if args.size() > 3 else ""
	if mode == "win":
		var results := {}
		for i in count:
			results[i] = (3 if i == 0 else 0)
		game.finish_round(results)
		await get_tree().create_timer(0.5).timeout

	var path := "user://shot_%s.png" % slug
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path(path))
	get_tree().quit()
