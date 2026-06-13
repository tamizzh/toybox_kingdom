extends Node

const GAMES := ["growth/snake_battle", "sports/sumo_push", "sports/mini_soccer",
	"platform/falling_platforms", "racing/lane_switch"]

func _ready() -> void:
	for path in GAMES:
		var name: String = path.get_file()
		var cat: String = path.get_base_dir()
		var game: Node = load("res://minigames/%s.gd" % path).new()
		game.game_title = name
		game.round_duration = 30.0
		game.category = cat
		game.slug = name
		add_child(game)
		game.start_game([PlayerData.new(0), PlayerData.new(1), PlayerData.new(2), PlayerData.new(3)])
		for i in range(45):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://_cap_%s.png" % name)
		game.queue_free()
		await get_tree().process_frame
	print("MULTICAP")
	get_tree().quit()
