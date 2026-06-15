extends Control

# First-run welcome / how-to flow. A few friendly pages explaining the game, modes,
# and controls. Shown once on first launch (gated by SaveManager.onboarding_done) and
# replayable from the menu's HOW TO PLAY button. Marks onboarding done when finished.

const PAGES := [
	{
		"title": "WELCOME TO PARTY PALS ARENA",
		"body": "Fast, silly mini-games for 1–4 players.\nWin rounds, score points, race to 5 to win the match!",
	},
	{
		"title": "PLAY YOUR WAY",
		"body": "Pass & play with friends on one device,\nor add CPU opponents and play solo.",
	},
	{
		"title": "SIMPLE CONTROLS",
		"body": "Move with the stick, tap the button to act.\nOn a PC: P1 = WASD + Space, P2 = Arrows + Enter.",
	},
	{
		"title": "EVERY ROUND IS DIFFERENT",
		"body": "Each game shows a quick how-to at the start.\nEarn coins as you play and unlock new looks. Have fun!",
	},
]

var _page: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := _Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		match page:
			0:  # four mascots
				var cols := [Palette.player_color(0), Palette.player_color(1), Palette.player_color(2), Palette.player_color(3)]
				for i in 4:
					var x := cx + (i - 1.5) * 100.0
					_mascot(Vector2(x, cy), 44.0, cols[i])
			1:  # friends cluster vs a CPU
				_mascot(Vector2(cx - 130, cy), 46.0, Palette.player_color(0))
				_mascot(Vector2(cx - 40, cy + 10), 46.0, Palette.player_color(1))
				var f := ArcadeTheme.font
				draw_string(f, Vector2(cx + 18, cy + 14), "vs", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
				_mascot(Vector2(cx + 130, cy), 46.0, Color("8b93a6"))   # grey = CPU
			2:  # joystick + action button
				var jc := Vector2(cx - 90, cy)
				draw_circle(jc, 70.0, Color(1, 1, 1, 0.16))
				draw_arc(jc, 70.0, 0, TAU, 40, Color(1, 1, 1, 0.7), 5.0)
				draw_circle(jc + Vector2(18, -10), 32.0, Color(1, 1, 1, 0.9))
				var bc := Vector2(cx + 110, cy + 10)
				DrawKit.blob(self, bc, 52.0, Palette.SAFE, 5.0)
			3:  # crown over a "5" target
				DrawKit.crown(self, Vector2(cx, cy - 40), 110.0)
				DrawKit.star(self, Vector2(cx - 120, cy + 60), 34.0)
				DrawKit.star(self, Vector2(cx + 120, cy + 60), 34.0)
				var f2 := ArcadeTheme.font
				var s := "5"
				var tw := f2.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
				draw_string(f2, Vector2(cx - tw * 0.5, cy + 80), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Palette.WARN)

	func _mascot(c: Vector2, r: float, col: Color) -> void:
		DrawKit.blob(self, c, r, col, 5.0)
		DrawKit.eyes(self, c + Vector2(0, -r * 0.05), r * 0.7)


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
