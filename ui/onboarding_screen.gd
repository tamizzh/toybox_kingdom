extends Control

# First-run welcome / how-to flow. A few friendly pages explaining the game, modes,
# and controls. Shown once on first launch (gated by SaveManager.onboarding_done) and
# replayable from the menu's HOW TO PLAY button. Marks onboarding done when finished.

const ILLO_SHOTS := [
	"res://assets/onboarding/p0_kingdom.png",
	"res://assets/screenshots/loop.png",
	"res://assets/screenshots/trail.png",
	"res://assets/screenshots/capture2.png",
	"res://assets/onboarding/p4_victory.png",
]

const PAGES := [
	{
		"title": "RULE YOUR TOY KINGDOM",
		"body": "You are the Crowned Toy King!\nStart with a small castle and grow your kingdom across the toybox.",
	},
	{
		"title": "CLAIM NEW LAND",
		"body": "Use the joystick (or WASD) to move.\nLeave your land to draw a trail — then loop back home.\nEverything you circle becomes YOUR territory!",
	},
	{
		"title": "MIND YOUR TRAIL",
		"body": "While you're out, your trail is exposed.\nIf a rival touches it, you pop and lose your trail!\nCut theirs first — or race home safely.",
	},
	{
		"title": "CONQUER CASTLES",
		"body": "Fully surround a rival's castle with your land to capture it.\nClaim more land to level up your castle — bigger castle beats smaller castle!",
	},
	{
		"title": "RULE THE TOYBOX",
		"body": "Campaign: hold the most land at time-up, or wipe out every rival.\nEndless: chain islands and beat your high score. Good luck, ruler!",
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

	# Game screenshot illustration — real in-game capture per page
	# Image.load_from_file bypasses the .import requirement so raw PNGs work in dev mode
	var illo := TextureRect.new()
	var _img := Image.load_from_file(ILLO_SHOTS[_page])
	if _img:
		illo.texture = ImageTexture.create_from_image(_img)
	illo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illo.size = Vector2(560, 280)
	illo.position = Vector2(Palette.CENTER_X - 280, 96)
	illo.clip_contents = true
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
	body.size = Vector2(900, 120)
	body.position = Vector2(Palette.CENTER_X - 450, 460)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	# Page dots
	var dots := _Dots.new()
	dots.count = PAGES.size()
	dots.current = _page
	dots.size = Vector2(200, 20)
	dots.position = Vector2(Palette.CENTER_X - 100, 590)
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
	next.position = Vector2(Palette.CENTER_X - 150, 620)
	add_child(next)

	# Skip (top-right) — hidden on the last page
	if not last:
		var skip := _btn("SKIP", Palette.NEUTRAL, func() -> void:
			AudioManager.play("tap")
			_finish())
		skip.custom_minimum_size = Vector2(110, 46)
		skip.position = Vector2(Palette.DESIGN_W - 150, 28)
		add_child(skip)

	# "tap anywhere" hint — pulsing below the dots, hidden on last page
	if not last:
		var hint := Label.new()
		hint.text = "tap anywhere to continue"
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size = Vector2(Palette.DESIGN_W, 28)
		hint.position = Vector2(0, 700)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hint)
		var tw := hint.create_tween().set_loops()
		tw.tween_property(hint, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(hint, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	# Tap anywhere (outside the buttons) advances to the next page.
	var is_tap: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch: bool = (event is InputEventScreenTouch and event.pressed)
	if (is_tap or is_touch) and _page < PAGES.size() - 1:
		AudioManager.play("tap")
		_page += 1
		_rebuild()


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
