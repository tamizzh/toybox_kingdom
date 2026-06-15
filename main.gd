extends Node

# Root view controller. Swaps screens in ScreenHost; keeps HUD + touch persistent.
# Flow: MainMenu → GameGrid → (game plays) → GameGrid → … → MatchResults → MainMenu

@onready var screen_host: Node = $ScreenHost
@onready var hud: Control = $UILayer/HUD
@onready var touch: Control = $TouchLayer/TouchControls

const MAIN_MENU := preload("res://ui/main_menu.tscn")
const GAME_GRID := preload("res://ui/game_grid.tscn")
const RESULTS  := preload("res://ui/results_screen.tscn")

func _ready() -> void:
	GameManager.match_started.connect(_on_match_started)
	GameManager.show_game_grid.connect(_on_show_game_grid)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_result.connect(_on_round_result)
	GameManager.match_finished.connect(_on_match_finished)
	GameManager.returned_to_menu.connect(show_menu)
	show_menu()
	_maybe_show_consent()

# First-run ad/data consent gate (GDPR/ATT). Real SDK consent is wired in
# MonetizationManager.mark_consent(); this is the player-facing prompt.
func _maybe_show_consent() -> void:
	if not MonetizationManager.needs_consent():
		return
	var ov := ColorRect.new()
	ov.color = Color(0.02, 0.03, 0.08, 0.88)
	ov.anchor_right = 1.0
	ov.anchor_bottom = 1.0
	ov.z_index = 200
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	$UILayer.add_child(ov)

	var msg := Label.new()
	msg.text = "Party Pals Arena is free, supported by ads.\nYou can remove ads anytime in the Shop."
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size = Vector2(820, 120)
	msg.position = Vector2(Palette.CENTER_X - 410, Palette.DESIGN_H * 0.5 - 130)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(msg)

	var btn := Button.new()
	btn.text = "AGREE & CONTINUE"
	btn.add_theme_font_size_override("font_size", 28)
	btn.size = Vector2(380, 72)
	btn.position = Vector2(Palette.CENTER_X - 190, Palette.DESIGN_H * 0.5 + 30)
	btn.pressed.connect(func() -> void:
		MonetizationManager.mark_consent(true)
		AudioManager.play("tap")
		ov.queue_free()
		_after_menu_shown())   # continue first-run flow: onboarding, then daily
	ov.add_child(btn)

# First open of the day grants a coin bonus — a cheap, proven retention hook.
func _maybe_show_daily() -> void:
	if MonetizationManager.needs_consent():
		return   # don't stack on the first-run consent prompt; claim next open
	var bonus := SaveManager.claim_daily_if_due()
	if bonus <= 0:
		return

	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.03, 0.09, 0.0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 150
	$UILayer.add_child(overlay)

	var card := _DailyCard.new()
	card.bonus = bonus
	card.size = Vector2(560, 240)
	card.position = Vector2(Palette.CENTER_X - 280, Palette.DESIGN_H * 0.5 - 120)
	card.pivot_offset = Vector2(280, 120)
	card.scale = Vector2(0.4, 0.4)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(card)

	AudioManager.play("round_win")
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.7, 0.2)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.34) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var dismiss := func(_e = null) -> void:
		if not is_instance_valid(overlay):
			return
		var t := overlay.create_tween()
		t.tween_property(overlay, "modulate:a", 0.0, 0.25)
		t.tween_callback(overlay.queue_free)
	overlay.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			dismiss.call())
	get_tree().create_timer(3.5).timeout.connect(func() -> void: dismiss.call())


# ------------------------------------------------------------------ screen swap

func _clear_host() -> void:
	for c in screen_host.get_children():
		c.queue_free()

func _swap(new_screen: Node) -> void:
	_clear_host()
	new_screen.modulate.a = 0.0
	screen_host.add_child(new_screen)
	var tw := create_tween()
	tw.tween_property(new_screen, "modulate:a", 1.0, 0.18)

