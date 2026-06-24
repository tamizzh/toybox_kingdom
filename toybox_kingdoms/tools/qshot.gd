## Quick capture: load the match, wait a few seconds, shoot one overview PNG.
## Short wait (vs shot_kingdom's 90s) so the window doesn't get closed mid-run;
## fine for judging the wilderness ground, which is fully visible early.
##   godot --path . res://toybox_kingdoms/tools/qshot.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1920, 1080)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	await get_tree().create_timer(6.0).timeout

	if m.camera:
		m.camera.target = null
		m.camera.global_position = Vector3(0, 30, 30)
		m.camera.look_at(Vector3(0, 0, -2), Vector3.UP)
		m.camera.fov = 50
	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_kingdom.png")
	img.save_png(out)
	print("QSHOT_SAVED: ", out)
	get_tree().quit()
