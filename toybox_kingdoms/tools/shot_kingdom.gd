## Capture harness: run the kingdom match, let the AI build kingdoms for a few
## seconds, pull the camera back to an overview, and save a PNG so we can eyeball
## the result. Run WITH a window (not --headless):
##   godot --path . res://toybox_kingdoms/tools/shot_kingdom.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1920, 1080)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	# let the AI expand: castles should hit tier 2-3 and towns fill in
	await get_tree().create_timer(9.0).timeout

	# overview camera so the whole toybox is in frame
	if m.camera:
		m.camera.target = null
		m.camera.global_position = Vector3(0, 72, 48)
		m.camera.look_at(Vector3.ZERO, Vector3.UP)
		m.camera.fov = 56
	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_kingdom.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)

	# close-up over a developed kingdom to check the town (houses + citizens)
	if m.camera:
		var focus := Vector3(-9.3, 0.0, 19.5)
		m.camera.global_position = focus + Vector3(0, 16, 13)
		m.camera.look_at(focus, Vector3.UP)
		m.camera.fov = 50
	await get_tree().process_frame
	await get_tree().process_frame
	var img2 := get_viewport().get_texture().get_image()
	var out2 := ProjectSettings.globalize_path("res://.claude/shot_kingdom_close.png")
	img2.save_png(out2)
	print("SHOT_SAVED: ", out2)
	get_tree().quit()
