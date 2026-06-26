extends Node

# Autoload. Builds and applies a StyleBoxFlat-based arcade theme to the entire
# window so every Button, Label, ScrollContainer picks it up automatically.
# Also loads the chunky rounded display font (Fredoka) and exposes it as `font`
# for code that draws text directly (draw_string) and so bypasses the theme.

const FONT_PATH := "res://assets/fonts/Fredoka-Variable.ttf"

# Shared display font. Loaded once; used everywhere via the theme default plus
# direct draw_string callers (DrawKit, action buttons, menu, results, etc.).
var font: Font
# Heavier cut (wght 700) for big numbers / headings — the % readout, timer,
# leaderboard ranks. Numbers at 700 vs labels at 500 is most of the UI polish.
var font_heavy: Font

func _ready() -> void:
	var base := _load_base()
	font = _weighted(base, 600)             # SemiBold — friendly but solid
	font_heavy = _weighted(base, 700)       # Bold — headings + big numbers
	var theme := _build()
	get_tree().root.theme = theme

# Load the variable Fredoka TTF through the resource system. Using load() (not
# FontFile.load_dynamic_font, which reads the raw .ttf off disk) is essential on
# exported builds — iOS only packs the *imported* font resource, not the source
# .ttf, so a direct disk read fails with "Can't open file ...Fredoka-Variable.ttf".
func _load_base() -> FontFile:
	var base: FontFile = load(FONT_PATH)
	if base == null:
		# Fallback for the (unexpected) case the import is missing.
		base = FontFile.new()
		base.load_dynamic_font(FONT_PATH)
	base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return base

# Pin a variable font to a specific weight so each cut renders crisply.
func _weighted(base: FontFile, wght: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": wght}
	return fv

func _build() -> Theme:
	var theme := Theme.new()

	# Make every Label / Button / Control use the rounded display font by default.
	if font:
		theme.set_default_font(font)
		theme.set_default_font_size(22)

	# ---- Button ---- (rounded, brighter to match the toy-box menu)
	var RADIUS := 16
	theme.set_stylebox("normal",   "Button", _btn(Color("26324a"),       Color(Palette.WALL, 0.85), RADIUS, 2.0))
	theme.set_stylebox("hover",    "Button", _btn(Color("33446a"),       Palette.ACCENT,            RADIUS, 2.5))
	theme.set_stylebox("pressed",  "Button", _btn(Color("1b2740"),       Palette.NEUTRAL,           RADIUS, 2.5))
	theme.set_stylebox("disabled", "Button", _btn(Color(Palette.ARENA_BG, 0.8), Color(Palette.WALL, 0.3), RADIUS, 1.0))
	theme.set_stylebox("focus",    "Button", _btn_empty())
	theme.set_color("font_color",          "Button", Color.WHITE)
	theme.set_color("font_hover_color",    "Button", Color.WHITE)
	theme.set_color("font_pressed_color",  "Button", Color(Palette.ACCENT, 0.85))
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
