## Close-up of the snake head (uses snake_battle._build_head directly).
## Run:  godot --path . tools/shot_head.tscn
extends Node

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(900, 900))

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("3a3550")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e8f8")
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -28, 0)
	key.light_energy = 1.5
	add_child(key)

	var snake = load("res://minigames/growth/snake_battle.gd").new()
	var head: Node3D = snake._build_head(Palette.PLAYER_COLORS[0])
	add_child(head)
	head.position = Vector3(0, 0.55, 0)   # eyes face +X (no rotation)

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(2.9, 1.0, 1.0)
	cam.look_at(Vector3(0, 0.62, 0), Vector3.UP)
	cam.make_current()

	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_head.png")
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path("user://shot_head.png"))
	get_tree().quit()
