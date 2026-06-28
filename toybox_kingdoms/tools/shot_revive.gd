## Capture harness for the revive / continue-on-death panel. Boots a match, lets it
## settle, then builds the continue panel directly so we can screenshot it. Run WITH a
## window (needs a GPU):
##   godot --path . res://toybox_kingdoms/tools/shot_revive.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1560, 720)   # landscape design framing (matches the HUD)

	var km: GDScript = load("res://toybox_kingdoms/kingdom_match.gd")
	var m: Node = km.new()
	add_child(m)

	# Let the AI paint some territory so the board behind the panel looks real.
	await get_tree().create_timer(8.0).timeout

	# Build just the revive panel (no real elimination/pause needed for a still capture).
	m._build_continue_panel()
	await get_tree().create_timer(0.6).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_revive.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
