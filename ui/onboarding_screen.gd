extends Control

# First-run welcome / how-to flow. A few friendly pages explaining the game, modes,
# and controls. Shown once on first launch (gated by SaveManager.onboarding_done) and
# replayable from the menu's HOW TO PLAY button. Marks onboarding done when finished.

const PAGES := [
	{
		"title": "RULE YOUR TOY KINGDOM",
		"body": "Start with a tiny castle and a patch of land.\nGrow it into the biggest kingdom in the toybox!",
	},
	{
		"title": "CLAIM NEW LAND",
		"body": "Leave your land to draw a trail, then loop back home.\nEverything you circle becomes your territory!",
	},
	{
		"title": "MIND YOUR TRAIL",
		"body": "Out in the open your trail is exposed.\nIf a rival crosses it you pop — so cut theirs first!",
	},
	{
		"title": "CONQUER CASTLES",
		"body": "Reach a rival's castle to take their whole kingdom —\nif your castle is the same level or higher.",
	},
	{
		"title": "RULE THE TOYBOX",
		"body": "Conquer every rival kingdom — or hold 50% of the map when time runs out.\nGood luck, ruler!",
	},
]

var _page: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # force full-viewport size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100   # cover the menu chrome (its buttons/chip use z_index=12)
	var bg := _Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		if c is _Backdrop:
			continue
		c.queue_free()

	var p: Dictionary = PAGES[_page]

	# Illustration
	var illo := _Illo.new()
	illo.page = _page
	illo.size = Vector2(420, 280)
	illo.position = Vector2(Palette.CENTER_X - 210, 96)
	illo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(illo)

	# Title
	var title := Label.new()
	title.text = p.title
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(Palette.DESIGN_W, 60)
	title.position = Vector2(0, 396)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Body
	var body := Label.new()
	body.text = p.body
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size = Vector2(900, 90)
	body.position = Vector2(Palette.CENTER_X - 450, 466)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	# Page dots
	var dots := _Dots.new()
	dots.count = PAGES.size()
	dots.current = _page
	dots.size = Vector2(200, 20)
	dots.position = Vector2(Palette.CENTER_X - 100, 576)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots)

	# Next / Let's Play
	var last := _page == PAGES.size() - 1
	var next := _btn("LET'S PLAY" if last else "NEXT", Palette.SAFE, func() -> void:
		AudioManager.play("tap")
		if last:
			_finish()
		else:
			_page += 1
			_rebuild())
	next.custom_minimum_size = Vector2(300, 70)
	next.position = Vector2(Palette.CENTER_X - 150, 612)
	add_child(next)

	# Skip (top-right) — hidden on the last page
	if not last:
		var skip := _btn("SKIP", Palette.NEUTRAL, func() -> void:
			AudioManager.play("tap")
			_finish())
		skip.custom_minimum_size = Vector2(110, 46)
		skip.position = Vector2(Palette.DESIGN_W - 150, 28)
		add_child(skip)


func _finish() -> void:
	SaveManager.set_onboarding_done(true)
	queue_free()


func _btn(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color.WHITE)
	var alphas := {"normal": 0.85, "hover": 1.0, "pressed": 0.7}
	for state in ["normal", "hover", "pressed"]:
		var a: float = alphas[state]
		var s := StyleBoxFlat.new()
		s.bg_color = Color(color, a)
		s.set_corner_radius_all(20)
		s.content_margin_left = 16; s.content_margin_right = 16
		s.content_margin_top = 8; s.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(cb)
	return b


# ── drawn pieces ─────────────────────────────────────────────────────────────────
class _Backdrop extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("181434"))
		draw_rect(Rect2(0, 0, w, h * 0.5), Color("241c4e"))
		draw_circle(Vector2(w * 0.18, h * 0.22), 220.0, Color(Palette.PLAYER_COLORS[1], 0.12))
		draw_circle(Vector2(w * 0.82, h * 0.20), 240.0, Color(Palette.PLAYER_COLORS[0], 0.10))
		draw_circle(Vector2(w * 0.80, h * 0.82), 260.0, Color(Palette.PLAYER_COLORS[2], 0.10))


