extends Control

# Settings overlay: audio sliders, restore purchases, privacy policy, credits.
# Added as a child of the main menu; frees itself on Close.

# TODO(store): host a real privacy policy and put its URL here before submission.
const PRIVACY_URL := "https://example.com/party-pals-arena/privacy"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color("141a28"), Color("3f4d69")))
	panel.custom_minimum_size = Vector2(560, 470)
	panel.position = Vector2(Palette.CENTER_X - 280, 130)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)

	col.add_child(_title("SETTINGS"))
	col.add_child(_slider_row("Music", SaveManager.music_volume(), SaveManager.set_music_volume))
	col.add_child(_slider_row("Sound FX", SaveManager.sfx_volume(),
		func(v): SaveManager.set_sfx_volume(v); AudioManager.play("tap")))

	col.add_child(_btn("Restore Purchases", Palette.PLAYER_COLORS[1],
		func(): MonetizationManager.restore()))
	col.add_child(_btn("Privacy Policy", Palette.NEUTRAL,
		func(): OS.shell_open(PRIVACY_URL)))

	var credits := Label.new()
	credits.text = "Party Pals Arena\nMade with Godot. Music & SFX generated in-house."
	credits.add_theme_font_size_override("font_size", 14)
	credits.add_theme_color_override("font_color", Color(Palette.NEUTRAL, 0.9))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(credits)

	col.add_child(_btn("CLOSE", Palette.SAFE, func(): AudioManager.play("tap"); queue_free()))

func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _slider_row(label: String, value: float, on_change: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(Palette.ACCENT, 0.9))
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(500, 28)
	s.value_changed.connect(func(v): on_change.call(v))
	row.add_child(s)
	return row

func _btn(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _panel(Color(color, 0.22), color))
	b.add_theme_stylebox_override("hover", _panel(Color(color, 0.40), color))
	b.add_theme_stylebox_override("pressed", _panel(Color(color, 0.55), color))
	b.custom_minimum_size = Vector2(0, 52)
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
	s.content_margin_left = 20; s.content_margin_right = 20
	s.content_margin_top = 16; s.content_margin_bottom = 16
	return s
