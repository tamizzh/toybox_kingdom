## Screenshot the main menu.
##   TBK_NO_COLDOPEN=1 prevents cold-open skip so we land on the actual menu.
##   godot --path . res://toybox_kingdoms/tools/shot_menu.tscn
extends Node

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1560, 720)

	var mm: Node = load("res://ui/main_menu.tscn").instantiate()
	add_child(mm)
	await get_tree().create_timer(2.5).timeout

	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_menu.png")
	img.save_png(out)
	print("SHOT_SAVED: ", out)
	get_tree().quit()
