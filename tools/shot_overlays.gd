## Screenshots all overlay screens (daily, settings, profile, onboarding).
## Run:  godot --path . tools/shot_overlays.tscn
extends Node

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1560, 720))
	SaveManager.set_consent_done(true)
	if SaveManager.has_method("set_onboarding_done"):
		SaveManager.set_onboarding_done(true)

	var menu: Control = load("res://ui/main_menu.tscn").instantiate()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	# Daily
	var daily: Control = load("res://ui/daily_screen.gd").new()
	menu.add_child(daily)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_save(".claude/shot_daily.png")
	daily.queue_free()
	await get_tree().process_frame

	# Settings
	var settings: Control = load("res://ui/settings_screen.gd").new()
	menu.add_child(settings)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_save(".claude/shot_settings.png")
	settings.queue_free()
	await get_tree().process_frame

	# Profile
	var profile: Control = load("res://ui/profile_screen.gd").new()
	menu.add_child(profile)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_save(".claude/shot_profile.png")
	profile.queue_free()
	await get_tree().process_frame

	# Campaign
	var campaign: Control = load("res://ui/campaign_screen.gd").new()
	menu.add_child(campaign)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_save(".claude/shot_campaign.png")
	campaign.queue_free()
	await get_tree().process_frame

	# Onboarding (page 0)
	if SaveManager.has_method("set_onboarding_done"):
		SaveManager.set_onboarding_done(false)
	var onboarding: Control = load("res://ui/onboarding_screen.gd").new()
	menu.add_child(onboarding)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_save(".claude/shot_onboarding.png")
	onboarding.queue_free()
	await get_tree().process_frame

	get_tree().quit()

func _save(rel_path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://" + rel_path)
	img.save_png(path)
	print("SCREENSHOT_SAVED:", path)
