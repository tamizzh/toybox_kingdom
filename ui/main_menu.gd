extends Control

# Toybox Kingdoms front screen: a big centred logo, a row of rival ruler crests,
# and one dominant PLAY button over a bright toy-box background. This is the app's
# boot scene — PLAY launches the territory match directly. SHOP / SETTINGS sit
# quietly in the top-right corner; coins/level chip in the top-left.

const Roster := preload("res://toybox_kingdoms/data/roster.gd")
const KINGDOM_MATCH := "res://toybox_kingdoms/kingdom_match.tscn"
const ROSTER_PREVIEW := 5        # crests shown in the rival row

var _coin_label: Label
var _hook_label: Label


func _ready() -> void:
	AudioManager.play_music("menu")

	# Pre-compile the match's custom shaders while the player is on the menu, so the
	# board's first frame doesn't stall compiling them (the main load hitch on mobile).
	add_child(load("res://toybox_kingdoms/tools/shader_warmup.gd").new())

	_build_background()

	_build_top_buttons()
	_build_currency_chip()
	_build_logo()

	var col := _play_row()
	col.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	col.offset_top = -210
	col.offset_bottom = -36
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_refresh_hook()

	# First launch: show the how-to-play tutorial (marks onboarding done when finished).
	if not SaveManager.onboarding_done():
		_open_overlay(load("res://ui/onboarding_screen.gd").new())
	else:
		# Returning player: grant the once-a-day login bonus (a reason to come back).
		var bonus := SaveManager.claim_daily_if_due(50)
		if bonus > 0:
			_show_daily(bonus)


# Floating "welcome back" reward toast, centred near the top, that rises and fades.
func _show_daily(bonus: int) -> void:
	var l := Label.new()
	l.text = "Daily reward!  +%d coins" % bonus
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Palette.WARN)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 96
	l.z_index = 20
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	AudioManager.play("collect")
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(l, "offset_top", 72.0, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


# Open a full-screen overlay in its own high CanvasLayer so it sits ABOVE all menu
# chrome (which uses z_index=12). The layer is freed when the overlay closes.
func _open_overlay(node: Control) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	layer.add_child(node)
	node.tree_exited.connect(layer.queue_free)


# ── Background ─────────────────────────────────────────────────────────────────
# Prefer the painted toybox-kingdom splash art (logo + tagline are baked in); fall
# back to the procedural wash when the PNG hasn't been imported yet.
#
# The splash is 16:9 but the menu frame is wider (1560×720 ≈ 2.17:1), so showing the
# whole poster leaves gaps on the sides. We fill them with a dimmed, zoomed copy of
# the same art (so the sides read as an intentional backdrop, not flat bars) and lay
# the full, un-cropped poster on top, centred.
func _build_background() -> void:
	var bg_tex := AssetKit.tex("res://assets/main_menu_bg")
	if bg_tex == null:
		var bg := _BG.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		return

	# The hero poster cover-cropped to FILL the whole screen on any aspect (no bars,
	# no dimmed margins). The title sits in the centre safe-zone so the crop never
	# eats it. A slow Ken Burns zoom keeps the title screen feeling alive.
	var photo := TextureRect.new()
	photo.texture = bg_tex
	photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(photo)
	_ken_burns(photo, 1.035, 9.0)

	# Drifting confetti above the art (below all chrome) for constant gentle motion.
	var confetti := _Confetti.new()
	confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(confetti)

	# Top scrim: dark gradient behind the chrome bar so coins/buttons are always legible.
	var top_scrim := _GradientRect.new()
	top_scrim.from_color = Color(0.05, 0.03, 0.12, 0.72)
	top_scrim.to_color   = Color(0.05, 0.03, 0.12, 0.0)
	top_scrim.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_scrim.offset_bottom = 110
	top_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_scrim)

	# Bottom scrim: darker gradient so the PLAY button + hint text stay legible.
	var bot_scrim := _GradientRect.new()
	bot_scrim.from_color = Color(0.05, 0.03, 0.12, 0.0)
	bot_scrim.to_color   = Color(0.05, 0.03, 0.12, 0.55)
	bot_scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_scrim.offset_top = -220
	bot_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot_scrim)


