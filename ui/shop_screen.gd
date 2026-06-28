extends Control

# Shop overlay — four sections in a scrollable panel:
#   COIN PACKS  |  UPGRADES  |  COLOUR PACKS  |  REMOVE ADS
# Visual kit: panel_frame.png (stone 9-slice) + btn_blue / btn_green CTAs.

const PANEL_FRAME   := preload("res://assets/panel_frame.png")
const BTN_BLUE      := preload("res://assets/btn_blue.png")
const BTN_GREEN     := preload("res://assets/btn_green.png")
const COIN_ICON     := preload("res://assets/hud/coin.png")
const BOOST_ICON    := preload("res://assets/hud/boost.png")
const SHIELD_ICON   := preload("res://assets/hud/shield.png")
const UpgradesData  := preload("res://theme/upgrades.gd")

# IAP-only coin bundles — the free-earn path fills in for non-payers via colour packs.
const COIN_PACKS := [
	{"name": "Handful",  "amount": 300,  "price": "$0.99", "product": "coins_300"},
	{"name": "Pouch",    "amount": 1000, "price": "$2.99", "product": "coins_1000"},
	{"name": "Chest",    "amount": 2500, "price": "$5.99", "product": "coins_2500"},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		if c is ColorRect:
			continue
		c.queue_free()

	# ── Outer stone panel — full-height with margin so content scrolls ────────
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame_style(20))
	panel.anchor_left   = 0.5;  panel.anchor_right  = 0.5
	panel.anchor_top    = 0.0;  panel.anchor_bottom = 1.0
	panel.offset_left   = -380; panel.offset_right  = 380
	panel.offset_top    = 48;   panel.offset_bottom = -48
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "SHOP"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Palette.WARN)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	# ── Coin balance chip ─────────────────────────────────────────────────────
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 7)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(coin_row)

	var coin_img := TextureRect.new()
	coin_img.texture = COIN_ICON
	coin_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_img.custom_minimum_size = Vector2(30, 30)
	coin_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_child(coin_img)

	var bal := Label.new()
	bal.text = str(SaveManager.coins()) + " coins"
	bal.add_theme_font_size_override("font_size", 20)
	bal.add_theme_color_override("font_color", Palette.WARN)
	bal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	bal.add_theme_constant_override("outline_size", 5)
	bal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_child(bal)

	outer.add_child(_divider())

	# ── Scrollable item list ──────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 7)
	scroll.add_child(inner)

	# Section: COIN PACKS
	inner.add_child(_section_header("COIN PACKS"))
	for pack in COIN_PACKS:
		inner.add_child(_coin_pack_row(pack))

	inner.add_child(_divider())

	# Section: UPGRADES
	inner.add_child(_section_header("UPGRADES"))
	for id in UpgradesData.ids():
		inner.add_child(_upgrade_row(id))

	inner.add_child(_divider())

	# Section: COLOUR PACKS
	inner.add_child(_section_header("COLOUR PACKS"))
	for id in Cosmetics.ids():
		inner.add_child(_colour_row(id))

	inner.add_child(_divider())

	# Section: REMOVE ADS
	inner.add_child(_remove_ads_row())

	outer.add_child(_divider())

	# ── Close (always visible at bottom) ─────────────────────────────────────
	var close_btn := _stone_btn("CLOSE", BTN_BLUE, Color.WHITE, func():
		AudioManager.play("tap")
		queue_free())
	close_btn.custom_minimum_size = Vector2(200, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(close_btn)


# ── Coin pack row ─────────────────────────────────────────────────────────────
func _coin_pack_row(pack: Dictionary) -> Control:
	var wrap := _row_wrap()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 52)
	wrap.add_child(row)

	# Stack of coin icons: 3 overlapping coins to visually suggest a pile.
	var icon_stack := Control.new()
	icon_stack.custom_minimum_size = Vector2(60, 44)
	icon_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var img := TextureRect.new()
		img.texture = COIN_ICON
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size = Vector2(30, 30)
		img.position = Vector2(i * 10, (2 - i) * 4)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_stack.add_child(img)
	row.add_child(icon_stack)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_l := Label.new()
	name_l.text = pack["name"]
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	name_l.add_theme_constant_override("outline_size", 4)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_l)

	var amt_l := Label.new()
	amt_l.text = str(pack["amount"]) + " coins"
	amt_l.add_theme_font_size_override("font_size", 14)
	amt_l.add_theme_color_override("font_color", Palette.WARN)
	amt_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	amt_l.add_theme_constant_override("outline_size", 3)
	amt_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(amt_l)

	var p_amount: int = pack["amount"]
	var p_product: String = pack["product"]
	row.add_child(_stone_btn(pack["price"], BTN_BLUE, Palette.WARN, func():
		MonetizationManager.purchase(p_product, func(_p: String):
			SaveManager.add_coins(p_amount)
			_rebuild())))
	return wrap


