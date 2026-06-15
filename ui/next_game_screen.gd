extends Control

# Party-mode bridge between rounds. Instead of making players pick from a grid,
# this screen shows a quick slot-machine reveal of the next auto-chosen game,
# its goal line, a compact live scoreboard, and a GET READY countdown — then
# launches the round. Keeps the match flowing like a real party game.

var target_index: int = 0
var is_first: bool = false

var _name_l: Label
var _tag_l: Label
var _icon: _RandIcon
var _ready_l: Label


# Drawn star icon (no emoji) — purple while spinning, green when locked in.
class _RandIcon extends Control:
	var col := Color("aa60ff")
	func _draw() -> void:
		DrawKit.star(self, size * 0.5, minf(size.x, size.y) * 0.44, col)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("221a45")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_scoreboard()
	_build_reveal()
	_run_reveal()


# ── Compact live scoreboard so players always see who's winning ──────────────────
func _build_scoreboard() -> void:
	var players := GameManager.players
	var n := players.size()
	var chip_w := 220.0
	var spacing := chip_w + 12.0
	var start_x := Palette.CENTER_X - (n - 1) * spacing * 0.5
	var match_point := false

	for i in n:
		var p: PlayerData = players[i]
		if p.score >= ScoreManager.target_score - 1:
			match_point = true

		var chip_bg := ColorRect.new()
		chip_bg.color = Color(p.color, 0.15)
		chip_bg.size = Vector2(chip_w, 42)
		chip_bg.position = Vector2(start_x + i * spacing - chip_w * 0.5, 28)
		chip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip_bg)

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

	if match_point:
		var mp := Label.new()
		mp.text = "MATCH POINT!"
		mp.add_theme_font_size_override("font_size", 22)
		mp.add_theme_color_override("font_color", Palette.WARN)
		mp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp.position = Vector2(0, 78)
		mp.size = Vector2(Palette.DESIGN_W, 28)
		mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mp)


# ── Centre reveal block ───────────────────────────────────────────────────────────
func _build_reveal() -> void:
	var cy := Palette.DESIGN_H * 0.5

	var up := Label.new()
	up.text = "FIRST GAME" if is_first else "NEXT GAME"
	up.add_theme_font_size_override("font_size", 24)
	up.add_theme_color_override("font_color", Color(Palette.ACCENT, 0.8))
	up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up.position = Vector2(0, cy - 200)
	up.size = Vector2(Palette.DESIGN_W, 30)
	up.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(up)

	_icon = _RandIcon.new()
	_icon.position = Vector2(Palette.CENTER_X - 70, cy - 160)
	_icon.size = Vector2(140, 110)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_name_l = Label.new()
	_name_l.add_theme_font_size_override("font_size", 60)
	_name_l.add_theme_color_override("font_color", Color("aa60ff"))
	_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_l.position = Vector2(0, cy - 30)
	_name_l.size = Vector2(Palette.DESIGN_W, 76)
	_name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_l)

	_tag_l = Label.new()
	_tag_l.add_theme_font_size_override("font_size", 26)
	_tag_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_tag_l.modulate.a = 0.0
	_tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_l.position = Vector2(0, cy + 52)
	_tag_l.size = Vector2(Palette.DESIGN_W, 36)
	_tag_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag_l)

	_ready_l = Label.new()
	_ready_l.add_theme_font_size_override("font_size", 34)
	_ready_l.add_theme_color_override("font_color", Color(Palette.SAFE, 0.0))
	_ready_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_l.position = Vector2(0, cy + 120)
	_ready_l.size = Vector2(Palette.DESIGN_W, 44)
	_ready_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ready_l)


func _run_reveal() -> void:
	var idxs: Array = MiniGameRegistry.launch_indices()
	var entry: Dictionary = MiniGameRegistry.GAMES[target_index]

	# Slot-machine spin that slows down before landing on the chosen game.
	var spins := 14 if is_first else 10
	for tick in spins:
		var show_idx: int = idxs[randi() % idxs.size()]
		_name_l.text = MiniGameRegistry.GAMES[show_idx].title
		AudioManager.play("tap", randf_range(1.1, 1.5))
		await get_tree().create_timer(0.045 + float(tick) * 0.014).timeout
		if not is_inside_tree():
			return

	# Lock in.
	_name_l.text = entry.get("title", "???")
	_name_l.add_theme_color_override("font_color", Palette.SAFE)
	_icon.col = Palette.SAFE
	_icon.queue_redraw()
	AudioManager.play("go")

	# Pop the title.
	_name_l.pivot_offset = Vector2(Palette.DESIGN_W * 0.5, 38)
	_name_l.scale = Vector2(0.7, 0.7)
	var pt := _name_l.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pt.tween_property(_name_l, "scale", Vector2.ONE, 0.3)

	# Reveal the goal line.
	_tag_l.text = entry.get("tagline", "")
	_tag_l.create_tween().tween_property(_tag_l, "modulate:a", 1.0, 0.25)

	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return

	# GET READY countdown: 3 … 2 … 1 …
	_ready_l.add_theme_color_override("font_color", Palette.WARN)
	for n in [3, 2, 1]:
		_ready_l.text = "GET READY  %d" % n
		AudioManager.play("count")
		await get_tree().create_timer(0.55).timeout
		if not is_inside_tree():
			return

	GameManager.pick_game(target_index)