func show_menu() -> void:
	hud.visible = false
	touch.visible = false
	AudioManager.play_music("menu")
	_swap(MAIN_MENU.instantiate())
	_after_menu_shown()

# First-run sequencing so popups never stack: consent → onboarding → daily reward.
func _after_menu_shown() -> void:
	if MonetizationManager.needs_consent():
		return   # consent prompt (shown from _ready) calls back here once agreed
	if not SaveManager.onboarding_done():
		$UILayer.add_child(load("res://ui/onboarding_screen.gd").new())
		return
	_maybe_show_daily()

# ------------------------------------------------------------------ game manager signals

func _on_match_started() -> void:
	hud.setup(GameManager.players)
	touch.setup(GameManager.players)

func _on_show_game_grid() -> void:
	hud.visible = false
	touch.visible = false
	_swap(GAME_GRID.instantiate())

func _on_round_started(game: Node) -> void:
	_clear_host()
	AudioManager.play_music("game")
	screen_host.add_child(game)

	# Solo "vs CPU": drive any AI players through InputManager (works for every game).
	var ai_ids: Array = []
	for p in GameManager.players:
		if p.is_ai:
			ai_ids.append(p.id)
	if not ai_ids.is_empty():
		var ai := AIController.new()
		game.add_child(ai)
		ai.setup(game, ai_ids, GameManager.last_difficulty)
	# 2D games fade in via modulate; 3D games (Node3D) have no modulate and just
	# appear (their Camera3D becomes current once added to the tree).
	if game is CanvasItem:
		game.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(game, "modulate:a", 1.0, 0.18)
	else:
		# 3D games have no modulate — settle them in with a quick screen fade so
		# the round start feels intentional rather than a hard cut.
		_round_intro_fade()
	game.time_changed.connect(hud.set_time)
	game.status_changed.connect(hud.set_status)
	hud.set_status(game.game_title)
	if hud.has_method("set_subtitle"):
		hud.set_subtitle(game.tagline if "tagline" in game else "")
	hud.set_time(game.round_duration)
	if touch.has_method("set_action_label"):
		touch.set_action_label(game.action_label if "action_label" in game else "ACTION")
	hud.visible = true
	touch.visible = true

func _round_intro_fade() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0.09, 0.07, 0.18, 1.0)
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.z_index = 50
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.4)
	tw.tween_callback(fade.queue_free)

func _on_round_result(results: Dictionary, _title: String) -> void:
	hud.flash_round_result(results)
	_show_winner_overlay(results)

func _on_match_finished(winner_id: int) -> void:
	hud.visible = false
	touch.visible = false
	AudioManager.play_music("menu")
	AudioManager.play("win")
	var rs := RESULTS.instantiate()
	_swap(rs)
	rs.show_match_winner(winner_id, GameManager.players)

# ------------------------------------------------------------------ winner overlay

