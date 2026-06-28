## Capture harness for the VICTORY results panel. Boots a match, lets it settle, then
## forces a win so _show_results draws the victory overlay, and saves a PNG. Run WITH a
## window (needs a GPU):
##   godot --path . res://toybox_kingdoms/tools/shot_victory.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1560, 720)   # landscape design framing (matches the HUD)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	# Let the AI paint some territory so the final standings list looks real.
	await get_tree().create_timer(8.0).timeout

	# Force the win → draws the VICTORY panel (rank/pct read from the live grid).
	m._end_match(true, "conquest")

	# Win plays a ~2.6s victory orbit + fireworks before the panel slides in.
	await get_tree().create_timer(3.6).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_victory.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
