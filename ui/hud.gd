extends Control

# In-game HUD: score chips at top corners, timer at top-centre, game title below.
# Matches the toy-box reference style (race_target / snake_target).

const CHIP_W := 258.0
const CHIP_H := 104.0

var _time_label: Label
var _timer_node: _TimerPill   # drawn widget that shows clock icon + number
var _arched_title: _ArchedTitle
var _subtitle_label: Label
var _chips      := {}   # player_id -> Label (score number)
var _chip_roots := {}   # player_id -> Panel
var _last_scores := {}  # player_id -> int, to detect score changes for the pop

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_timer()
	_build_title()
	ScoreManager.scores_updated.connect(_refresh)

# ── Timer pill ────────────────────────────────────────────────────────────────
func _build_timer() -> void:
	_timer_node = _TimerPill.new()
	_timer_node.position = Vector2(Palette.CENTER_X - 104, 10)
	_timer_node.size     = Vector2(208, 82)
	_timer_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_node)
	# Keep _time_label as a no-op dummy so set_time() callers don't crash
	_time_label = Label.new()
	_time_label.visible = false
	add_child(_time_label)

# ── Game title banner (title + subtitle), like the reference art ────────────────
func _build_title() -> void:
	var bw := 700.0
	var bx := Palette.CENTER_X - bw * 0.5

	_arched_title = _ArchedTitle.new()
	_arched_title.font_size = 62
	_arched_title.position = Vector2(bx, 92)
	_arched_title.size = Vector2(bw, 72)
	_arched_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arched_title)

	var sub_w := 382.0
	var sub := _pill(Rect2(Palette.CENTER_X - sub_w * 0.5, 162, sub_w, 36),
		Color("0f5da8"), 16)
	add_child(sub)
	_subtitle_label = _label("", 22, Vector2(10, 2), Vector2(sub_w - 20, 30), sub)
	_subtitle_label.add_theme_color_override("font_color", Color.WHITE)
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.40))
	_subtitle_label.add_theme_constant_override("outline_size", 4)

func _build_title_old() -> void:
	var bw := 660.0
	var bx := Palette.CENTER_X - bw * 0.5
	# Banner backdrop — dark translucent pill with a thin warm underline accent.
	var banner := _pill(Rect2(bx, 84, bw, 92), Color(0.07, 0.10, 0.20, 0.80), 22)
	add_child(banner)
	var accent := _pill(Rect2(bx + bw * 0.30, 166, bw * 0.40, 5),
						Color(Palette.WARN, 0.85), 3)
	add_child(accent)

	# Title — arched, thick-outlined glyphs drawn along a shallow curve.
	_arched_title = _ArchedTitle.new()
	_arched_title.font_size = 56
	_arched_title.position = Vector2(bx, 80)
	_arched_title.size     = Vector2(bw, 60)
	_arched_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arched_title)

	# Subtitle — smaller, warm, sits under the title
	_subtitle_label = _label("", 20, Vector2(bx, 132), Vector2(bw, 28), self)
	_subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))

# ── Score chips ───────────────────────────────────────────────────────────────
func setup(players: Array) -> void:
	for id in _chip_roots:
		if is_instance_valid(_chip_roots[id]):
			_chip_roots[id].queue_free()
	_chip_roots.clear()
	_chips.clear()

	var n  := players.size()
	var w  := Palette.DESIGN_W
	var h  := Palette.DESIGN_H

	for i in n:
		var p: PlayerData = players[i]
		var pos := _chip_pos(i, n, w, h)
		_make_chip(p, pos, pos.x > w * 0.5)

	_refresh()

func _chip_pos(i: int, n: int, w: float, h: float) -> Vector2:
	if n <= 2:
		# Two chips at top corners
		return [
			Vector2(22, 24),
			Vector2(w - CHIP_W - 22, 24),
		][i]
	else:
		# Four chips spread across the top
		var total := n * CHIP_W + (n - 1) * 8.0
		var start  := (w - total) * 0.5
		return Vector2(start + i * (CHIP_W + 8.0), 10)

func _make_chip(p: PlayerData, pos: Vector2, mirror: bool) -> void:
	# Outer pill — outer edge carries a big mascot face that pops out slightly.
	var outer := _pill(Rect2(pos, Vector2(CHIP_W, CHIP_H)),
					   Color(p.color.darkened(0.26), 0.96), 38)
	outer.clip_contents = false
	add_child(outer)
	_chip_roots[p.id] = outer

	# Cute mascot face on the outer side (overhangs the pill edge a touch)
	var fsz := 104.0
	var fy  := (CHIP_H - fsz) * 0.5
	var fx: float = (CHIP_W - fsz + 8.0) if mirror else 0.0
	var face := MascotFace.new()
	face.set_color(p.color)
	face.position = Vector2(fx, fy)
	face.size     = Vector2(fsz, fsz)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(face)

	# Text block (P# label + big score) on the inner side of the face
	var tx: float = 18.0 if mirror else 108.0
	var tw: float = CHIP_W - 124.0
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT

	var name_l := _label(p.display_name, 24, Vector2(tx, 4), Vector2(tw, 28), outer)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.add_theme_color_override("font_outline_color", p.color.darkened(0.55))
	name_l.add_theme_constant_override("outline_size", 5)
	name_l.horizontal_alignment = align

	var score_l := _label(str(p.score), 64, Vector2(tx, 30), Vector2(tw, 68), outer)
	score_l.add_theme_color_override("font_color", Color.WHITE)
	score_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.22))
	score_l.add_theme_constant_override("outline_size", 5)
	score_l.horizontal_alignment = align
	score_l.pivot_offset = Vector2(tw * 0.5, 34)
	_chips[p.id] = score_l
	_last_scores[p.id] = p.score

