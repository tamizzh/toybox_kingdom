## Screenshots the main menu (with Shop/Settings buttons) and the Shop overlay.
## Run:  godot --path . tools/shot_menu.tscn
extends Node

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	SaveManager.set_consent_done(true)   # skip the first-run consent gate here

	var menu: Control = load("res://ui/main_menu.tscn").instantiate()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_save("shot_menu")

	var shop: Control = load("res://ui/shop_screen.gd").new()
	menu.add_child(shop)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_save("shot_shop")
	get_tree().quit()

func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://%s.png" % name)
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path("user://%s.png" % name))
