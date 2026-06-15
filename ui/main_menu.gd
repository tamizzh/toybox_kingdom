extends Control

# Bold, playful front screen: a big centred logo, a row of bobbing mascots, a
# player-count selector and one dominant PLAY button over a bright toy-box
# background. SHOP / SETTINGS sit quietly in the top-right corner.

const MascotFace := preload("res://ui/mascot_face.gd")

var _humans: int = 2
var _cpus: int = 0
var _difficulty: int = 1
var _human_btns: Array = []
var _cpu_btns: Array = []
var _diff_btn: _DiffButton
var _coin_label: Label
var _hook_label: Label


func _ready() -> void:
	var bg := _BG.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_top_buttons()
	_build_currency_chip()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(820, 0)
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	col.add_child(_logo_node())
	col.add_child(_mascot_row())
	col.add_child(_human_row())
	col.add_child(_cpu_row())
	col.add_child(_play_row())

	_update_visual()


# ── Top-right SHOP / SETTINGS ──────────────────────────────────────────────────
func _build_top_buttons() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.position = Vector2(Palette.DESIGN_W - 500, 22)
	bar.z_index = 12
	add_child(bar)
	bar.add_child(_menu_btn("HOW TO PLAY", Palette.PLAYER_COLORS[1], func() -> void:
		AudioManager.play("tap")
		add_child(load("res://ui/onboarding_screen.gd").new()), 176))
	bar.add_child(_menu_btn("SHOP", Palette.WARN, func() -> void:
		AudioManager.play("tap")
		add_child(load("res://ui/shop_screen.gd").new())))
	bar.add_child(_menu_btn("SETTINGS", Palette.NEUTRAL, func() -> void:
		AudioManager.play("tap")
		add_child(load("res://ui/settings_screen.gd").new())))


# ── Top-left coins / level chip (opens the profile/stats panel) ───────────────────
func _build_currency_chip() -> void:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2(24, 22)
	btn.custom_minimum_size = Vector2(232, 46)
	btn.size = Vector2(232, 46)
	btn.z_index = 12
	btn.add_theme_stylebox_override("normal", _panel_style(Color(0, 0, 0, 0.30), Color(Palette.WARN, 0.6), 16, 2, 12))
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0, 0, 0, 0.42), Palette.WARN, 16, 2, 12))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0, 0, 0, 0.52), Palette.WARN, 16, 2, 12))
	add_child(btn)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color.WHITE)
	_coin_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(_coin_label)
	_refresh_currency()

	SaveManager.coins_changed.connect(_on_coins_changed)
	btn.pressed.connect(func() -> void:
		AudioManager.play("tap")
		add_child(load("res://ui/profile_screen.gd").new()))


func _on_coins_changed(_total: int) -> void:
	_refresh_currency()
	_refresh_hook()


func _refresh_currency() -> void:
	if _coin_label:
		_coin_label.text = "LV %d     %d COINS" % [SaveManager.level(), SaveManager.coins()]


func _menu_btn(text: String, color: Color, cb: Callable, width: int = 140) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _panel_style(Color(color, 0.20), color, 16, 2, 14))
	b.add_theme_stylebox_override("hover", _panel_style(Color(color, 0.40), color, 16, 2, 14))
	b.add_theme_stylebox_override("pressed", _panel_style(Color(color, 0.55), color, 16, 2, 14))
	b.custom_minimum_size = Vector2(width, 46)
	b.pressed.connect(cb)
	return b


# ── Logo ───────────────────────────────────────────────────────────────────────
func _logo_node() -> Control:
	var logo_tex := AssetKit.menu_logo()
	if logo_tex == null:
		logo_tex = AssetKit.logo()

	if logo_tex == null:
		var fallback := _title_lockup()
		fallback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return fallback

	var logo := TextureRect.new()
	logo.texture = logo_tex
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(620, 200)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return logo


func _title_lockup() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", -8)

	var party := Label.new()
	party.text = "PARTY PALS"
	party.add_theme_font_size_override("font_size", 84)
	party.add_theme_color_override("font_color", Color.WHITE)
	party.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(party)

	var arena := Label.new()
	arena.text = "ARENA"
	arena.add_theme_font_size_override("font_size", 84)
	arena.add_theme_color_override("font_color", Palette.PLAYER_COLORS[3])
	arena.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(arena)

	return wrap


# ── Mascot character row ─────────────────────────────────────────────────────────
func _mascot_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.size_flags_horizontal = Control.SIZE_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		row.add_child(_mascot(i))
	return row


