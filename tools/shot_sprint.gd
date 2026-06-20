## One-off capture: load Sprint Race, let it settle past the countdown, and save
## a clean in-engine screenshot to res://.claude/shot_sprint.png.
## Run (WITH a window, not --headless):  godot --path . tools/shot_sprint.tscn
extends Node

func _ready() -> void:
	var players: Array = [PlayerData.new(0), PlayerData.new(1)]
	var script: GDScript = load("res://minigames/racing/sprint_race.gd")
	var game: MiniGameBase3D = script.new()
	game.round_duration = 9999.0
	add_child(game)
	game.round_finished.connect(func(_r): pass)
	game.time_changed.connect(func(_t): pass)
	game.status_changed.connect(func(_s): pass)
	game.start_game(players)

	# Wait out the 3-2-1-GO countdown (+ possible first-time rule card).
	for _f in 480:
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_sprint.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
