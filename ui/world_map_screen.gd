extends Control

# World-conquest progress overlay: the 20 real-world countries you fight across,
# shown as their actual map SILHOUETTES in play order. Conquered countries glow
# green with a check; the current frontier is gold; later ones are dim + locked.
# Each shape is rasterised from the country's land mask. Added as a child of the
# main menu, frees itself on Close (mirrors campaign_screen).

const CountryMasks := preload("res://toybox_kingdoms/data/country_masks.gd")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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

	# Four-column scrolling grid of country silhouettes.
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

	col.add_child(_btn("CLOSE", Palette.SAFE, func() -> void:
		AudioManager.play("tap")
		queue_free()))


# One country tile: the map silhouette tinted by status, a corner order-badge, and a
# status mark (✓ conquered / ▶ current / 🔒 locked).
func _country_tile(idx: int, entry: Dictionary, conquered: int, current: int) -> Control:
	var is_conquered := idx < conquered
	var is_current := idx == current and conquered < CountryMasks.COUNTRIES.size()
	var is_locked := idx > current

	var accent := Palette.NEUTRAL
	var shape_col := Color(0.45, 0.5, 0.58)   # dim slate for locked silhouettes
	if is_current:
		accent = Palette.WARN
		shape_col = Palette.WARN
	elif is_conquered:
		accent = Palette.SAFE
		shape_col = Palette.SAFE

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		_panel(Color(accent, 0.18 if is_current else 0.08), Color(accent, 0.9 if is_current else 0.4)))
	card.custom_minimum_size = Vector2(180, 150)

	# A free-form layer so the badge + status mark can overlap the shape.
	var layer := Control.new()
	layer.custom_minimum_size = Vector2(180, 150)
	card.add_child(layer)

	# Silhouette — fills the tile, centred, aspect-preserved.
	var shape := TextureRect.new()
	shape.texture = _shape_texture(String(entry.get("mask_hex", "")), shape_col)
	shape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Linear filter melts the chunky mask cells into smooth toy-paper edges on upscale.
	shape.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shape.offset_left = 8; shape.offset_top = 22
	shape.offset_right = -8; shape.offset_bottom = -8
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shape)

	# Order badge, top-left.
	var badge := Label.new()
	badge.text = "%d" % (idx + 1)
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color.WHITE if not is_locked else Color(1, 1, 1, 0.45))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	badge.add_theme_constant_override("outline_size", 5)
	badge.position = Vector2(8, 2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(badge)

	# Status mark, top-right.
	var mark := Label.new()
	if is_current:
		mark.text = "▶"; mark.add_theme_color_override("font_color", Palette.WARN)
	elif is_conquered:
		mark.text = "✓"; mark.add_theme_color_override("font_color", Palette.SAFE)
	else:
		mark.text = "🔒"; mark.add_theme_color_override("font_color", Palette.NEUTRAL)
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	mark.add_theme_constant_override("outline_size", 5)
	mark.position = Vector2(146, 2)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(mark)
	return card


# Rasterise a country's land mask (cropped to its bounding box) into a toy-paper
# cut-out: a soft drop shadow, a darker edge stroke, then the tinted fill. Padded
# so the shadow/stroke have room; ocean stays transparent.
func _shape_texture(mask_hex: String, col: Color) -> ImageTexture:
	if mask_hex == "":
		return null
	var mask := CountryMasks.decode_mask(mask_hex)
	var bb := CountryMasks.mask_bbox(mask)
	var gw: int = CountryMasks.GRID_W
	var mw: int = bb["x1"] - bb["x0"] + 1
	var mh: int = bb["y1"] - bb["y0"] + 1
	if mw <= 0 or mh <= 0:
		return null
	var pad := 4          # border room for the stroke + shadow
	var sh := 3           # drop-shadow offset (down-right)
	var w := mw + pad * 2
	var h := mh + pad * 2
	# Copy the cropped land into a padded local grid for O(1) neighbour lookups.
	var land := PackedByteArray(); land.resize(w * h)
	for y in mh:
		for x in mw:
			if mask[(bb["y0"] + y) * gw + (bb["x0"] + x)] == 1:
				land[(y + pad) * w + (x + pad)] = 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var shadow := Color(0, 0, 0, 0.30)
	var edge := col.darkened(0.42)
	# 1) drop shadow — the silhouette shifted down-right.
	for y in h:
		for x in w:
			var sx := x - sh; var sy := y - sh
			if sx >= 0 and sy >= 0 and land[sy * w + sx] == 1:
				img.set_pixel(x, y, shadow)
	# 2) edge stroke — empty cells touching land (8-neighbour) become the paper rim.
	for y in h:
		for x in w:
			if land[y * w + x] == 1:
				continue
			var near := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx; var ny := y + dy
					if nx >= 0 and nx < w and ny >= 0 and ny < h and land[ny * w + nx] == 1:
						near = true
			if near:
				img.set_pixel(x, y, edge)
	# 3) fill — the land itself, on top.
	for y in h:
		for x in w:
			if land[y * w + x] == 1:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _btn(text: String, color: Color, cb: Callable, width: float = 150.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _panel(Color(color, 0.22), color))
	b.add_theme_stylebox_override("hover", _panel(Color(color, 0.40), color))
	b.add_theme_stylebox_override("pressed", _panel(Color(color, 0.55), color))
	b.custom_minimum_size = Vector2(width, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


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
