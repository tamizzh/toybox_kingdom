## Verify the capture VFX: fire a confetti+coin burst, screenshot mid-air.
##   godot --path . res://toybox_kingdoms/tools/shot_fx.tscn
extends Node3D

const CaptureFX := preload("res://toybox_kingdoms/fx/capture_fx.gd")

func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("203028")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("cfe0ee")
	e.ambient_light_energy = 0.5
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_hdr_threshold = 1.1
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("3f6e2c")
	ground.material_override = gm
	add_child(ground)

	var fx := CaptureFX.new()
	add_child(fx)

	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.global_position = Vector3(0, 4.5, 8.0)
	cam.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	cam.make_current()

	await get_tree().process_frame
	fx.burst(Vector3.ZERO, Color("2f7de0"))   # blue-kingdom capture burst

	# catch the particles mid-flight
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_fx.png")
	img.save_png(out)
	print("FX_SHOT_SAVED: ", out)
	get_tree().quit()