# ── Logo overlay ──────────────────────────────────────────────────────────────
func _build_logo() -> void:
	var logo_tex := AssetKit.tex("res://assets/logo")
	if logo_tex == null:
		return
	var logo := TextureRect.new()
	logo.texture = logo_tex
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Anchor top-wide, sized so the logo sits comfortably below the chrome bar.
	# Place logo in the top half, well below the 76px chrome bar, centered.
	# anchor_top=0.08 keeps it below chrome; anchor_bottom=0.55 gives it room.
	logo.anchor_left   = 0.1
	logo.anchor_right  = 0.9
	logo.anchor_top    = 0.06
	logo.anchor_bottom = 0.52
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.z_index = 5
	add_child(logo)


# ── Top-right SHOP / SETTINGS ──────────────────────────────────────────────────
func _build_top_buttons() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.position = Vector2(Palette.DESIGN_W - 500, 22)
	bar.z_index = 12
	add_child(bar)
	bar.add_child(_menu_btn("HOW TO PLAY", Palette.PLAYER_COLORS[1], func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/onboarding_screen.gd").new()), 176))
	bar.add_child(_menu_btn("SHOP", Palette.WARN, func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/shop_screen.gd").new())))
	bar.add_child(_menu_btn("SETTINGS", Palette.NEUTRAL, func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/settings_screen.gd").new())))


# ── Top-left coins / level chip (opens the profile/stats panel) ───────────────────
func _build_currency_chip() -> void:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2(24, 22)
	btn.custom_minimum_size = Vector2(232, 46)
	btn.size = Vector2(232, 46)
	btn.z_index = 12
	btn.add_theme_stylebox_override("normal", _panel_style(Color(0, 0, 0, 0.30), Color(Palette.WARN, 0.6), 16, 2, 12))
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0, 0, 0, 0.42), Palette.WARN, 16, 2, 12))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0, 0, 0, 0.52), Palette.WARN, 16, 2, 12))
	add_child(btn)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color.WHITE)
	_coin_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(_coin_label)
	_refresh_currency()

	SaveManager.coins_changed.connect(_on_coins_changed)
	btn.pressed.connect(func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/profile_screen.gd").new()))


func _on_coins_changed(_total: int) -> void:
	_refresh_currency()
	_refresh_hook()


func _refresh_currency() -> void:
	if _coin_label:
		_coin_label.text = "LV %d     %d COINS" % [SaveManager.level(), SaveManager.coins()]


func _menu_btn(text: String, color: Color, cb: Callable, width: int = 140) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _panel_style(Color(color, 0.20), color, 16, 2, 14))
	b.add_theme_stylebox_override("hover", _panel_style(Color(color, 0.40), color, 16, 2, 14))
	b.add_theme_stylebox_override("pressed", _panel_style(Color(color, 0.55), color, 16, 2, 14))
	b.custom_minimum_size = Vector2(width, 46)
	b.pressed.connect(cb)
	return b


# ── Logo ───────────────────────────────────────────────────────────────────────
func _logo_node() -> Control:
	# Prefer dedicated Toybox Kingdoms logo art if dropped in; otherwise draw the
	# branded text lockup. (The legacy assets/ui/menu_logo.png is the old Party Pals
	# logo, so we intentionally do not fall back to it.)
	var logo_tex := AssetKit.tex(AssetKit.UI + "kingdom_logo")

	if logo_tex == null:
		var fallback := _title_lockup()
		fallback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return fallback

	var logo := TextureRect.new()
	logo.texture = logo_tex
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(640, 210)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return logo


func _title_lockup() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", -10)

	var toybox := Label.new()
	toybox.text = "TOYBOX"
	toybox.add_theme_font_size_override("font_size", 92)
	toybox.add_theme_color_override("font_color", Color.WHITE)
	toybox.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	toybox.add_theme_constant_override("outline_size", 10)
	toybox.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toybox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(toybox)

	var kingdoms := Label.new()
	kingdoms.text = "KINGDOMS"
	kingdoms.add_theme_font_size_override("font_size", 92)
	kingdoms.add_theme_color_override("font_color", Palette.WARN)
	kingdoms.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	kingdoms.add_theme_constant_override("outline_size", 10)
	kingdoms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kingdoms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(kingdoms)

	return wrap


# ── Rival ruler crest row ────────────────────────────────────────────────────────
func _roster_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.size_flags_horizontal = Control.SIZE_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in ROSTER_PREVIEW:
		row.add_child(_crest(i))
	return row