func _mascot(i: int) -> Control:
	var bob := _Bobber.new()
	bob.custom_minimum_size = Vector2(110, 110)
	bob.phase = float(i) * 0.7
	bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := MascotFace.new()
	face.set_color(Palette.player_color(i))
	face.size = Vector2(96, 96)
	face.position = Vector2(7, 7)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bob.add_child(face)
	bob.face = face
	return bob


# ── Players / CPU / difficulty selectors ─────────────────────────────────────────
func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(132, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(Palette.ACCENT, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _selector_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_FILL
	return row


func _human_row() -> Control:
	var row := _selector_row()
	row.add_child(_row_label("PLAYERS"))
	for n in [1, 2, 3, 4]:
		var btn := _CountButton.new()
		btn.value = n
		btn.show_dots = true
		btn.accent = Palette.player_color(n - 1)
		btn.custom_minimum_size = Vector2(78, 92)
		btn.pressed.connect(_on_humans.bind(n))
		row.add_child(btn)
		_human_btns.append(btn)
	return row


func _cpu_row() -> Control:
	var row := _selector_row()
	row.add_child(_row_label("CPUs"))
	for n in [0, 1, 2, 3]:
		var btn := _CountButton.new()
		btn.value = n
		btn.show_dots = false
		btn.accent = Color("aa60ff")
		btn.custom_minimum_size = Vector2(78, 92)
		btn.pressed.connect(_on_cpus.bind(n))
		row.add_child(btn)
		_cpu_btns.append(btn)
	_diff_btn = _DiffButton.new()
	_diff_btn.custom_minimum_size = Vector2(150, 92)
	_diff_btn.pressed.connect(_on_diff)
	row.add_child(_diff_btn)
	return row


# ── PLAY ─────────────────────────────────────────────────────────────────────────
func _play_row() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	wrap.size_flags_horizontal = Control.SIZE_FILL

	var play := _PlayButton.new()
	play.custom_minimum_size = Vector2(380, 100)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play)
	wrap.add_child(play)

	var hint := Label.new()
	hint.text = "First to 5 points wins"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(Palette.NEUTRAL, 0.9))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_FILL
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hint)

	_hook_label = Label.new()
	_hook_label.add_theme_font_size_override("font_size", 18)
	_hook_label.add_theme_color_override("font_color", Color(Palette.WARN, 0.96))
	_hook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hook_label.size_flags_horizontal = Control.SIZE_FILL
	_hook_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_hook_label)
	return wrap


# ── Helpers ───────────────────────────────────────────────────────────────────────
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


func _on_humans(n: int) -> void:
	AudioManager.play("tap", randf_range(0.96, 1.06))
	_humans = n
	_cpus = clampi(_cpus, 0, 4 - _humans)
	_update_visual()


func _on_cpus(n: int) -> void:
	if n > 4 - _humans:
		return
	AudioManager.play("tap", randf_range(0.96, 1.06))
	_cpus = n
	_update_visual()


func _on_diff() -> void:
	AudioManager.play("tap", randf_range(0.96, 1.06))
	_difficulty = (_difficulty + 1) % 3
	_update_visual()


func _update_visual() -> void:
	for btn in _human_btns:
		btn.selected = btn.value == _humans
		btn.queue_redraw()
	for btn in _cpu_btns:
		btn.usable = btn.value <= 4 - _humans
		btn.selected = btn.value == _cpus
		btn.queue_redraw()
	if _diff_btn:
		_diff_btn.level = _difficulty
		_diff_btn.usable = _cpus > 0
		_diff_btn.queue_redraw()
	_refresh_hook()

func _refresh_hook() -> void:
	if not _hook_label:
		return
	var next_pack := SaveManager.next_unlock_pack_id()
	if next_pack != "":
		var remaining := SaveManager.next_unlock_pack_remaining()
		_hook_label.text = "%d more coins unlock %s colors" % [remaining, Cosmetics.name_of(next_pack)]
		return
	var progress := int(round(SaveManager.level_progress() * 100.0))
	if _cpus > 0:
		_hook_label.text = "Winner bonus: +%d coins   Level %d %d%%" % [GameManager.MATCH_COINS, SaveManager.level(), progress]
	else:
		_hook_label.text = "Quick rematches build XP fast   Level %d %d%%" % [SaveManager.level(), progress]


func _on_play() -> void:
	AudioManager.play("tap")
	GameManager.setup_match(_humans, _cpus, _difficulty)
	GameManager.start_match()