# ── Upgrade row ───────────────────────────────────────────────────────────────
func _upgrade_row(id: String) -> Control:
	var wrap := _row_wrap()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 60)
	wrap.add_child(row)

	var icon_tex: Texture2D = COIN_ICON if UpgradesData.icon_of(id) == "coin" else BOOST_ICON
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_l := Label.new()
	name_l.text = UpgradesData.name_of(id)
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	name_l.add_theme_constant_override("outline_size", 4)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_l)

	var desc_l := Label.new()
	desc_l.text = UpgradesData.desc_of(id)
	desc_l.add_theme_font_size_override("font_size", 13)
	desc_l.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	desc_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	desc_l.add_theme_constant_override("outline_size", 3)
	desc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(desc_l)

	if SaveManager.has_upgrade(id):
		row.add_child(_tag("OWNED", Palette.SAFE))
	else:
		var cost := UpgradesData.coin_cost_of(id)
		var can := SaveManager.coins() >= cost
		var coin_col := Color.WHITE if can else Color(0.55, 0.55, 0.55)
		var buy_id := id
		var buy_cost := cost
		var cbtn := _stone_btn(str(cost) + " coins", BTN_GREEN, coin_col, func():
			if SaveManager.spend_coins(buy_cost):
				AudioManager.play("collect")
				SaveManager.unlock_upgrade(buy_id)
				_rebuild())
		cbtn.disabled = not can
		row.add_child(cbtn)

		var iap_id := id
		row.add_child(_stone_btn(UpgradesData.price_of(id), BTN_BLUE, Palette.WARN, func():
			MonetizationManager.purchase(UpgradesData.product_of(iap_id), func(_p: String):
				SaveManager.unlock_upgrade(iap_id)
				_rebuild())))
	return wrap


# ── Colour pack row ───────────────────────────────────────────────────────────
func _colour_row(id: String) -> Control:
	var wrap := _row_wrap()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 52)
	wrap.add_child(row)

	# King colour swatch — the territory colour visible in-game.
	var swatch_bg := StyleBoxFlat.new()
	swatch_bg.bg_color = Cosmetics.king_color(id)
	swatch_bg.corner_radius_top_left     = 20
	swatch_bg.corner_radius_top_right    = 20
	swatch_bg.corner_radius_bottom_left  = 20
	swatch_bg.corner_radius_bottom_right = 20
	var swatch := PanelContainer.new()
	swatch.add_theme_stylebox_override("panel", swatch_bg)
	swatch.custom_minimum_size = Vector2(40, 40)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	# Four mascot-face palette swatches.
	var colors := Cosmetics.colors(id)
	for i in 4:
		var face := MascotFace.new()
		face.set_color(colors[i])
		face.custom_minimum_size = Vector2(30, 30)
		face.size = Vector2(30, 30)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(face)

	var name_l := Label.new()
	name_l.text = Cosmetics.name_of(id)
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	name_l.add_theme_constant_override("outline_size", 4)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)

	if SaveManager.owns_pack(id):
		if SaveManager.selected_pack() == id:
			row.add_child(_tag("ACTIVE", Palette.SAFE))
		else:
			var sel_id := id
			row.add_child(_stone_btn("SELECT", BTN_GREEN, Color.WHITE, func():
				AudioManager.play("tap")
				SaveManager.set_selected_pack(sel_id)
				_rebuild()))
	else:
		var cost := Cosmetics.coin_cost_of(id)
		if cost > 0:
			var can := SaveManager.coins() >= cost
			var coin_col := Color.WHITE if can else Color(0.55, 0.55, 0.55)
			var buy_id := id
			var buy_cost := cost
			var cbtn := _stone_btn(str(cost) + " coins", BTN_GREEN, coin_col, func():
				if SaveManager.spend_coins(buy_cost):
					AudioManager.play("collect")
					SaveManager.add_owned_pack(buy_id)
					SaveManager.set_selected_pack(buy_id)
					_rebuild())
			cbtn.disabled = not can
			row.add_child(cbtn)
		var iap_id := id
		row.add_child(_stone_btn(Cosmetics.price_of(id), BTN_BLUE, Palette.WARN, func():
			MonetizationManager.purchase(Cosmetics.product_of(iap_id), func(_p: String):
				SaveManager.add_owned_pack(iap_id)
				SaveManager.set_selected_pack(iap_id)
				_rebuild())))
	return wrap