func _crest(i: int) -> Control:
	var bob := _Bobber.new()
	bob.custom_minimum_size = Vector2(150, 132)
	bob.phase = float(i) * 0.7
	bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crest := _Crest.new()
	crest.accent = _kingdom_color(i)
	crest.ruler_name = String(Roster.info(i)["name"])
	crest.size = Vector2(150, 124)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bob.add_child(crest)
	bob.face = crest
	return bob


# Mirror of KingdomMatch._kingdom_color so menu crests match in-game banner colors.
func _kingdom_color(i: int) -> Color:
	return Color.from_hsv(fmod(0.02 + float(i) / float(Roster.RULERS.size()), 1.0), 0.85, 0.92)


# ── PLAY ─────────────────────────────────────────────────────────────────────────
func _play_row() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	wrap.size_flags_horizontal = Control.SIZE_FILL

	var play := _PlayButton.new()
	play.custom_minimum_size = Vector2(420, 104)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play)
	wrap.add_child(play)

	var hint := Label.new()
	hint.text = "Claim land · conquer every rival · or hold 50% at the buzzer"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(Palette.NEUTRAL, 0.9))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_FILL
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hint)

	_hook_label = Label.new()
	_hook_label.add_theme_font_size_override("font_size", 18)
	_hook_label.add_theme_color_override("font_color", Color(Palette.WARN, 0.96))
	_hook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hook_label.size_flags_horizontal = Control.SIZE_FILL
	_hook_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_hook_label)
	return wrap


func _on_play() -> void:
	AudioManager.play("tap")
	# PLAY opens the campaign map — the conquest ladder is the spine; the player
	# launches their current stage from there (CONQUER button).
	_open_overlay(load("res://ui/campaign_screen.gd").new())


func _refresh_hook() -> void:
	if not _hook_label:
		return
	# The campaign ladder is the headline pull — show where the player is on it.
	var Campaign := preload("res://toybox_kingdoms/data/campaign.gd")
	if SaveManager.campaign_complete():
		_hook_label.text = "Campaign complete!  You rule the toybox 👑"
		return
	var stage := SaveManager.active_stage()
	_hook_label.text = "CONQUEST  %d/%d   ·   Next: %s" % [
		stage + 1, Campaign.count(), Campaign.title(stage)]


# ── Helpers ───────────────────────────────────────────────────────────────────────
# Cinematic "Ken Burns" loop: scale a full-rect layer gently in and out from its
# centre, forever. Pivot is kept at the layer's centre as it (re)sizes so the zoom
# never drifts off-frame. `peak` is the max scale, `secs` one half-cycle's duration.
func _ken_burns(node: Control, peak: float, secs: float) -> void:
	var recentre := func() -> void: node.pivot_offset = node.size * 0.5
	node.resized.connect(recentre)
	recentre.call()
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(peak, peak), secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _panel_style(bg: Color, border: Color, radius: int, border_width: int, padding: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_width
	s.border_width_right = border_width
	s.border_width_top = border_width
	s.border_width_bottom = border_width
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s


# ── Crest idle bob ───────────────────────────────────────────────────────────────
class _Bobber extends Control:
	var face: Control
	var phase: float = 0.0
	var _t: float = 0.0
	func _process(delta: float) -> void:
		_t += delta
		if face:
			face.position.y = 4.0 + sin(_t * 2.2 + phase) * 5.0


# ── Bright toy-box background ────────────────────────────────────────────────────
class _BG extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Vertical-ish wash: deep indigo base with playful colour blobs.
		draw_rect(Rect2(Vector2.ZERO, size), Color("221a45"))
		draw_rect(Rect2(0, 0, w, h * 0.5), Color("2c2358"))
		draw_circle(Vector2(w * 0.16, h * 0.20), 200.0, Color(Palette.PLAYER_COLORS[1], 0.16))
		draw_circle(Vector2(w * 0.84, h * 0.18), 240.0, Color(Palette.PLAYER_COLORS[0], 0.14))
		draw_circle(Vector2(w * 0.78, h * 0.82), 280.0, Color(Palette.PLAYER_COLORS[2], 0.12))
		draw_circle(Vector2(w * 0.20, h * 0.80), 230.0, Color(Palette.PLAYER_COLORS[3], 0.12))
		draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color(0, 0, 0, 0.10))

		var step := 44.0
		var dot_color := Color(Palette.ACCENT, 0.05)
		for ccol in int(w / step) + 2:
			for crow in int(h / step) + 2:
				draw_circle(Vector2(ccol * step + 8, crow * step + 8), 1.4, dot_color)


