extends Control

# Game-picker grid. Players browse all 30 games and tap one to start.
# Header shows live scores so players can see who's winning.

const TILE_SCRIPT := preload("res://ui/game_tile.gd")
const COLS := 6

func _ready() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Palette.ARENA_BG
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_header()
	_build_grid()

func _build_header() -> void:
	# Title
	var title_l := Label.new()
	title_l.text = "CHOOSE A GAME"
	title_l.add_theme_font_size_override("font_size", 36)
	title_l.add_theme_color_override("font_color", Palette.ACCENT)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.set_anchor_and_offset(SIDE_LEFT,   0.0, 0.0)
	title_l.set_anchor_and_offset(SIDE_RIGHT,  1.0, 0.0)
	title_l.set_anchor_and_offset(SIDE_TOP,    0.0, 8.0)
	title_l.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 54.0)
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_l)

	# Score chips (one per player)
	var players := GameManager.players
	var n := players.size()
	var chip_w := 220.0
	var spacing := chip_w + 12.0
	var start_x := Palette.CENTER_X - (n - 1) * spacing * 0.5

	for i in n:
		var p: PlayerData = players[i]

		# Colored background chip
		var chip_bg := ColorRect.new()
		chip_bg.color = Color(p.color, 0.15)
		chip_bg.size = Vector2(chip_w, 42)
		chip_bg.position = Vector2(start_x + i * spacing - chip_w * 0.5, 58)
		chip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip_bg)

		# Left-border accent
		var border := ColorRect.new()
		border.color = p.color
		border.size = Vector2(4, 42)
		border.position = chip_bg.position
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)

		var l := Label.new()
		l.text = "%s    %d / %d" % [p.display_name, p.score, ScoreManager.target_score]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", p.color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(chip_w, 42)
		l.position = chip_bg.position
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)

	# Bottom separator
	var sep := ColorRect.new()
	sep.color = Color(Palette.WALL, 0.5)
	sep.position = Vector2(0, 106)
	sep.size = Vector2(Palette.DESIGN_W, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)

func _build_grid() -> void:
	# 6 columns of 236px tiles + 5×10px gaps = 1466px, centred in the 1560 design.
	var grid_w := COLS * 236.0 + (COLS - 1) * 10.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2((Palette.DESIGN_W - grid_w) * 0.5, 112)
	scroll.size = Vector2(grid_w, 608)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var games := MiniGameRegistry.GAMES
	for i in games.size():
		var tile: Control = TILE_SCRIPT.new()
		tile.entry = games[i]
		tile.idx = i
		tile.tile_pressed.connect(GameManager.pick_game)
		grid.add_child(tile)
