extends Control

# World-conquest progress overlay: the 20 real-world countries you fight across,
# shown as island screenshot previews in play order. Conquered countries glow
# green with a check; the current frontier is gold; later ones are dimmed + locked.
# Screenshots are pre-generated assets (assets/islands/island_N.png) produced by
# running tools/shot_islands.tscn once in the editor.
# Added as a child of the main menu, frees itself on Close (mirrors campaign_screen).

const CountryMasks := preload("res://toybox_kingdoms/data/country_masks.gd")
const UIKit := preload("res://ui/ui_kit.gd")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color("141a28"), Color("3f4d69")))
	panel.custom_minimum_size = Vector2(800, 624)
	panel.position = Vector2(Palette.CENTER_X - 400, 48)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var total: int = CountryMasks.COUNTRIES.size()
	# Conquest progress rides the persisted island index: every cleared country advances it.
	var conquered: int = clampi(SaveManager.endless_island(), 0, total)
	var current := mini(conquered, total - 1)

	# ── Title row: map icon + heading ────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 12)
	col.add_child(title_row)

	var map_tex := AssetKit.tex("res://assets/hud/map")
	if map_tex:
		var icon := TextureRect.new()
		icon.texture = map_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(icon)

	var title := Label.new()
	title.text = "WORLD CONQUERED 👑" if conquered >= total else "WORLD CONQUEST"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)

	var prog := Label.new()
	prog.text = "%d / %d countries conquered" % [conquered, total]
	prog.add_theme_font_size_override("font_size", 20)
	prog.add_theme_color_override("font_color", Palette.WARN)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(prog)

	# Four-column scrolling grid of island screenshot previews.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 462)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for idx in total:
		var entry: Dictionary = CountryMasks.COUNTRIES[idx]
		grid.add_child(_country_tile(idx, entry, conquered, current))

	var close_btn := UIKit.stone_btn("CLOSE", false, func() -> void:
		AudioManager.play("tap")
		queue_free(), 200)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(close_btn)


# One country tile: island screenshot preview tinted by status, plus a number badge
# and status mark (✓ conquered / ▶ current / 🔒 locked).
func _country_tile(idx: int, _entry: Dictionary, conquered: int, current: int) -> Control:
	var is_conquered := idx < conquered
	var is_current := idx == current and conquered < CountryMasks.COUNTRIES.size()
	var is_locked := idx > current

	var accent := Palette.NEUTRAL
	if is_current:
		accent = Palette.WARN
	elif is_conquered:
		accent = Palette.SAFE

	# Use a plain Control (not PanelContainer) so children use normal anchor layout
	# without the container trying to manage their sizes. clip_children is intentionally
	# NOT set — PanelContainer + CLIP_CHILDREN_ONLY causes intermediate-buffer compositing
	# that darkens TextureRect children in Godot 4.6.
	var card := Control.new()
	card.custom_minimum_size = Vector2(180, 150)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background panel drawn first (behind everything else).
	var bg := Panel.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(accent, 0.10 if is_current else 0.06)
	card_style.border_color = Color(accent, 0.9 if is_current else 0.45)
	card_style.border_width_left = 2; card_style.border_width_right = 2
	card_style.border_width_top = 2; card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 10; card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10; card_style.corner_radius_bottom_right = 10
	bg.add_theme_stylebox_override("panel", card_style)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)

	# Island screenshot — fills the tile, cover-cropped. Siblings of bg so no
	# intermediate clip buffer is introduced.
	var shot := TextureRect.new()
	shot.texture = _island_texture(idx)
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shot)

	# Status tint overlay: dark dim for locked, green wash for conquered.
	var tint := ColorRect.new()
	if is_locked:
		tint.color = Color(0, 0, 0, 0.40)
	elif is_conquered:
		tint.color = Color(Palette.SAFE, 0.15)
	else:
		tint.color = Color(0, 0, 0, 0)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tint)

	# Border drawn on top so it overlaps the image edge cleanly.
	var border := Panel.new()
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = card_style.border_color
	border_style.border_width_left = 2; border_style.border_width_right = 2
	border_style.border_width_top = 2; border_style.border_width_bottom = 2
	border_style.corner_radius_top_left = 10; border_style.corner_radius_top_right = 10
	border_style.corner_radius_bottom_left = 10; border_style.corner_radius_bottom_right = 10
	border.add_theme_stylebox_override("panel", border_style)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(border)

	# Order badge, top-left.
	var badge := Label.new()
	badge.text = "%d" % (idx + 1)
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color.WHITE if not is_locked else Color(1, 1, 1, 0.55))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	badge.add_theme_constant_override("outline_size", 6)
	badge.position = Vector2(8, 2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)

	# Status mark, top-right.
	var mark := Label.new()
	if is_current:
		mark.text = "▶"; mark.add_theme_color_override("font_color", Palette.WARN)
	elif is_conquered:
		mark.text = "✓"; mark.add_theme_color_override("font_color", Palette.SAFE)
	else:
		mark.text = "🔒"; mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	mark.add_theme_constant_override("outline_size", 6)
	mark.position = Vector2(146, 2)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mark)
	return card


# Load the pre-rendered island thumbnail (generated by tools/shot_islands.tscn).
# Returns null if the asset hasn't been generated yet (tile shows a plain colour).
func _island_texture(idx: int) -> Texture2D:
	var path := "res://assets/islands/island_%d.png" % idx
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D




func _panel(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.corner_radius_top_left = 14; s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14; s.corner_radius_bottom_right = 14
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 10; s.content_margin_bottom = 10
	return s