# ── Rival crest: a kingdom-colour banner card with a crown and the ruler's name. ──
class _Crest extends Control:
	var accent: Color = Color.WHITE
	var ruler_name: String = ""

	func _draw() -> void:
		var card_rect := Rect2(0, 0, size.x, size.y - 26)
		DrawKit.card(self, card_rect, 20.0, Color(accent, 0.32), 3.0, true)
		# kingdom banner stripe
		draw_rect(Rect2(6, 6, size.x - 12, 8), accent)
		DrawKit.crown(self, Vector2(size.x * 0.5, card_rect.size.y * 0.56), size.x * 0.46, accent)
		var tw := ArcadeTheme.font.get_string_size(ruler_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(ArcadeTheme.font, Vector2((size.x - tw) * 0.5, size.y - 4), ruler_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)


# ── Drifting confetti layer ──────────────────────────────────────────────────────
# A sparse field of slow-falling, tumbling paper bits in the kingdom colours. Pure
# procedural draw (no textures); wraps each piece to the top when it leaves the
# bottom so the field loops seamlessly. Kept faint so it accents, never distracts.
class _Confetti extends Control:
	const COUNT := 40
	var _bits: Array = []

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		var pal: Array = Palette.PLAYER_COLORS
		for i in COUNT:
			_bits.append({
				"x": randf(),                                   # 0..1 across width
				"y": randf(),                                   # 0..1 down height
				"vy": randf_range(18.0, 46.0),                  # px/sec fall speed
				"sway": randf_range(8.0, 22.0),                 # px horizontal swing
				"freq": randf_range(0.5, 1.4),
				"phase": randf_range(0.0, TAU),
				"spin": randf_range(-2.2, 2.2),
				"rot": randf_range(0.0, TAU),
				"w": randf_range(7.0, 14.0),
				"h": randf_range(4.0, 9.0),
				"color": Color(pal[i % pal.size()], randf_range(0.5, 0.85)),
			})

	func _process(delta: float) -> void:
		var h := size.y
		for b in _bits:
			b["y"] += b["vy"] * delta / max(h, 1.0)
			b["rot"] += b["spin"] * delta
			b["phase"] += b["freq"] * delta
			if b["y"] > 1.08:
				b["y"] = -0.08
				b["x"] = randf()
		queue_redraw()

	func _draw() -> void:
		for b in _bits:
			var px: float = b["x"] * size.x + sin(b["phase"]) * b["sway"]
			var py: float = b["y"] * size.y
			draw_set_transform(Vector2(px, py), b["rot"], Vector2.ONE)
			var w: float = b["w"]
			var hh: float = b["h"]
			draw_rect(Rect2(-w * 0.5, -hh * 0.5, w, hh), b["color"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Vertical gradient rect (top-to-bottom) ──────────────────────────────────────
class _GradientRect extends Control:
	var from_color: Color = Color(0, 0, 0, 0.6)
	var to_color:   Color = Color(0, 0, 0, 0.0)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), from_color)
		# Simulate gradient by drawing thin horizontal strips.
		var steps := 32
		for i in steps:
			var t := float(i) / float(steps)
			var c := from_color.lerp(to_color, t)
			var y := t * size.y
			var h := size.y / float(steps) + 1.0
			draw_rect(Rect2(0, y, size.x, h), c)


class _PlayButton extends Button:
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		# Gentle "press me" pulse so the eye lands on PLAY. Pivot stays centred.
		var recentre := func() -> void: pivot_offset = size * 0.5
		resized.connect(recentre)
		recentre.call()
		var tw := create_tween().set_loops()
		tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _draw() -> void:
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 30.0, Palette.SAFE, 4.0, true)
		var fsize := 38
		var label := "PLAY"
		var tw := ArcadeTheme.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var cx := size.x * 0.5
		# play glyph (triangle) sits to the left of the centred word
		var gx := cx - tw * 0.5 - 34.0
		var gy := size.y * 0.5
		draw_polygon(
			PackedVector2Array([
				Vector2(gx - 4, gy - 18), Vector2(gx + 22, gy), Vector2(gx - 4, gy + 18),
			]),
			PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
		)
		draw_string(
			ArcadeTheme.font,
			Vector2(cx - tw * 0.5 + 6, size.y * 0.5 + fsize * 0.36),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE
		)
