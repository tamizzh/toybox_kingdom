## Close ground-level capture over WILDERNESS to judge the painted tiles up close
## (the overview zoom is too far to see tile detail).
##   godot --path . res://toybox_kingdoms/tools/shot_ground.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1920, 1080)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	await get_tree().create_timer(4.0).timeout   # early: most of the board is still wilderness

	if m.camera:
		m.camera.target = null
		# low 3/4 framing (same pitch as the gameplay follow-cam) over an open patch
		var focus := Vector3(6.0, 0.0, 0.0)
		m.camera.global_position = focus + Vector3(0, 9.0, 11.0)
		m.camera.look_at(focus, Vector3.UP)
		m.camera.fov = 46
	if m._ui_layer:
		m._ui_layer.visible = false
	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_ground.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