# ── Updates ───────────────────────────────────────────────────────────────────
func _refresh() -> void:
	for p in ScoreManager.players:
		if _chips.has(p.id):
			var lbl: Label = _chips[p.id]
			lbl.text = str(p.score)
			if _last_scores.get(p.id, p.score) != p.score:
				_pop(lbl)
			_last_scores[p.id] = p.score

# Quick scale-bounce so scoring reads as a satisfying punch.
func _pop(lbl: Label) -> void:
	lbl.scale = Vector2(1.45, 1.45)
	var tw := lbl.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.28)

func set_time(t: float) -> void:
	if _timer_node:
		_timer_node.set_time(t)
	if _time_label:
		_time_label.text = "%d" % int(ceil(t))

func set_status(text: String) -> void:
	if _arched_title:
		_arched_title.set_text(text.to_upper())

func set_subtitle(text: String) -> void:
	if _subtitle_label:
		_subtitle_label.text = text

func flash_round_result(_results: Dictionary) -> void:
	pass  # main.gd _show_winner_overlay handles the visual flash

# ── Helpers ───────────────────────────────────────────────────────────────────
func _pill(rect: Rect2, color: Color, radius: int) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(color.lightened(0.34), 0.95)
	s.set_border_width_all(3)
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	p.add_theme_stylebox_override("panel", s)
	p.position = rect.position
	p.size     = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _label(text: String, font_size: int, pos: Vector2, sz: Vector2,
			parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size     = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ── Drawn timer pill: clock icon on the left, bold countdown number on the right ──
class _TimerPill extends Control:
	var _seconds: int = 45
	var _warn: bool = false   # turns red when ≤5 s

	func set_time(t: float) -> void:
		var s := int(ceil(t))
		var w := s <= 5
		if s != _seconds or w != _warn:
			_seconds = s
			_warn = w
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var fill := Color("c0392b") if _warn else Color("242947")
		var num_col := Color("ff6b6b") if _warn else Color.WHITE

		# Pill background with outline
		DrawKit.card(self, Rect2(Vector2(18, 5), Vector2(w - 24, h - 10)), (h - 10) * 0.45, fill, 4.0, true)

		# Clock icon (left side)
		DrawKit.clock(self, Vector2(46, h * 0.5), h * 0.36, Color("fff8f0"), 4.0)
		draw_arc(Vector2(46, h * 0.5), h * 0.42, 0, TAU, 64, Color("ffbd4a"), 7.0)

		# Number (right side)
		var font: Font = ArcadeTheme.font if ArcadeTheme.font else ThemeDB.fallback_font
		var fs := 56
		var txt := str(_seconds)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := 108 + (w - 120 - tw) * 0.5
		var ty := h * 0.5 + fs * 0.36
		# shadow
		draw_string(font, Vector2(tx + 2, ty + 2), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45))
		# number
		draw_string(font, Vector2(tx, ty), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, num_col)


# ── Arched title: glyphs laid along a shallow upward curve with a thick outline ──
class _ArchedTitle extends Control:
	var _text := ""
	var font_size := 46
	var arc := 16.0                      # px the ends drop below the centre
	var fill := Color("fffdf5")          # white face with warm edge, like target.png
	var outline := Color("5a2e00")       # dark brown outline
	var outline_w := 4

	func set_text(t: String) -> void:
		if t != _text:
			_text = t
			queue_redraw()

	func _draw() -> void:
		if _text == "":
			return
		var font: Font = ArcadeTheme.font if ArcadeTheme.font else ThemeDB.fallback_font
		var total := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := (size.x - total) * 0.5
		var cy := size.y * 0.5 + font_size * 0.35
		for i in _text.length():
			var cp := _text.unicode_at(i)
			var w := font.get_char_size(cp, font_size).x
			var t := (x + w * 0.5) / size.x          # 0..1 across the width
			var lift := arc * pow(2.0 * t - 1.0, 2.0)  # parabola: ends sit lower
			var pos := Vector2(x, cy + lift)
			# thick outline via 8-way offset draw
			for dx in [-outline_w, 0, outline_w]:
				for dy in [-outline_w, 0, outline_w]:
					if dx != 0 or dy != 0:
						draw_char(font, pos + Vector2(dx, dy), _text[i], font_size, outline)
			draw_char(font, pos, _text[i], font_size, fill)
			x += w
