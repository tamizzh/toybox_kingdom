## Capture harness for the in-match PAUSE/SETTINGS panel. Boots a real match,
## lets the board settle, then calls _show_pause_panel() directly.
##   godot --path . res://toybox_kingdoms/tools/shot_pause.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1560, 720)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	await get_tree().create_timer(8.0).timeout

	m._show_pause_panel()
	await get_tree().create_timer(1.0).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_pause.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
