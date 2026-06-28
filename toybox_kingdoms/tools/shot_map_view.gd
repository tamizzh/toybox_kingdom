## Screenshot the full-board map overview. Boots a match, lets it run 10s,
## then triggers the MAP toggle and waits 2s for the camera to settle.
##   godot --path . res://toybox_kingdoms/tools/shot_map_view.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1560, 720)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	await get_tree().create_timer(10.0).timeout
	m._toggle_map_view()

	await get_tree().create_timer(2.0).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_map_view.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