class _Illo extends Control:
	var page: int = 0
	const BLUE := Color("2f7ae0")
	const RED := Color("e0463a")

	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		match page:
			0:  # your kingdom: a patch of land + castle + blob
				_land(Vector2(cx, cy + 20), 230, 130, BLUE)
				_castle(Vector2(cx - 30, cy), 1.0, BLUE)
				_mascot(Vector2(cx + 70, cy + 30), 30.0, BLUE)
			1:  # claim: home + a trail loop back, enclosed area filled
				_land(Vector2(cx - 110, cy + 30), 90, 110, BLUE)
				_dash_rect(Rect2(cx - 110, cy - 70, 200, 150), BLUE)
				_land(Vector2(cx + 10, cy - 20), 150, 90, Color(BLUE, 0.35))   # claimed area
				_mascot(Vector2(cx - 110, cy - 70), 22.0, BLUE)
				_arrow(Vector2(cx + 70, cy + 70), Vector2(cx - 70, cy + 70), Color.WHITE)
			2:  # mind your trail: rival cutting your exposed trail
				_dash_line(Vector2(cx - 150, cy + 30), Vector2(cx + 40, cy + 30), BLUE)
				_mascot(Vector2(cx - 150, cy + 30), 24.0, BLUE)
				_mascot(Vector2(cx + 30, cy - 30), 26.0, RED)
				# the X where the rival cuts the trail
				var p := Vector2(cx + 5, cy + 5)
				draw_line(p + Vector2(-16, -16), p + Vector2(16, 16), Color.WHITE, 5.0)
				draw_line(p + Vector2(16, -16), p + Vector2(-16, 16), Color.WHITE, 5.0)
			3:  # conquer castles: rival castle -> captured (colour flip)
				_castle(Vector2(cx - 110, cy), 0.95, RED)
				_arrow(Vector2(cx - 50, cy), Vector2(cx + 40, cy), Color.WHITE)
				_castle(Vector2(cx + 110, cy), 0.95, BLUE)
				draw_string(ArcadeTheme.font, Vector2(cx + 70, cy - 70),
					"Lv ≥", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.WARN)
			4:  # rule the toybox: crown + 50%
				DrawKit.crown(self, Vector2(cx, cy - 30), 110.0)
				DrawKit.star(self, Vector2(cx - 120, cy + 55), 30.0)
				DrawKit.star(self, Vector2(cx + 120, cy + 55), 30.0)
				var s := "50%"
				var tw := ArcadeTheme.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
				draw_string(ArcadeTheme.font, Vector2(cx - tw * 0.5, cy + 90), s,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Palette.WARN)

	func _mascot(c: Vector2, r: float, col: Color) -> void:
		DrawKit.blob(self, c, r, col, 5.0)
		DrawKit.eyes(self, c + Vector2(0, -r * 0.05), r * 0.7)

	func _land(c: Vector2, w: float, h: float, col: Color) -> void:
		var r := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
		draw_rect(r, col)
		draw_rect(r, col.darkened(0.35), false, 4.0)

	func _castle(c: Vector2, s: float, roof: Color) -> void:
		var stone := Color("d8cdb5")
		draw_rect(Rect2(c.x - 22 * s, c.y - 8 * s, 44 * s, 32 * s), stone)        # keep body
		for sx in [-1.0, 1.0]:
			draw_rect(Rect2(c.x + sx * 26 * s - 7 * s, c.y - 16 * s, 14 * s, 40 * s), stone)  # towers
			_roof(Vector2(c.x + sx * 26 * s, c.y - 16 * s), 9 * s, roof)
		_roof(Vector2(c.x, c.y - 8 * s), 24 * s, roof)                            # keep roof

	func _roof(base_c: Vector2, w: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			base_c + Vector2(-w, 0), base_c + Vector2(w, 0), base_c + Vector2(0, -w * 1.4)]),
			col)

	func _dash_rect(r: Rect2, col: Color) -> void:
		_dash_line(r.position, r.position + Vector2(r.size.x, 0), col)
		_dash_line(r.position + Vector2(r.size.x, 0), r.position + r.size, col)
		_dash_line(r.position + r.size, r.position + Vector2(0, r.size.y), col)
		_dash_line(r.position + Vector2(0, r.size.y), r.position, col)

	func _dash_line(a: Vector2, b: Vector2, col: Color) -> void:
		var n := int(a.distance_to(b) / 14.0)
		for i in n:
			if i % 2 == 0:
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, 5.0)

	func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
		draw_line(a, b, col, 4.0)
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x) * 8.0
		draw_colored_polygon(PackedVector2Array([b, b - d * 16.0 + n, b - d * 16.0 - n]), col)


class _Dots extends Control:
	var count: int = 4
	var current: int = 0
	func _draw() -> void:
		var gap := 26.0
		var total := (count - 1) * gap
		var sx := size.x * 0.5 - total * 0.5
		for i in count:
			var c := Color.WHITE if i == current else Color(1, 1, 1, 0.3)
			draw_circle(Vector2(sx + i * gap, size.y * 0.5), 7.0 if i == current else 5.0, c)
