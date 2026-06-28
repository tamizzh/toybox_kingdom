## Capture HUD at a wider-than-design resolution (21:9) to verify right/bottom anchors.
## Run: godot --path . res://toybox_kingdoms/tools/shot_hud_wide.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1920, 720)   # wider than 1560 — tests right-edge anchoring

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	await get_tree().create_timer(14.0).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_hud_wide.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