func _show_winner_overlay(results: Dictionary) -> void:
	var best := -1
	var winner_id := -1
	for id in results:
		if int(results[id]) > best:
			best = int(results[id])
			winner_id = id
	if winner_id < 0 or best <= 0:
		return

	var pts          := int(best)
	var winner_color := Palette.player_color(winner_id)
	var winner_name  := Palette.player_name(winner_id)
	var pt_text      := "+%d POINT" % pts if pts == 1 else "+%d POINTS" % pts

	# Dark semi-transparent backdrop
	var overlay := ColorRect.new()
	overlay.color         = Color(0.04, 0.04, 0.10, 0.0)
	overlay.anchor_right  = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	overlay.z_index       = 100
	$UILayer.add_child(overlay)

	# Winner-colour horizontal flash strip
	var strip := ColorRect.new()
	strip.color        = Color(winner_color, 0.18)
	strip.size         = Vector2(Palette.DESIGN_W, 240)
	strip.position     = Vector2(0, Palette.DESIGN_H * 0.5 - 120)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(strip)

	# Drawn crown + "P1 WINS!" — big, bouncy with drop shadow
	var hy := Palette.DESIGN_H * 0.5
	var cx := Palette.DESIGN_W * 0.5
	var crown := _CrownIcon.new()
	crown.fill = winner_color
	crown.size = Vector2(150, 110)
	crown.position = Vector2(cx - 75, hy - 200)
	crown.pivot_offset = Vector2(75, 90)
	crown.scale = Vector2(0.3, 0.3)
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(crown)
	_shadow_label("%s WINS!" % winner_name, 82, overlay,
				  Vector2(0, hy - 80), Vector2(Palette.DESIGN_W, 100))
	var crown_l := _plain_label("%s WINS!" % winner_name, 82, overlay,
								Vector2(0, hy - 80), Vector2(Palette.DESIGN_W, 100))
	crown_l.add_theme_color_override("font_color", winner_color)
	crown_l.pivot_offset = Vector2(cx, 50)
	crown_l.scale        = Vector2(0.3, 0.3)

	# "+1 POINT"
	_shadow_label(pt_text, 44, overlay, Vector2(0, hy + 36), Vector2(Palette.DESIGN_W, 56))
	var pt_l := _plain_label(pt_text, 44, overlay,
							 Vector2(0, hy + 36), Vector2(Palette.DESIGN_W, 56))
	pt_l.add_theme_color_override("font_color", Palette.WARN)

	# Confetti sprinkle for extra celebration
	var conf_colors := [Color("f02828"), Color("1878f0"), Color("10b83c"),
		Color("f5c018"), Color("f040a0"), Color("40e0ff")]
	for _i in 22:
		var cr := ColorRect.new()
		cr.color = conf_colors[randi() % conf_colors.size()]
		cr.size = Vector2(randf_range(9, 18), randf_range(6, 12))
		cr.position = Vector2(randf_range(0, Palette.DESIGN_W), randf_range(-40, hy - 40))
		cr.pivot_offset = cr.size * 0.5
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(cr)
		var ctw := cr.create_tween()
		var dur := randf_range(1.0, 1.9)
		ctw.tween_property(cr, "position:y", Palette.DESIGN_H + 30, dur)
		ctw.parallel().tween_property(cr, "rotation", randf_range(-TAU, TAU), dur)

	# Backdrop fade-in, text bounce, then fade-out
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.72, 0.18)
	tw.parallel().tween_property(crown_l, "scale", Vector2(1.0, 1.0), 0.32) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(crown, "scale", Vector2(1.0, 1.0), 0.32) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.5)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.40)
	tw.tween_callback(overlay.queue_free)

func _plain_label(text: String, font_size: int, parent: Node,
				  pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.position    = pos
	l.size        = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _shadow_label(text: String, font_size: int, parent: Node,
				   pos: Vector2, sz: Vector2) -> void:
	var sh := _plain_label(text, font_size, parent, pos + Vector2(4, 6), sz)
	sh.add_theme_color_override("font_color", Color(0, 0, 0, 0.48))


# Drawn crown for the round-win flash (consistent across platforms — no emoji).
class _CrownIcon extends Control:
	var fill: Color = Color("ffc31f")
	func _draw() -> void:
		DrawKit.crown(self, Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.7, Color("ffc31f"))


# Daily-reward popup card: a sticker panel with a star and the coin bonus.
class _DailyCard extends Control:
	var bonus: int = 0
	func _draw() -> void:
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 28.0, Color("23203f"), 4.0, true)
		DrawKit.star(self, Vector2(size.x * 0.5, 64), 40.0)
		var f: Font = ArcadeTheme.font
		var t1 := "DAILY REWARD"
		var w1 := f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(f, Vector2((size.x - w1) * 0.5, 138), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		var t2 := "+%d COINS" % bonus
		var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		draw_string(f, Vector2((size.x - w2) * 0.5, 196), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("f5c018"))
