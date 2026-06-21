## Renders a branded boot-splash image to res://assets/splash.png at an exact
## 1280x720 via a SubViewport (independent of the OS window size).
## Run:  godot --path . tools/gen_splash.tscn
extends Node

const Roster := preload("res://toybox_kingdoms/data/roster.gd")


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color("18142a")
	bg.size = Vector2(1280, 720)
	vp.add_child(bg)

	# A row of rival-ruler crowns in their kingdom colours.
	var crowns := _CrownRow.new()
	crowns.size = Vector2(1280, 240)
	crowns.position = Vector2(0, 150)
	vp.add_child(crowns)

	var title := Label.new()
	title.text = "TOYBOX KINGDOMS"
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1280, 110)
	title.position = Vector2(0, 410)
	vp.add_child(title)

	var sub := Label.new()
	sub.text = "Claim the land. Rule the toybox."
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", Color("ffd23f"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1280, 50)
	sub.position = Vector2(0, 540)
	vp.add_child(sub)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://assets/splash.png"))
	print("SPLASH_SAVED:", ProjectSettings.globalize_path("res://assets/splash.png"))
	get_tree().quit()


# Five kingdom crowns bobbing across the splash, coloured to match the in-game banners.
class _CrownRow extends Control:
	const N := 5
	func _draw() -> void:
		var spacing := size.x / float(N + 1)
		for i in N:
			var c := Color.from_hsv(fmod(0.02 + float(i) / float(Roster.RULERS.size()), 1.0), 0.85, 0.92)
			var cx := spacing * float(i + 1)
			var cy := size.y * 0.5 + sin(float(i) * 1.1) * 18.0
			DrawKit.crown(self, Vector2(cx, cy), 150.0, c, 6.0)
