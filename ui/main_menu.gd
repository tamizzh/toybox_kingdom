extends Control

var _count: int = 2
var _count_btns: Array = []


func _ready() -> void:
	var bg := _BG.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 44)
	root.add_theme_constant_override("margin_right", 44)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var shell := HBoxContainer.new()
	shell.custom_minimum_size = Vector2(1472, 540)
	shell.add_theme_constant_override("separation", 20)
	center.add_child(shell)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(676, 532)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	shell.add_child(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(676, 532)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	shell.add_child(right)

	_build_left_column(left)
	_build_right_column(right)
	_build_logo_overlay(self)
	_update_visual()


func _build_left_column(parent: VBoxContainer) -> void:
	parent.add_child(_spacer(2))

	var eyebrow := _make_label("LOCAL PARTY MINI-GAMES", 18, Color(Palette.NEUTRAL, 0.95))
	eyebrow.add_theme_font_size_override("font_size", 18)
	parent.add_child(eyebrow)

	parent.add_child(_spacer(126))

	var subtitle := Label.new()
	subtitle.text = "Fast couch-friendly mini-games with a clean arcade feel. Pick your player count, pass the device around, and race to five points."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(636, 52)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(Palette.ACCENT, 0.88))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(subtitle)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 12)
	parent.add_child(chips)
	chips.add_child(_chip("30 mini-games", Palette.PLAYER_COLORS[1]))
	chips.add_child(_chip("1-4 players", Palette.PLAYER_COLORS[2]))
	chips.add_child(_chip("one device", Palette.PLAYER_COLORS[3]))

	parent.add_child(_section_card())


func _section_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(648, 192)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("111724"), Color("3f4d69"), 30, 2, 24))

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)

	var head := Label.new()
	head.text = "SET UP THE MATCH"
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(Palette.NEUTRAL, 0.95))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)

	var copy := VBoxContainer.new()
	copy.custom_minimum_size = Vector2(226, 0)
	copy.add_theme_constant_override("separation", 6)
	row.add_child(copy)

	var title := Label.new()
	title.text = "Number of players"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Palette.ACCENT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title)

	var body := Label.new()
	body.text = "Each player gets a color-coded character, score chip, and control mapping."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(226, 58)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(Palette.NEUTRAL, 0.95))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(body)

	var buttons := HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	row.add_child(buttons)

	for n in [1, 2, 3, 4]:
		var btn := _CountButton.new()
		btn.player_count = n
		btn.custom_minimum_size = Vector2(78, 92)
		btn.pressed.connect(_on_count.bind(n))
		buttons.add_child(btn)
		_count_btns.append(btn)

	var cta_row := HBoxContainer.new()
	cta_row.add_theme_constant_override("separation", 12)
	col.add_child(cta_row)

	var play := _PlayButton.new()
	play.custom_minimum_size = Vector2(248, 56)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play)
	cta_row.add_child(play)

	var hint := Label.new()
	hint.text = "First to 5 points wins"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(Palette.NEUTRAL, 0.95))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_row.add_child(hint)

	return panel


func _build_right_column(parent: VBoxContainer) -> void:
	var hero_panel := PanelContainer.new()
	hero_panel.custom_minimum_size = Vector2(676, 532)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_panel.add_theme_stylebox_override("panel", _panel_style(Color("0f1520"), Color("33415b"), 34, 2, 28))
	parent.add_child(hero_panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	hero_panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	pad.add_child(col)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	col.add_child(top_row)

	top_row.add_child(_chip("clean arcade", Palette.PLAYER_COLORS[0]))
	top_row.add_child(_chip("instant rounds", Palette.PLAYER_COLORS[1]))

	var hero_card := _HeroArtPanel.new()
	hero_card.custom_minimum_size = Vector2(640, 284)
	hero_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(hero_card)

	var hero_tex := AssetKit.menu_hero()
	if hero_tex:
		var hero := TextureRect.new()
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.anchor_left = 0.0
		hero.anchor_top = 0.0
		hero.anchor_right = 1.0
		hero.anchor_bottom = 1.0
		hero.offset_left = 38
		hero.offset_top = 20
		hero.offset_right = -38
		hero.offset_bottom = -20
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_card.add_child(hero)

	var blurb := Label.new()
	blurb.text = "Browse categories, jump into a random challenge, and keep the pace moving with short, readable rounds."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(632, 34)
	blurb.add_theme_font_size_override("font_size", 16)
	blurb.add_theme_color_override("font_color", Color(Palette.ACCENT, 0.82))
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(blurb)

	var categories := GridContainer.new()
	categories.columns = 3
	categories.add_theme_constant_override("h_separation", 8)
	categories.add_theme_constant_override("v_separation", 8)
	col.add_child(categories)

	for cat in ["Racing", "Combat", "Growth", "Sports", "Reaction", "Platform"]:
		categories.add_child(_category_pill(cat))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _title_lockup() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(640, 190)
	wrap.add_theme_constant_override("separation", -4)

	var party := Label.new()
	party.text = "PARTY PALS"
	party.add_theme_font_size_override("font_size", 76)
	party.add_theme_color_override("font_color", Color.WHITE)
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(party)

	var arena := Label.new()
	arena.text = "ARENA"
	arena.add_theme_font_size_override("font_size", 76)
	arena.add_theme_color_override("font_color", Palette.PLAYER_COLORS[3])
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(arena)

	return wrap


func _build_logo_overlay(parent: Control) -> void:
	var logo_tex := AssetKit.menu_logo()
	if logo_tex == null:
		logo_tex = AssetKit.logo()

	if logo_tex == null:
		var fallback := _title_lockup()
		fallback.position = Vector2(92, 54)
		fallback.z_index = 10
		parent.add_child(fallback)
		return

	var logo := TextureRect.new()
	logo.texture = logo_tex
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(8, 28)
	logo.size = Vector2(738, 270)
	logo.z_index = 10
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(logo)


func _chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 34)
	chip.add_theme_stylebox_override("panel", _panel_style(Color(color, 0.14), Color(color, 0.45), 18, 1, 12))

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 34)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip


