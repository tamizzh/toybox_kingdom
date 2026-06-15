## Screenshot capture tool. Loads tank_battle with 2 fake players, waits 4
## frames for the scene to fully render, saves arena_screenshot.png to the
## project root's user:// directory, then quits.
## Run via: godot --path . tools/screenshot_test.tscn
extends Node

const SHOT_PATH := "user://arena_screenshot.png"

func _ready() -> void:
	var players: Array = [PlayerData.new(0), PlayerData.new(1)]

	var script: GDScript = load("res://minigames/combat/tank_battle.gd")
	var game: MiniGameBase3D = script.new()
	game.round_duration = 9999.0
	add_child(game)
	game.round_finished.connect(func(_r): pass)
	game.time_changed.connect(func(_t): pass)
	game.status_changed.connect(func(_s): pass)
	game.start_game(players)

	await get_tree().process_frame
	await get_tree().process_frame

	# Move avatars to open arena center and face toward camera so eyes show
	var ids := game.avatars.keys()
	var cx_offsets := [-3.5, 3.5, -3.5, 3.5]
	var cz_offsets := [0.0, 0.0, 2.0, 2.0]
	for i in ids.size():
		var av = game.avatars[ids[i]]
		av.global_position = Vector3(cx_offsets[i], 0, cz_offsets[i])
		if av.has_method("face"):
			av.face(Vector2(0, -1))   # face +Z = toward camera

	await get_tree().process_frame
	await get_tree().process_frame
	_save_shot()

func _save_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_PATH)
	var real := ProjectSettings.globalize_path(SHOT_PATH)
	print("SCREENSHOT_SAVED:", real)
	get_tree().quit()
