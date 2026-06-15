extends Control

# In-game HUD: score chips at top corners, timer at top-centre, game title below.
# Matches the toy-box reference style (race_target / snake_target).

const CHIP_W := 210.0
const CHIP_H := 76.0

var _time_label: Label
var _timer_node: _TimerPill   # drawn widget that shows clock icon + number
var _title_label: Label
var _title_shadow: Label
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
	_timer_node.position = Vector2(Palette.CENTER_X - 90, 8)
	_timer_node.size     = Vector2(180, 72)
	_timer_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_node)
	# Keep _time_label as a no-op dummy so set_time() callers don't crash
	_time_label = Label.new()
	_time_label.visible = false
	add_child(_time_label)

# ── Game title banner (title + subtitle), like the reference art ────────────────
func _build_title() -> void:
	var bw := 600.0
	var bx := Palette.CENTER_X - bw * 0.5
	# Banner backdrop — dark translucent pill with a thin warm underline accent.
	var banner := _pill(Rect2(bx, 84, bw, 86), Color(0.07, 0.10, 0.20, 0.80), 20)
	add_child(banner)
	var accent := _pill(Rect2(bx + bw * 0.30, 162, bw * 0.40, 5),
						Color(Palette.WARN, 0.85), 3)
	add_child(accent)

	# Title — big, white, drop-shadowed
	_title_shadow = _label("", 38, Vector2(bx + 2, 90), Vector2(bw, 46), self)
	_title_shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.55))
	_title_label = _label("", 38, Vector2(bx, 88), Vector2(bw, 46), self)
	_title_label.add_theme_color_override("font_color", Color.WHITE)

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
			Vector2(12, 10),
			Vector2(w - CHIP_W - 12, 10),
		][i]
	else:
		# Four chips spread across the top
		var total := n * CHIP_W + (n - 1) * 8.0
		var start  := (w - total) * 0.5
		return Vector2(start + i * (CHIP_W + 8.0), 10)

func _make_chip(p: PlayerData, pos: Vector2, mirror: bool) -> void:
	# Outer pill — outer edge carries a big mascot face that pops out slightly.
	var outer := _pill(Rect2(pos, Vector2(CHIP_W, CHIP_H)),
					   Color(p.color.darkened(0.22), 0.92), 22)
	outer.clip_contents = false
	add_child(outer)
	_chip_roots[p.id] = outer

	# Cute mascot face on the outer side (overhangs the pill edge a touch)
	var fsz := 64.0
	var fy  := (CHIP_H - fsz) * 0.5
	var fx: float = (CHIP_W - fsz + 6.0) if mirror else -6.0
	var face := MascotFace.new()
	face.set_color(p.color)
	face.position = Vector2(fx, fy)
	face.size     = Vector2(fsz, fsz)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(face)

	# Text block (P# label + big score) on the inner side of the face
	var tx: float = 14.0 if mirror else 66.0
	var tw: float = CHIP_W - 80.0
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT

	var name_l := _label(p.display_name, 13, Vector2(tx, 8), Vector2(tw, 20), outer)
	name_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	name_l.horizontal_alignment = align

	var score_l := _label(str(p.score), 42, Vector2(tx, 24), Vector2(tw, 46), outer)
	score_l.add_theme_color_override("font_color", Color.WHITE)
	score_l.horizontal_alignment = align
	score_l.pivot_offset = Vector2(tw * 0.5, 23)
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
	var up := text.to_upper()
	if _title_label:   _title_label.text   = up
	if _title_shadow:  _title_shadow.text  = up

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
		var fill := Color("c0392b") if _warn else Color(0.05, 0.06, 0.14, 0.95)
		var num_col := Color("ff6b6b") if _warn else Palette.WARN

		# Pill background with outline
		DrawKit.card(self, Rect2(Vector2.ZERO, size), h * 0.5, fill, 4.0, true)

		# Clock icon (left side)
		DrawKit.clock(self, Vector2(h * 0.55, h * 0.5), h * 0.30, num_col, 3.5)

		# Number (right side)
		var font: Font = ArcadeTheme.font if ArcadeTheme.font else ThemeDB.fallback_font
		var fs := 44
		var txt := str(_seconds)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := w * 0.62 + (w * 0.35 - tw) * 0.5
		var ty := h * 0.5 + fs * 0.36
		# shadow
		draw_string(font, Vector2(tx + 2, ty + 2), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45))
		# number
		draw_string(font, Vector2(tx, ty), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, num_col)