func _category_pill(cat: String) -> PanelContainer:
	var color := Palette.category_color(cat)
	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(0, 40)
	pill.add_theme_stylebox_override("panel", _panel_style(Color(color, 0.16), Color(color, 0.42), 20, 1, 12))

	var label := Label.new()
	label.text = cat
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	return pill


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _panel_style(bg: Color, border: Color, radius: int, border_width: int, padding: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_width
	s.border_width_right = border_width
	s.border_width_top = border_width
	s.border_width_bottom = border_width
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s


func _on_count(c: int) -> void:
	_count = c
	_update_visual()


func _update_visual() -> void:
	for btn in _count_btns:
		btn.selected = btn.player_count == _count
		btn.queue_redraw()


func _on_play() -> void:
	GameManager.setup_match(_count)
	GameManager.start_match()


class _BG extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("111722"))
		draw_circle(Vector2(w * 0.16, h * 0.18), 180.0, Color(Palette.PLAYER_COLORS[1], 0.08))
		draw_circle(Vector2(w * 0.82, h * 0.22), 220.0, Color(Palette.PLAYER_COLORS[0], 0.08))
		draw_circle(Vector2(w * 0.74, h * 0.78), 260.0, Color(Palette.PLAYER_COLORS[2], 0.05))
		draw_rect(Rect2(0, h * 0.58, w, h * 0.42), Color(0, 0, 0, 0.12))

		var step := 40.0
		var dot_color := Color(Palette.WALL, 0.12)
		for col in int(w / step) + 2:
			for row in int(h / step) + 2:
				draw_circle(Vector2(col * step + 8, row * step + 8), 1.3, dot_color)

		for i in 5:
			var y := 70.0 + i * 122.0
			draw_line(Vector2(48, y), Vector2(w - 48, y), Color(Palette.WALL, 0.05), 1.0)


class _CountButton extends Button:
	var player_count: int = 2
	var selected: bool = false

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var fill := Color("182131") if selected else Color("101722")
		var border := Palette.player_color(max(0, player_count - 1)) if selected else Color("344055")
		DrawKit.card(self, rect, 26.0, fill, 3.0, true)
		draw_rect(Rect2(4, 4, size.x - 8, 6), Color(border, 0.95))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(size.x * 0.5 - 14, 30),
			"%dP" % player_count,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color.WHITE
		)

		var r := 7.0
		var gap := 8.0
		var total := player_count * r * 2.0 + (player_count - 1) * gap
		var sx := (size.x - total) * 0.5 + r
		var y := 68.0
		for i in player_count:
			var col := Palette.player_color(i)
			var x := sx + i * (r * 2.0 + gap)
			draw_circle(Vector2(x, y), r + 2.5, Color.BLACK)
			draw_circle(Vector2(x, y), r, col)


class _PlayButton extends Button:
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 26.0, Palette.PLAYER_COLORS[1], 3.0, true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(24, size.y * 0.5 + 10),
			"START MATCH",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			26,
			Color.WHITE
		)
		var cx := size.x - 28.0
		var cy := size.y * 0.5
		var pts := PackedVector2Array([
			Vector2(cx - 14, cy - 14),
			Vector2(cx + 6, cy),
			Vector2(cx - 14, cy + 14),
		])
		draw_polygon(pts, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]))


class _HeroArtPanel extends Control:
	func _draw() -> void:
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 34.0, Color("f7f4ee"), 4.0, true)
		draw_circle(Vector2(size.x * 0.82, size.y * 0.18), 46.0, Color(Palette.PLAYER_COLORS[1], 0.10))
		draw_circle(Vector2(size.x * 0.18, size.y * 0.78), 58.0, Color(Palette.PLAYER_COLORS[3], 0.11))
		draw_circle(Vector2(size.x * 0.12, size.y * 0.20), 28.0, Color(Palette.PLAYER_COLORS[0], 0.14))
		draw_circle(Vector2(size.x * 0.74, size.y * 0.80), 22.0, Color(Palette.PLAYER_COLORS[2], 0.16))
