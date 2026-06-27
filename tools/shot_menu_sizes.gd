## Captures the real main menu at several device resolutions into .claude/, so we
## can eyeball the cover-crop background + chrome layout on mobile / desktop / tablet.
## Each size renders into its own SubViewport (independent of the OS window/monitor).
## Run:  godot --path . tools/shot_menu_sizes.tscn
extends Node

const MENU := "res://ui/main_menu.tscn"

# (label, width, height) — real 2025 flagships at native res, in LANDSCAPE
# (the game is landscape-locked, so the long edge is width).
const SIZES := [
	["iphone17_pro_max", 2868, 1320],  # 6.9"  19.5:9 (2.17)
	["iphone17", 2622, 1206],          # 6.3"  19.5:9 (2.17)
	["galaxy_s25_ultra", 3120, 1440],  # 6.9"  19.3:9 (2.17)
	["galaxy_s25", 2340, 1080],        # 6.2"  19.5:9 (2.17)
	["galaxy_z_fold7", 2184, 1968],    # 8.0"  unfolded ~1.11 (near-square stress case)
]


func _ready() -> void:
	# Skip the first-run consent + onboarding gates so we capture the bare menu.
	if SaveManager.has_method("set_consent_done"):
		SaveManager.set_consent_done(true)
	if SaveManager.has_method("set_onboarding_done"):
		SaveManager.set_onboarding_done(true)

	var menu_scene: PackedScene = load(MENU)
	for entry in SIZES:
		var label: String = entry[0]
		var w: int = entry[1]
		var h: int = entry[2]
		var vp := SubViewport.new()
		vp.size = Vector2i(w, h)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var menu := menu_scene.instantiate()
		vp.add_child(menu)
		# Let _ready build the UI, the Ken Burns tween settle, and frames render.
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		var img := vp.get_texture().get_image()
		var path := "res://.claude/shot_menu_%s.png" % label
		img.save_png(ProjectSettings.globalize_path(path))
		print("SHOT_SAVED:", path, " (", w, "x", h, ")")
		menu.queue_free()
		vp.queue_free()
		await get_tree().process_frame
	get_tree().quit()
