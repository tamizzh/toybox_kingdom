## Single-island thumbnail capture. Invoked by gen_island_thumbs.ps1.
## Reads TBK_ISLAND env var, boots the match, snaps the overhead view,
## saves assets/islands/island_N.png at 480x270, then quits.
extends Node

func _ready() -> void:
	var idx := int(OS.get_environment("TBK_ISLAND"))

	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_factor = 1.0
	win.size = Vector2i(1920, 1080)

	var m: Node = load("res://toybox_kingdoms/kingdom_match.gd").new()
	add_child(m)

	# Disable the camera's own process so the intro animation can't override
	# the overhead position we set directly below.
	if m.camera:
		m.camera.set_process(false)
		m.camera.set_physics_process(false)
		m.camera.global_position = Vector3(0.0, 171.0, 21.0)
		m.camera.look_at(Vector3.ZERO, Vector3.UP)
		m.camera.fov = 55.0

	if m._ui_layer:
		m._ui_layer.visible = false

	# CanvasLayer.visible is unreliable in Godot 4 — hide each child CanvasItem instead.
	if m._dbg_label and is_instance_valid(m._dbg_label):
		var dbg_layer: Node = m._dbg_label.get_parent()
		for child in dbg_layer.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false

	# Run physics for 2.5 s so kingdoms spread small coloured territory patches
	# (adds vibrancy). Power-ups spawn at 10 s, so none appear in this window.
	# process_always=true fires the timer even if _offer_continue pauses the tree.
	await get_tree().create_timer(2.5, true).timeout

	# Wait for the renderer to finish the current frame (Forward Mobile / D3D12
	# requires this — get_image() can stall mid-frame otherwise).
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("ERROR: empty viewport image for island ", idx)
		get_tree().quit(1)
		return
	img.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	var path := ProjectSettings.globalize_path(
		"res://assets/islands/island_%d.png" % idx)
	var err := img.save_png(path)
	if err != OK:
		print("ERROR: save failed (", err, ") for island ", idx)
		get_tree().quit(1)
		return
	print("SAVED: island_%d.png" % idx)
	get_tree().quit()
