## Capture harness for the in-match HUD (no results overlay). Boots a match, lets
## the AI paint some territory + the player earn coins, then screenshots with the
## full HUD visible. Run WITH a window (needs a GPU):
##   godot --path . res://toybox_kingdoms/tools/shot_hud.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1560, 720)   # landscape design framing (matches Palette.DESIGN_*)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	# Let the board develop so the stat pills / minimap show real numbers.
	await get_tree().create_timer(14.0).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_hud.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
