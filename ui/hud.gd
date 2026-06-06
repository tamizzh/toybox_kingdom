extends Control

# In-game overlay: timer, game title, and per-player score chips at screen corners.
# P1 = bottom-left, P2 = bottom-right (normal).
# P3 = top-left, P4 = top-right — rotated 180° so they read from their edge.

const CHIP_W := 130.0
const CHIP_H := 36.0

var _time_label: Label
var _status_label: Label
var _chips := {}   # id -> Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_time_label = _make_label(58, Vector2(Palette.CENTER_X - 100.0, 6), Vector2(200, 66))
	_time_label.add_theme_color_override("font_color", Palette.ACCENT)

	_status_label = _make_label(24, Vector2(Palette.CENTER_X - 300.0, 72), Vector2(600, 34))
	_status_label.add_theme_color_override("font_color", Palette.NEUTRAL)

	ScoreManager.scores_updated.connect(_refresh)

func _make_label(font_size: int, pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func setup(players: Array) -> void:
	for l in _chips.values():
		l.queue_free()
	_chips.clear()

	# Corner positions: P1 bottom-left, P2 bottom-right, P3 top-left (rot), P4 top-right (rot)
	# Design = 1560x720. Chip size = 130x36.
	var w := Palette.DESIGN_W
	var corners := [
		{"pos": Vector2(8.0, 684.0),        "rot": 0.0},   # P1 bottom-left
		{"pos": Vector2(w - 138.0, 684.0),  "rot": 0.0},   # P2 bottom-right
		{"pos": Vector2(8.0, 8.0),          "rot": PI},    # P3 top-left (upside-down)
		{"pos": Vector2(w - 268.0, 8.0),    "rot": PI},    # P4 top-right (upside-down)
	]

	for i in players.size():
		var p: PlayerData = players[i]
		var info: Dictionary = corners[i % corners.size()]
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", p.color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(CHIP_W, CHIP_H)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if info.rot != 0.0:
			# Rotate around the label center so visual position is at info.pos
			# After PI rotation, local (0,0) → screen (pos + size) so:
			# set position = info.pos, pivot at center, rotation = PI
			l.position = info.pos
			l.pivot_offset = Vector2(CHIP_W * 0.5, CHIP_H * 0.5)
			l.rotation = info.rot
		else:
			l.position = info.pos

		add_child(l)
		_chips[p.id] = l

	_refresh()

func _refresh() -> void:
	for p in ScoreManager.players:
		if _chips.has(p.id):
			_chips[p.id].text = "%s  %d" % [p.display_name, p.score]

func set_time(t: float) -> void:
	_time_label.text = "%d" % int(ceil(t))

func set_status(text: String) -> void:
	_status_label.text = text

func flash_round_result(results: Dictionary) -> void:
	var best := -1
	var bid := -1
	for id in results:
		if int(results[id]) > best:
			best = int(results[id])
			bid = id
	if bid >= 0 and best > 0:
		set_status("%s wins the round!" % Palette.player_name(bid))
	else:
		set_status("Round over")
