extends Control

# Final match results — the showpiece. Big winning mascot with a crown, a solid
# styled scoreboard card, a fun stat, and chunky buttons. Confetti throughout.

const MascotFace := preload("res://ui/mascot_face.gd")

const CENTER := 780.0


func show_match_winner(winner_id: int, players: Array) -> void:
	var wcol := Palette.player_color(winner_id)

	# Background
	var bg := ColorRect.new()
	bg.color = Color("181434")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Soft winner-colour glow band behind the mascot
	var strip := ColorRect.new()
	strip.color = Color(wcol, 0.16)
	strip.size = Vector2(Palette.DESIGN_W, 300)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	_spawn_confetti()

	# Crown + big winning mascot, popped in with a bounce.
	var hero := _HeroMascot.new()
	hero.player_color = wcol
	hero.size = Vector2(220, 210)
	hero.position = Vector2(CENTER - 110, 56)
	hero.pivot_offset = Vector2(110, 160)
	hero.scale = Vector2(0.3, 0.3)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero)
	var htw := hero.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	htw.tween_property(hero, "scale", Vector2.ONE, 0.4)

	# Winner name
	var name_label := Label.new()
	name_label.text = "%s WINS!" % Palette.player_name(winner_id)
	name_label.add_theme_font_size_override("font_size", 76)
	name_label.add_theme_color_override("font_color", wcol)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(Palette.DESIGN_W, 90)
	name_label.position = Vector2(0, 280)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	# Scoreboard card (solid, outlined)
	var sorted := ScoreManager.sorted_by_score()
	var rows := sorted.size()
	var card_h := 28.0 + rows * 50.0
	var card := _Card.new()
	card.size = Vector2(560, card_h)
	card.position = Vector2(CENTER - 280, 380)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	for i in rows:
		var p: PlayerData = sorted[i]
		var row := HBoxContainer.new()
		row.position = Vector2(28, 18 + i * 50)
		row.add_theme_constant_override("separation", 16)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)

		var dot := ColorRect.new()
		dot.color = p.color
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)

		var name_l := Label.new()
		name_l.text = p.display_name
		name_l.add_theme_font_size_override("font_size", 28)
		name_l.add_theme_color_override("font_color", p.color)
		name_l.custom_minimum_size = Vector2(360, 0)
		row.add_child(name_l)

		var score_l := Label.new()
		score_l.text = "%d pts" % p.score
		score_l.add_theme_font_size_override("font_size", 28)
		score_l.add_theme_color_override("font_color", Color.WHITE if p.id == winner_id else Palette.NEUTRAL)
		row.add_child(score_l)

	# Fun stat with a drawn trophy
	var trophy := _TrophyIcon.new()
	trophy.size = Vector2(48, 48)
	trophy.position = Vector2(CENTER - 300, 388 + card_h)
	trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trophy)

	var stat := _compute_funny_stat(players, winner_id)
	var stat_label := Label.new()
	stat_label.text = stat
	stat_label.add_theme_font_size_override("font_size", 22)
	stat_label.add_theme_color_override("font_color", Palette.WARN)
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label.size = Vector2(480, 48)
	stat_label.position = Vector2(CENTER - 240, 388 + card_h)
	stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stat_label)

	# Coins earned this match — reinforces the progression loop at the payoff moment.
	if GameManager.last_match_coins > 0:
		var coins_l := Label.new()
		coins_l.text = "+%d COINS EARNED" % GameManager.last_match_coins
		coins_l.add_theme_font_size_override("font_size", 26)
		coins_l.add_theme_color_override("font_color", Palette.WARN)
		coins_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coins_l.size = Vector2(Palette.DESIGN_W, 34)
		coins_l.position = Vector2(0, 566)
		coins_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(coins_l)

	# Buttons
	_make_btn("PLAY AGAIN", Vector2(CENTER - 400, 612), Palette.SAFE, _on_again)
	_make_btn("MAIN MENU", Vector2(CENTER + 20, 612), Color("3a496a"), GameManager.return_to_menu)


# ── Solid chunky button ──────────────────────────────────────────────────────────
func _make_btn(text: String, pos: Vector2, color: Color, cb: Callable) -> void:
	var btn := _SolidButton.new()
	btn.label = text
	btn.fill = color
	btn.custom_minimum_size = Vector2(380, 84)
	btn.size = Vector2(380, 84)
	btn.position = pos
	btn.pressed.connect(cb)
	add_child(btn)


func _compute_funny_stat(players: Array, winner_id: int) -> String:
	var sorted := ScoreManager.sorted_by_score()
	if sorted.size() < 2:
		return "%s dominated — undefeated!" % Palette.player_name(winner_id)
	var winner_score: int = sorted[0].score
	var runner_score: int = sorted[1].score
	var gap := winner_score - runner_score
	var runner_name := Palette.player_name(sorted[1].id)
	if gap >= 4:
		return "%s was unstoppable — won by %d points!" % [Palette.player_name(winner_id), gap]
	elif gap == 0:
		return "Tiebreaker! %s edged out %s on the last round!" % [Palette.player_name(winner_id), runner_name]
	elif gap == 1:
		return "%s held on — only 1 point ahead of %s!" % [Palette.player_name(winner_id), runner_name]
	else:
		return "%s beat %s by %d — rematch?" % [Palette.player_name(winner_id), runner_name, gap]


func _spawn_confetti() -> void:
	var colors := [
		Color("f02828"), Color("1878f0"), Color("10b83c"), Color("f5c018"),
		Color("f040a0"), Color("40e0ff"), Color("ff8820"),
	]
	for _i in 44:
		var cr := ColorRect.new()
		cr.color = colors[randi() % colors.size()]
		cr.size = Vector2(randf_range(8, 18), randf_range(5, 12))
		cr.position = Vector2(randf_range(0, Palette.DESIGN_W), randf_range(-60, -10))
		cr.pivot_offset = cr.size * 0.5
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cr)
		var tw := cr.create_tween()
		var duration := randf_range(1.4, 2.8)
		tw.tween_property(cr, "position:y", Palette.DESIGN_H + 20, duration)
		tw.parallel().tween_property(cr, "rotation", randf_range(-TAU, TAU), duration)


func _on_again() -> void:
	GameManager.replay_last()
	GameManager.start_match()


# ── Drawn pieces ───────────────────────────────────────────────────────────────────
class _HeroMascot extends Control:
	var player_color: Color = Color.WHITE
	var _face: Control
	func _ready() -> void:
		_face = (preload("res://ui/mascot_face.gd")).new()
		_face.set_color(player_color)
		_face.size = Vector2(170, 170)
		_face.position = Vector2((size.x - 170) * 0.5, 40)
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_face)
	func _draw() -> void:
		DrawKit.crown(self, Vector2(size.x * 0.5, 34), 96.0)


class _Card extends Control:
	func _draw() -> void:
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 26.0, Color("23203f"), 4.0, true)


class _TrophyIcon extends Control:
	func _draw() -> void:
		DrawKit.trophy(self, Vector2(size.x * 0.5, size.y * 0.45), size.x * 0.7, Color("ffc31f"))


class _SolidButton extends Button:
	var label: String = ""
	var fill: Color = Color("10b83c")
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
	func _draw() -> void:
		var f := fill.darkened(0.12) if button_pressed else fill
		DrawKit.card(self, Rect2(Vector2.ZERO, size), 24.0, f, 4.0, true)
		var fs := 30
		var tw := ArcadeTheme.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(ArcadeTheme.font, Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.36),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
