extends Control

# Game-picker grid. Players browse all 30 games and tap one to start.
# Header shows live scores so players can see who's winning.

const TILE_SCRIPT := preload("res://ui/game_tile.gd")
const COLS := 6

var _spinning := false


# Drawn star icon for the RANDOM tile (replaces the 🎲 emoji so it renders the
# same on every platform). Recolours green when a game is chosen.
class _RandIcon extends Control:
	var col := Color("aa60ff")
	func _draw() -> void:
		DrawKit.star(self, size * 0.5, minf(size.x, size.y) * 0.44, col)

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
	_build_match_point_overlay()

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

	_build_hype_banner()

func _build_hype_banner() -> void:
	var sorted := ScoreManager.sorted_by_score()
	if sorted.is_empty():
		return
	var leader: PlayerData = sorted[0]
	var text := ""
	var color := leader.color
	if sorted.size() > 1 and leader.score > 0:
		var runner: PlayerData = sorted[1]
		var gap := leader.score - runner.score
		if gap <= 1:
			text = "%s leads by %d - steal this round!" % [leader.display_name, gap]
		else:
			text = "%s is pulling ahead - time for a comeback!" % leader.display_name
	else:
		text = "Pick your best game and grab the early lead!"
		color = Palette.WARN
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 84)
	l.size = Vector2(Palette.DESIGN_W, 24)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)

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

	_add_random_tile(grid)

	# Show only the curated launch roster; the rest ship later as content updates.
	for i in MiniGameRegistry.launch_indices():
		var tile: Control = TILE_SCRIPT.new()
		tile.entry = MiniGameRegistry.GAMES[i]
		tile.idx = i
		tile.tile_pressed.connect(GameManager.pick_game)
		grid.add_child(tile)


func _add_random_tile(grid: GridContainer) -> void:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(236, 158)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e1040")
	style.border_color = Color("aa60ff")
	style.border_width_left   = 3; style.border_width_right  = 3
	style.border_width_top    = 3; style.border_width_bottom = 3
	style.corner_radius_top_left     = 18; style.corner_radius_top_right    = 18
	style.corner_radius_bottom_left  = 18; style.corner_radius_bottom_right = 18
	tile.add_theme_stylebox_override("normal",  style)
	var hov := style.duplicate() as StyleBoxFlat
	hov.bg_color = Color("2d1860")
	tile.add_theme_stylebox_override("hover",   hov)
	tile.add_theme_stylebox_override("pressed", style)

	var dice_l := _RandIcon.new()
	dice_l.position = Vector2(0, 16)
	dice_l.size = Vector2(236, 66)
	dice_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(dice_l)

	var name_l := Label.new()
	name_l.text = "RANDOM"
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", Color("aa60ff"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, 88)
	name_l.size = Vector2(236, 28)
	name_l.clip_contents = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_l)

	var hint_l := Label.new()
	hint_l.text = "tap to spin!"
	hint_l.add_theme_font_size_override("font_size", 12)
	hint_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_l.position = Vector2(0, 120)
	hint_l.size = Vector2(236, 20)
	hint_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(hint_l)

	tile.pressed.connect(_on_random_pressed.bind(dice_l, name_l, hint_l))
	grid.add_child(tile)


func _on_random_pressed(dice_l: _RandIcon, name_l: Label, hint_l: Label) -> void:
	if _spinning:
		return
	_spinning = true
	var idxs := MiniGameRegistry.launch_indices()
	var chosen_idx: int = idxs[randi() % idxs.size()]
	name_l.add_theme_font_size_override("font_size", 11)
	for tick in 22:
		var show_idx: int = idxs[randi() % idxs.size()]
		name_l.text = MiniGameRegistry.GAMES[show_idx].title
		name_l.add_theme_color_override("font_color", Color("aa60ff"))
		hint_l.text = "spinning..."
		var delay := 0.04 + float(tick) * 0.012
		await get_tree().create_timer(delay).timeout
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.text = MiniGameRegistry.GAMES[chosen_idx].title
	name_l.add_theme_color_override("font_color", Palette.SAFE)
	hint_l.text = "launching..."
	dice_l.col = Palette.SAFE
	dice_l.queue_redraw()
	await get_tree().create_timer(0.45).timeout
	GameManager.pick_game(chosen_idx)


func _build_match_point_overlay() -> void:
	var target := ScoreManager.target_score
	var mp_player: PlayerData = null
	for p: PlayerData in ScoreManager.players:
		if p.score == target - 1:
			if mp_player == null or p.score > mp_player.score:
				mp_player = p
	if mp_player == null:
		return

	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.02, 0.10, 0.92)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.z_index = 10
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var mp_l := Label.new()
	mp_l.text = "MATCH POINT!"
	mp_l.add_theme_font_size_override("font_size", 72)
	mp_l.add_theme_color_override("font_color", Palette.WARN)
	mp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_l.size = Vector2(Palette.DESIGN_W, 100)
	mp_l.position = Vector2(0, 220)
	mp_l.pivot_offset = Vector2(Palette.DESIGN_W * 0.5, 50)
	mp_l.scale = Vector2(0.4, 0.4)
	mp_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(mp_l)

	var tw := mp_l.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(mp_l, "scale", Vector2(1.0, 1.0), 0.4)

	var sub_l := Label.new()
	sub_l.text = "%s is ONE WIN AWAY!" % mp_player.display_name
	sub_l.add_theme_font_size_override("font_size", 36)
	sub_l.add_theme_color_override("font_color", mp_player.color)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l.size = Vector2(Palette.DESIGN_W, 56)
	sub_l.position = Vector2(0, 348)
	sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(sub_l)

	# Fade out and free after 2.5s
	var fade := overlay.create_tween()
	fade.tween_interval(2.0)
	fade.tween_property(overlay, "modulate:a", 0.0, 0.45)
	fade.tween_callback(overlay.queue_free)