# ── Remove Ads row ────────────────────────────────────────────────────────────
func _remove_ads_row() -> Control:
	var wrap := _row_wrap()
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 10)
	wrap.add_child(row)

	var icon := TextureRect.new()
	icon.texture = SHIELD_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_l := Label.new()
	name_l.text = "Remove Ads"
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	name_l.add_theme_constant_override("outline_size", 4)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_l)

	var desc_l := Label.new()
	desc_l.text = "Play every match uninterrupted"
	desc_l.add_theme_font_size_override("font_size", 13)
	desc_l.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	desc_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	desc_l.add_theme_constant_override("outline_size", 3)
	desc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(desc_l)

	if SaveManager.has_remove_ads():
		row.add_child(_tag("OWNED", Palette.SAFE))
	else:
		row.add_child(_stone_btn("$2.99", BTN_BLUE, Palette.WARN, func():
			MonetizationManager.purchase("remove_ads", func(_p: String): _rebuild())))
	return wrap


# ── Helpers ───────────────────────────────────────────────────────────────────

func _row_wrap() -> PanelContainer:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.corner_radius_top_left     = 10
	sb.corner_radius_top_right    = 10
	sb.corner_radius_bottom_left  = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left   = 10
	sb.content_margin_right  = 10
	sb.content_margin_top    = 6
	sb.content_margin_bottom = 6
	wrap.add_theme_stylebox_override("panel", sb)
	return wrap


func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Palette.WARN)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _frame_style(content_margin: int) -> StyleBoxTexture:
	var st := StyleBoxTexture.new()
	st.texture = PANEL_FRAME
	st.texture_margin_left   = 20
	st.texture_margin_right  = 20
	st.texture_margin_top    = 20
	st.texture_margin_bottom = 20
	st.set_content_margin_all(content_margin)
	return st


func _stone_btn(text: String, frame: Texture2D, text_color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_stylebox_override("normal",   _btn_sbox(frame, Color.WHITE))
	b.add_theme_stylebox_override("hover",    _btn_sbox(frame, Color(1.0, 1.0, 0.8)))
	b.add_theme_stylebox_override("pressed",  _btn_sbox(frame, Color(0.72, 0.72, 0.72)))
	b.add_theme_stylebox_override("disabled", _btn_sbox(frame, Color(0.38, 0.38, 0.38, 0.55)))
	b.custom_minimum_size = Vector2(134, 44)
	b.pressed.connect(cb)
	return b


func _btn_sbox(frame: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = frame
	sb.modulate_color = tint
	sb.texture_margin_left   = 34
	sb.texture_margin_right  = 34
	sb.texture_margin_top    = 34
	sb.texture_margin_bottom = 34
	sb.set_content_margin_all(8)
	return sb


func _tag(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(110, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _divider() -> Control:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, 0.12)
	d.custom_minimum_size = Vector2(0, 2)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d
