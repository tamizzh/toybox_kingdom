extends Control

# Profile / stats overlay: coins, level + XP bar, and lifetime match/round stats.
# Added as a child of the main menu; frees itself on Close. Gives players a sense of
# progress and a home for the earned-currency economy.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color("141a28"), Color("3f4d69")))
	panel.custom_minimum_size = Vector2(620, 480)
	panel.position = Vector2(Palette.CENTER_X - 310, 120)
	add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_top", 22)
	pad.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)

	col.add_child(_heading("PROFILE", 34, Color.WHITE))
	col.add_child(_heading("Level %d" % SaveManager.level(), 26, Palette.WARN))

	# XP progress bar
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = SaveManager.level_progress()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.WARN
	fill.set_corner_radius_all(10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	col.add_child(bar)

	col.add_child(_stat_row("Coins", "%d" % SaveManager.coins(), Palette.WARN))
	col.add_child(_stat_row("Matches played", "%d" % SaveManager.stat("matches_played"), Color.WHITE))
	col.add_child(_stat_row("Matches won", "%d" % SaveManager.stat("matches_won"), Palette.SAFE))
	col.add_child(_stat_row("Rounds won", "%d" % SaveManager.stat("rounds_won"), Color.WHITE))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	col.add_child(_btn("CLOSE", Palette.SAFE, func() -> void:
		AudioManager.play("tap")
		queue_free()))


func _heading(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _stat_row(label: String, value: String, vcol: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 24)
	v.add_theme_color_override("font_color", vcol)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(v)
	return row


func _btn(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _panel(Color(color, 0.22), color))
	b.add_theme_stylebox_override("hover", _panel(Color(color, 0.40), color))
	b.add_theme_stylebox_override("pressed", _panel(Color(color, 0.55), color))
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(cb)
	return b


func _panel(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.corner_radius_top_left = 16; s.corner_radius_top_right = 16
	s.corner_radius_bottom_left = 16; s.corner_radius_bottom_right = 16
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 10; s.content_margin_bottom = 10
	return s
