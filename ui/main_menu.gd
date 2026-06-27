extends Control

# Toybox Kingdoms front screen: a big centred logo, a row of rival ruler crests,
# and one dominant PLAY button over a bright toy-box background. This is the app's
# boot scene — PLAY launches the territory match directly. SHOP / SETTINGS sit
# quietly in the top-right corner; coins/level chip in the top-left.

const Roster := preload("res://toybox_kingdoms/data/roster.gd")
const KINGDOM_MATCH := "res://toybox_kingdoms/kingdom_match.tscn"
const ROSTER_PREVIEW := 5        # crests shown in the rival row

var _coin_label: Label
var _hook_label: Button


func _ready() -> void:
	# Cold-open: a brand-new player drops STRAIGHT into their first match — action in
	# seconds, no menu/PLAY/stage taps to read past. The in-match coach teaches the loop,
	# so we also mark the how-to slideshow seen (no double-teaching). After that first
	# match the results screen's MAIN MENU brings them here as normal.
	if _should_cold_open():
		SaveManager.set_onboarding_done(true)
		SaveManager.set_mode("campaign")
		# Deferred: the menu node is still being added to the tree here, so swapping the
		# scene synchronously trips "parent is busy adding/removing children".
		get_tree().change_scene_to_file.call_deferred(KINGDOM_MATCH)
		return

	AudioManager.play_music("menu")
	add_child(load("res://toybox_kingdoms/tools/shader_warmup.gd").new())

	_build_background()  # cover-cropped art + scrims
	_build_logo()        # logo centered upper area
	_build_currency_chip() # coin bar top-left
	_build_bottom_dock() # icon buttons + PLAY

	_refresh_hook()

	if not SaveManager.onboarding_done():
		_open_overlay(load("res://ui/onboarding_screen.gd").new())
	else:
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


# ── Bottom dock: icon buttons row + PLAY + campaign text ─────────────────────
func _build_bottom_dock() -> void:
	# Icon buttons row: SHOP · REWARDS · HOW TO PLAY · SETTINGS
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 20)
	icon_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	icon_row.offset_top    = -320
	icon_row.offset_bottom = -204
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.z_index = 12
	add_child(icon_row)
	icon_row.add_child(_atlas_icon_btn("shop", func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/shop_screen.gd").new())))
	icon_row.add_child(_atlas_icon_btn("rewards", func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/daily_screen.gd").new())))
	icon_row.add_child(_atlas_icon_btn("howtoplay", func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/onboarding_screen.gd").new())))
	icon_row.add_child(_atlas_icon_btn("settings", func() -> void:
		AudioManager.play("tap")
		_open_overlay(load("res://ui/settings_screen.gd").new())))

	# PLAY button (campaign) — wide, prominent, centered
	var play := _PlayButton.new()
	play.custom_minimum_size = Vector2(460, 110)
	play.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	play.offset_top    = -200
	play.offset_bottom = -90
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play)
	play.z_index = 12
	add_child(play)

	# ENDLESS button — the score-attack retention loop, a secondary action under PLAY.
	# Shows your best so the chase is visible right on the menu.
	var endless := Button.new()
	endless.text = "CONQUER RUSH"
	endless.focus_mode = Control.FOCUS_NONE
	endless.add_theme_font_size_override("font_size", 24)
	endless.add_theme_color_override("font_color", Color.WHITE)
	endless.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	endless.add_theme_constant_override("outline_size", 5)
	var ec := Color("6a3fb0")   # regal purple, distinct from the gold PLAY
	endless.add_theme_stylebox_override("normal", _panel_style(Color(ec, 0.92), Color(ec.lightened(0.2), 0.9), 18, 2, 8))
	endless.add_theme_stylebox_override("hover", _panel_style(ec.lightened(0.12), Color(ec.lightened(0.3), 0.9), 18, 2, 8))
	endless.add_theme_stylebox_override("pressed", _panel_style(ec.darkened(0.15), Color(ec, 0.9), 18, 2, 8))
	endless.anchor_left = 0.5; endless.anchor_right = 0.5
	endless.anchor_top = 1.0; endless.anchor_bottom = 1.0
	endless.offset_left = -170; endless.offset_right = 170
	endless.offset_top = -82; endless.offset_bottom = -40
	endless.z_index = 12
	endless.pressed.connect(_on_endless)
	add_child(endless)

	# Campaign hook — tappable progress line that opens the conquest ladder. Styled as
	# flat text (no button chrome) so it reads as a hint, but it's a real tap target now
	# that PLAY skips the stage-select overlay.
	_hook_label = Button.new()
	_hook_label.flat = true
	_hook_label.focus_mode = Control.FOCUS_NONE
	_hook_label.add_theme_font_size_override("font_size", 17)
	_hook_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
	_hook_label.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1.0))
	_hook_label.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.7))
	_hook_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hook_label.add_theme_constant_override("outline_size", 6)
	var flat_sb := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		_hook_label.add_theme_stylebox_override(st, flat_sb)
	_hook_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hook_label.offset_top    = -34
	_hook_label.offset_bottom = -6
	_hook_label.z_index = 12
	_hook_label.pressed.connect(_open_campaign)
	add_child(_hook_label)


# ENDLESS button caption — shows the best score once the player has set one.
func _endless_label() -> String:
	var best := SaveManager.endless_best()
	return ("ENDLESS  ·  BEST %s" % best) if best > 0 else "ENDLESS"


# ── Top-left coin bar (atlas coinbar + label) ─────────────────────────────────
func _build_currency_chip() -> void:
	var btn := TextureButton.new()
	btn.focus_mode = Control.FOCUS_NONE
	var tex := AssetKit.tex("res://assets/ui/buttons/coinbar")
	if tex:
		btn.texture_normal = tex
		btn.texture_hover  = tex
		btn.texture_pressed = tex
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn.offset_left   = 14
	btn.offset_top    = 14
	btn.offset_right  = 254
	btn.offset_bottom = 76
	btn.z_index = 12
	add_child(btn)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 17)
	_coin_label.add_theme_color_override("font_color", Color(0.35, 0.22, 0.04))
	_coin_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.5))
	_coin_label.add_theme_constant_override("outline_size", 4)
	_coin_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_label.offset_left = 48
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
		_coin_label.text = "LV %d  •  %d" % [SaveManager.level(), SaveManager.coins()]


