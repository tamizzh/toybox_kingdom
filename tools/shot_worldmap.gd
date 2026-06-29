## World-conquest overlay screenshot tool — verifies the toy-paper country thumbnails.
## Run (with a window): godot --path . tools/shot_worldmap.tscn
extends Node

func _ready() -> void:
	# Seed mid-run progress so the shot shows conquered (green) + current (gold) + locked (slate).
	SaveManager._cfg.set_value("progress", "endless_island", 12)

	var scr: GDScript = load("res://ui/world_map_screen.gd")
	var screen: Control = scr.new()
	add_child(screen)

	for _i in 12:
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := "user://shot_worldmap.png"
	img.save_png(out)
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path(out))
	get_tree().quit()
