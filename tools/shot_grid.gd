## Screenshot the game-picker grid to confirm it shows only the launch roster.
## Run:  godot --path . tools/shot_grid.tscn
extends Node

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GameManager.setup_match(2)
	GameManager.players[0].score = 2
	GameManager.players[1].score = 1
	ScoreManager.setup(GameManager.players, 5)
	var grid: Control = load("res://ui/game_grid.tscn").instantiate()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(grid)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_grid.png")
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path("user://shot_grid.png"))
	print("LAUNCH_COUNT:", MiniGameRegistry.launch_indices().size())
	get_tree().quit()