# ── Mascot idle bob ────────────────────────────────────────────────────────────────
class _Bobber extends Control:
	var face: Control
	var phase: float = 0.0
	var _t: float = 0.0
	func _process(delta: float) -> void:
		_t += delta
		if face:
			face.position.y = 8.0 + sin(_t * 2.2 + phase) * 5.0


# ── Bright toy-box background ────────────────────────────────────────────────────
class _BG extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Vertical-ish wash: deep indigo base with playful colour blobs.
		draw_rect(Rect2(Vector2.ZERO, size), Color("221a45"))
		draw_rect(Rect2(0, 0, w, h * 0.5), Color("2c2358"))
		draw_circle(Vector2(w * 0.16, h * 0.20), 200.0, Color(Palette.PLAYER_COLORS[1], 0.16))
		draw_circle(Vector2(w * 0.84, h * 0.18), 240.0, Color(Palette.PLAYER_COLORS[0], 0.14))
		draw_circle(Vector2(w * 0.78, h * 0.82), 280.0, Color(Palette.PLAYER_COLORS[2], 0.12))
		draw_circle(Vector2(w * 0.20, h * 0.80), 230.0, Color(Palette.PLAYER_COLORS[3], 0.12))
		draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color(0, 0, 0, 0.10))

		var step := 44.0
		var dot_color := Color(Palette.ACCENT, 0.05)
		for ccol in int(w / step) + 2:
			for crow in int(h / step) + 2:
				draw_circle(Vector2(ccol * step + 8, crow * step + 8), 1.4, dot_color)


class _CountButton extends Button:
	var value: int = 1
	var accent: Color = Color.WHITE
	var show_dots: bool = false
	var selected: bool = false
	var usable: bool = true

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var fill := Color("141c2c")
		if usable:
			fill = Color("2a3a5e") if selected else Color("1b2740")
		DrawKit.card(self, rect, 20.0, fill, 3.0, true)
		if selected and usable:
			draw_rect(Rect2(5, 5, size.x - 10, 6), Color(accent, 0.95))
		var txt_col := Color.WHITE if usable else Color(1, 1, 1, 0.28)
		var s := str(value)
		var tw := ArcadeTheme.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var ty := 34.0 if show_dots else size.y * 0.5 + 10.0
		draw_string(ArcadeTheme.font, Vector2((size.x - tw) * 0.5, ty), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, txt_col)

		if show_dots:
			var r := 6.0
			var gap := 7.0
			var total := value * r * 2.0 + (value - 1) * gap
			var sx := (size.x - total) * 0.5 + r
			var y := 70.0
			for i in value:
				var x := sx + i * (r * 2.0 + gap)
				draw_circle(Vector2(x, y), r + 2.0, Color.BLACK)
				draw_circle(Vector2(x, y), r, Palette.player_color(i))


class _DiffButton extends Button:
	const NAMES := ["EASY", "NORMAL", "HARD"]
	const COLS := [Color("10b83c"), Color("f5c018"), Color("f02828")]
	var level: int = 1
	var usable: bool = true

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		var fill := Color("1b2740") if usable else Color("141c2c")
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 20.0, fill, 3.0, true)
		var c: Color = COLS[level]
		draw_rect(Rect2(5, 5, size.x - 10, 6), Color(c, 0.95 if usable else 0.3))
		var txt_col := Color.WHITE if usable else Color(1, 1, 1, 0.3)
		var cap := "DIFFICULTY"
		var ctw := ArcadeTheme.font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(ArcadeTheme.font, Vector2((size.x - ctw) * 0.5, 34), cap,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(txt_col, 0.7))
		var s: String = NAMES[level]
		var tw := ArcadeTheme.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(ArcadeTheme.font, Vector2((size.x - tw) * 0.5, 64), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, txt_col)


class _PlayButton extends Button:
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 30.0, Palette.SAFE, 4.0, true)
		var fsize := 38
		var label := "PLAY"
		var tw := ArcadeTheme.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var cx := size.x * 0.5
		# play glyph (triangle) sits to the left of the centred word
		var gx := cx - tw * 0.5 - 34.0
		var gy := size.y * 0.5
		draw_polygon(
			PackedVector2Array([
				Vector2(gx - 4, gy - 18), Vector2(gx + 22, gy), Vector2(gx - 4, gy + 18),
			]),
			PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
		)
		draw_string(
			ArcadeTheme.font,
			Vector2(cx - tw * 0.5 + 6, size.y * 0.5 + fsize * 0.36),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE
		)
