## Capture all 7 menu overlay screens in one run. Each overlay is mounted on a
## fresh CanvasLayer over the live main menu, screenshotted, then freed before
## the next one appears.
##   TBK_NO_COLDOPEN=1  (prevents cold-open skip so we actually see the menu)
##   godot --path . res://toybox_kingdoms/tools/shot_all_overlays.tscn
extends Node

const SCREENS := [
	["campaign",  "res://ui/campaign_screen.gd"],
	["daily",     "res://ui/daily_screen.gd"],
	["onboarding","res://ui/onboarding_screen.gd"],
	["profile",   "res://ui/profile_screen.gd"],
	["settings",  "res://ui/settings_screen.gd"],
	["shop",      "res://ui/shop_screen.gd"],
	["world_map", "res://ui/world_map_screen.gd"],
]

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1560, 720)

	var mm: Node = load("res://ui/main_menu.tscn").instantiate()
	add_child(mm)
	await get_tree().create_timer(2.5).timeout

	for entry in SCREENS:
		var screen_name: String = entry[0]
		var script_path: String = entry[1]

		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)

		var overlay: Control = load(script_path).new()
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(overlay)

		await get_tree().create_timer(1.8).timeout

		var img := get_viewport().get_texture().get_image()
		var out := ProjectSettings.globalize_path("res://.claude/shot_%s.png" % screen_name)
		img.save_png(out)
		print("SHOT_SAVED: ", out)

		layer.queue_free()
		await get_tree().create_timer(0.4).timeout

	get_tree().quit()
