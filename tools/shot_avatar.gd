## Close-up render of a single Avatar3D to inspect the mascot model (eyes, etc.).
## Run:  godot --path . tools/shot_avatar.tscn
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

	var p := PlayerData.new(0)
	var av: Node = load("res://players/avatar3d.gd").new()
	add_child(av)
	av.setup(p)
	av.auto_input = false
	av.global_position = Vector3.ZERO

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(4.2, 1.5, 1.4)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.make_current()

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_avatar.png")
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path("user://shot_avatar.png"))
	get_tree().quit()