func _atlas_icon_btn(name: String, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.focus_mode = Control.FOCUS_NONE
	var tex := AssetKit.tex("res://assets/ui/buttons/" + name)
	if tex:
		b.texture_normal  = tex
		b.texture_hover   = tex
		b.texture_pressed = tex
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# Clear any theme styleboxes so no gray box appears
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", empty)
	b.add_theme_stylebox_override("pressed", empty)
	b.add_theme_stylebox_override("focus", empty)
	b.custom_minimum_size = Vector2(130, 130)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


func _on_play() -> void:
	AudioManager.play("tap")
	SaveManager.set_mode("timed")
	SaveManager.endless_run_reset()
	get_tree().change_scene_to_file(KINGDOM_MATCH)


func _on_endless() -> void:
	# CONQUER RUSH — the campaign conquest ladder.
	AudioManager.play("tap")
	SaveManager.set_mode("campaign")
	get_tree().change_scene_to_file(KINGDOM_MATCH)


func _open_campaign() -> void:
	AudioManager.play("tap")
	_open_overlay(load("res://ui/campaign_screen.gd").new())


# True only for a never-played install. TBK_COLDOPEN=1 forces it for QA; TBK_NO_COLDOPEN=1
# disables it (so the menu can be inspected on a fresh save).
func _should_cold_open() -> bool:
	if OS.get_environment("TBK_NO_COLDOPEN") == "1":
		return false
	if OS.get_environment("TBK_COLDOPEN") == "1":
		return true
	return SaveManager.stat("matches_played") == 0


func _refresh_hook() -> void:
	if not _hook_label:
		return
	# The campaign ladder is the headline pull — show where the player is on it.
	var Campaign := preload("res://toybox_kingdoms/data/campaign.gd")
	if SaveManager.campaign_complete():
		_hook_label.text = "Campaign complete!  You rule the toybox 👑"
		return
	var stage := SaveManager.active_stage()
	_hook_label.text = "CONQUEST  %d/%d   ·   Next: %s   ›" % [
		stage + 1, Campaign.count(), Campaign.title(stage)]


# ── Helpers ───────────────────────────────────────────────────────────────────────
# Cinematic "Ken Burns" loop: scale a full-rect layer gently in and out from its
# centre, forever. Pivot is kept at the layer's centre as it (re)sizes so the zoom
# never drifts off-frame. `peak` is the max scale, `secs` one half-cycle's duration.
func _ken_burns(node: Control, peak: float, secs: float) -> void:
	var recentre := func() -> void:
		node.pivot_offset = Vector2(node.get_viewport().size) * 0.5
	node.resized.connect(recentre)
	recentre.call()
	# Cosine oscillation: scale = 1.0 + (peak-1) * (1 - cos(t·2π)) / 2
	# gives perfectly continuous velocity — no jerk at the zoom reversal.
	# secs is the half-period so the full in-out cycle takes secs*2.
	var set_scale := func(t: float) -> void:
		var s := 1.0 + (peak - 1.0) * (1.0 - cos(t * TAU)) * 0.5
		node.scale = Vector2(s, s)
	var tw := node.create_tween().set_loops()
	tw.tween_method(set_scale, 0.0, 1.0, secs * 2.0)


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


class _PlayButton extends TextureButton:
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		ignore_texture_size = true
		stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var tex := AssetKit.tex("res://assets/ui/buttons/play")
		if tex:
			texture_normal  = tex
			texture_hover   = tex
			texture_pressed = tex
		# Gentle "press me" pulse.
		var recentre := func() -> void: pivot_offset = size * 0.5
		resized.connect(recentre)
		await get_tree().process_frame
		recentre.call()
		var tw := create_tween().set_loops()
		tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
