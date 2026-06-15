## Renders a branded boot-splash image to res://assets/splash.png at an exact
## 1280x720 via a SubViewport (independent of the OS window size).
## Run:  godot --path . tools/gen_splash.tscn
extends Node

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

	var f1 := MascotFace.new()
	f1.set_color(Palette.PLAYER_COLORS[0])
	f1.size = Vector2(200, 200)
	f1.position = Vector2(420, 200)
	vp.add_child(f1)
	var f2 := MascotFace.new()
	f2.set_color(Palette.PLAYER_COLORS[1])
	f2.size = Vector2(200, 200)
	f2.position = Vector2(660, 200)
	vp.add_child(f2)

	var title := Label.new()
	title.text = "PARTY PALS ARENA"
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1280, 100)
	title.position = Vector2(0, 430)
	vp.add_child(title)

	var sub := Label.new()
	sub.text = "Pass the phone. Race to 5."
	sub.add_theme_font_size_override("font_size", 32)
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
