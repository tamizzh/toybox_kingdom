## UI screenshot tool. Instantiates a UI screen script (passed after `--`) and
## saves a PNG so menu / results polish can be verified headlessly-ish.
## Run (with a window):
##   godot --path . tools/ui_shot.tscn -- res://ui/main_menu.gd [menu|results]
extends Node

func _ready() -> void:
	var uargs := OS.get_cmdline_user_args()
	var path: String = uargs[0] if uargs.size() > 0 else "res://ui/main_menu.gd"
	var mode: String = uargs[1] if uargs.size() > 1 else "menu"
	var seed_coins: int = int(uargs[2]) if uargs.size() > 2 else 0
	var slug := path.get_file().get_basename()

	if seed_coins > 0:
		SaveManager.add_coins(seed_coins)

	# Some screens read live match state — fake a finished 2-player match.
	if mode == "results":
		GameManager.setup_match(2)
		ScoreManager.players[0].score = 5
		ScoreManager.players[1].score = 3

	var scr: GDScript = load(path)
	var screen: Control = scr.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)

	if mode == "results" and screen.has_method("show_match_winner"):
		screen.show_match_winner(0, GameManager.players)

	for _i in 8:
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var out := "user://ui_%s.png" % slug
	img.save_png(out)
	print("SCREENSHOT_SAVED:", ProjectSettings.globalize_path(out))
	get_tree().quit()
