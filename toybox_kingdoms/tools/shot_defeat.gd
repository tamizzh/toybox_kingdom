## Capture harness for the DEFEATED results panel. Boots a match, lets it settle a
## moment, then forces a loss so _show_results draws the defeat overlay, and saves a
## PNG. Run WITH a window (needs a GPU):
##   godot --path . res://toybox_kingdoms/tools/shot_defeat.tscn
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

	# Force the loss → draws the DEFEATED panel (rank/pct read from the live grid).
	m._end_match(false, "conquered")

	# Let the panel's fade/slide tweens settle.
	await get_tree().create_timer(1.0).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_defeat.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
