extends Control

# Shop overlay: cosmetic colour packs (buy / select) + a Remove Ads purchase.
# Added as a child of the main menu; frees itself on Close. Rebuilds its rows
# whenever a purchase or selection changes so state stays in sync.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		if c is ColorRect:
			continue   # keep the dim backdrop
		c.queue_free()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color("141a28"), Color("3f4d69")))
	panel.custom_minimum_size = Vector2(720, 560)
	panel.position = Vector2(Palette.CENTER_X - 360, 80)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "SHOP"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var bal := Label.new()
	bal.text = "%d COINS" % SaveManager.coins()
	bal.add_theme_font_size_override("font_size", 20)
	bal.add_theme_color_override("font_color", Palette.WARN)
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(bal)

	for id in Cosmetics.ids():
		col.add_child(_pack_row(id))

	col.add_child(_remove_ads_row())
	col.add_child(_btn("CLOSE", Palette.SAFE, func(): AudioManager.play("tap"); queue_free()))

func _pack_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 66)

	# Colour preview: four mascot faces in the pack colours
	var colors := Cosmetics.colors(id)
	for i in 4:
		var face := MascotFace.new()
		face.set_color(colors[i])
		face.custom_minimum_size = Vector2(42, 42)
		face.size = Vector2(42, 42)
		row.add_child(face)

	var name_l := Label.new()
	name_l.text = Cosmetics.name_of(id)
	name_l.add_theme_font_size_override("font_size", 22)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.custom_minimum_size = Vector2(130, 0)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	if SaveManager.owns_pack(id):
		if SaveManager.selected_pack() == id:
			row.add_child(_tag("SELECTED", Palette.SAFE))
		else:
			row.add_child(_btn("SELECT", Palette.PLAYER_COLORS[1], func():
				AudioManager.play("tap")
				SaveManager.set_selected_pack(id)
				_rebuild()))
	else:
		# Two unlock paths: pay with money (IAP) OR spend earned coins.
		var cost := Cosmetics.coin_cost_of(id)
		if cost > 0:
			var can := SaveManager.coins() >= cost
			var coin_col := Palette.PLAYER_COLORS[2] if can else Palette.NEUTRAL
			var cbtn := _btn("%d coins" % cost, coin_col, func():
				if SaveManager.spend_coins(cost):
					AudioManager.play("collect")
					SaveManager.add_owned_pack(id)
					SaveManager.set_selected_pack(id)
					_rebuild(), 134.0)
			cbtn.disabled = not can
			row.add_child(cbtn)
		row.add_child(_btn(Cosmetics.price_of(id), Palette.WARN, func():
			MonetizationManager.purchase(Cosmetics.product_of(id), func(_p):
				SaveManager.set_selected_pack(id)
				_rebuild()), 134.0))
	return row

func _remove_ads_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	var l := Label.new()
	l.text = "Remove Ads"
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	if SaveManager.has_remove_ads():
		row.add_child(_tag("OWNED", Palette.SAFE))
	else:
		row.add_child(_btn("$2.99", Palette.DANGER, func():
			MonetizationManager.purchase("remove_ads", func(_p): _rebuild())))
	return row

func _tag(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(120, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _btn(text: String, color: Color, cb: Callable, width: float = 150.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _panel(Color(color, 0.22), color))
	b.add_theme_stylebox_override("hover", _panel(Color(color, 0.40), color))
	b.add_theme_stylebox_override("pressed", _panel(Color(color, 0.55), color))
	b.custom_minimum_size = Vector2(width, 48)
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
