extends Control

# Final match results: winner banner, scoreboard, Play Again / Main Menu.

func show_match_winner(winner_id: int, players: Array) -> void:
	var bg := ColorRect.new()
	bg.color = Palette.ARENA_BG
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_label("MATCH WINNER", 44, Vector2(240, 80), 800, Palette.NEUTRAL)
	_label(Palette.player_name(winner_id), 110, Vector2(240, 140), 800, Palette.player_color(winner_id))

	var sorted := ScoreManager.sorted_by_score()
	for i in sorted.size():
		var p: PlayerData = sorted[i]
		_label("%s   %d pts" % [p.display_name, p.score], 34, Vector2(440, 290 + i * 50), 400, p.color)

	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.add_theme_font_size_override("font_size", 40)
	again.custom_minimum_size = Vector2(340, 96)
	again.position = Vector2(250, 560)
	again.pressed.connect(_on_again)
	add_child(again)

	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.add_theme_font_size_override("font_size", 40)
	menu.custom_minimum_size = Vector2(340, 96)
	menu.position = Vector2(690, 560)
	menu.pressed.connect(GameManager.return_to_menu)
	add_child(menu)

func _label(text: String, font_size: int, pos: Vector2, width: float, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(width, font_size + 10)
	add_child(l)

func _on_again() -> void:
	GameManager.setup_match(GameManager.player_count)
	GameManager.start_match()
