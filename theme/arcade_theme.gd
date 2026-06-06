extends Node

# Autoload. Builds and applies a StyleBoxFlat-based dark arcade theme to the
# entire window so every Button, Label, ScrollContainer picks it up automatically.

func _ready() -> void:
	var theme := _build()
	get_tree().root.theme = theme

func _build() -> Theme:
	var theme := Theme.new()

	# ---- Button ----
	var RADIUS := 10
	theme.set_stylebox("normal",   "Button", _btn(Palette.ARENA_FLOOR,  Palette.WALL,    RADIUS, 1.5))
	theme.set_stylebox("hover",    "Button", _btn(Color(Palette.WALL, 0.6), Palette.ACCENT,  RADIUS, 2.0))
	theme.set_stylebox("pressed",  "Button", _btn(Color("0d1018"),       Palette.NEUTRAL, RADIUS, 2.0))
	theme.set_stylebox("disabled", "Button", _btn(Color(Palette.ARENA_BG, 0.8), Color(Palette.WALL, 0.3), RADIUS, 1.0))
	theme.set_stylebox("focus",    "Button", _btn_empty())
	theme.set_color("font_color",          "Button", Palette.ACCENT)
	theme.set_color("font_hover_color",    "Button", Color.WHITE)
	theme.set_color("font_pressed_color",  "Button", Palette.NEUTRAL)
	theme.set_color("font_disabled_color", "Button", Color(Palette.NEUTRAL, 0.4))
	theme.set_constant("h_separation", "Button", 8)

	# ---- ScrollContainer ----
	var sc_bg := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", sc_bg)

	# ---- VScrollBar ----
	theme.set_stylebox("scroll",          "VScrollBar", _scrollbar_track())
	theme.set_stylebox("scroll_focus",    "VScrollBar", _scrollbar_track())
	theme.set_stylebox("grabber",         "VScrollBar", _grabber())
	theme.set_stylebox("grabber_hover",   "VScrollBar", _grabber(true))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _grabber(true))
	theme.set_constant("width", "VScrollBar", 8)

	# ---- Panel / PanelContainer ----
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.ARENA_BG
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	return theme

# ------------------------------------------------------------------ helpers

func _btn(bg: Color, border: Color, radius: int, border_w: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left   = int(border_w)
	s.border_width_right  = int(border_w)
	s.border_width_top    = int(border_w)
	s.border_width_bottom = int(border_w)
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left   = 16
	s.content_margin_right  = 16
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s

func _btn_empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _scrollbar_track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Palette.WALL, 0.2)
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	return s

func _grabber(hover: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Palette.NEUTRAL, 0.5 if not hover else 0.8)
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	return s
