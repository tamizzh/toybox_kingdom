## Quick mascot verification: spawn 3 recolored Avatar3D mascots facing the
## camera, then screenshot. Confirms the new mascot.glb imports, the body
## recolors per player, and the Face + Crown keep their own materials.
##   godot --path . res://toybox_kingdoms/tools/shot_mascot.tscn
extends Node3D

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 720)

	# Ground + lights so the vinyl shader reads
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.74, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.78, 0.9)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.4
	add_child(sun)

	# Three players in a row, each a different color
	for i in 3:
		var p := PlayerData.new(i)
		var av := Avatar3D.new()
		add_child(av)
		av.setup(p)
		av.auto_input = false
		av.global_position = Vector3(0, 0, (i - 1) * 1.8)
		av.face(Vector2.RIGHT)   # front (+X) toward the camera

	# Camera in front (+X), looking back at the row
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.global_position = Vector3(6.5, 1.1, 0)
	cam.look_at(Vector3(0, 0.7, 0), Vector3.UP)
	cam.make_current()

	await get_tree().create_timer(1.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_mascot.png")
	img.save_png(out)
	print("MASCOT_SHOT_SAVED: ", out)
	get_tree().quit()
