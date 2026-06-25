extends Control

# Campaign-map overlay: the whole conquest ladder as a vertical run of stage cards.
# Cleared stages show a check; the current frontier stage is highlighted with a
# CONQUER button that launches the match (kingdom_match plays SaveManager's active
# stage); later stages are locked + dimmed. Added as a child of the main menu,
# frees itself on Close. Difficulty preview = one coloured pip per rival
# (green timid / gold balanced / red bold).

const Campaign := preload("res://toybox_kingdoms/data/campaign.gd")
const KINGDOM_MATCH := "res://toybox_kingdoms/kingdom_match.tscn"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color("141a28"), Color("3f4d69")))
	panel.custom_minimum_size = Vector2(760, 624)
	panel.position = Vector2(Palette.CENTER_X - 380, 48)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var cleared := SaveManager.campaign_cleared()
	var done := SaveManager.campaign_complete()

	var title := Label.new()
	title.text = "CAMPAIGN COMPLETE 👑" if done else "CAMPAIGN"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var prog := Label.new()
	prog.text = "%d / %d stages conquered" % [mini(cleared, Campaign.count()), Campaign.count()]
	prog.add_theme_font_size_override("font_size", 20)
	prog.add_theme_color_override("font_color", Palette.WARN)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(prog)

	# Scrolling stack of stage cards (10 stages overflow the panel height).
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 472)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var active := SaveManager.active_stage()
	for idx in Campaign.count():
		list.add_child(_stage_card(idx, cleared, active))

	col.add_child(_btn("CLOSE", Palette.SAFE, func() -> void:
		AudioManager.play("tap")
		queue_free()))


# One stage card: number badge · title + difficulty pips · status (✓ / CONQUER / 🔒).
func _stage_card(idx: int, cleared: int, active: int) -> Control:
	var is_cleared := idx < cleared
	var is_current := idx == active
	var is_locked := idx > cleared

	var accent := Palette.NEUTRAL
	if is_current:
		accent = Palette.WARN
	elif is_cleared:
		accent = Palette.SAFE

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		_panel(Color(accent, 0.16 if is_current else 0.08), Color(accent, 0.85 if is_current else 0.4)))
	card.custom_minimum_size = Vector2(700, 76)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	# stage-number badge
	var badge := Label.new()
	badge.text = "%d" % (idx + 1)
	badge.add_theme_font_size_override("font_size", 30)
	badge.add_theme_color_override("font_color", Color.WHITE if not is_locked else Color(1, 1, 1, 0.4))
	badge.custom_minimum_size = Vector2(44, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(badge)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var name_l := Label.new()
	name_l.text = Campaign.title(idx)
	name_l.add_theme_font_size_override("font_size", 23)
	name_l.add_theme_color_override("font_color", Color.WHITE if not is_locked else Color(1, 1, 1, 0.45))
	info.add_child(name_l)

	# difficulty preview: one coloured pip per rival
	var diffs := Campaign.rival_diffs(idx)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 5)
	for d in diffs:
		pips.add_child(_pip(int(d), is_locked))
	var cnt := Label.new()
	cnt.text = "  %d rivals" % diffs.size()
	cnt.add_theme_font_size_override("font_size", 15)
	cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pips.add_child(cnt)
	info.add_child(pips)

	# status / action on the right
	if is_current:
		row.add_child(_btn("REPLAY" if is_cleared else "CONQUER", Palette.WARN, func() -> void:
			AudioManager.play("tap")
			get_tree().change_scene_to_file(KINGDOM_MATCH), 150.0))
	elif is_cleared:
		row.add_child(_status("✓", Palette.SAFE))
	else:
		row.add_child(_status("🔒", Palette.NEUTRAL))
	return card


# A small difficulty pip: green timid / gold balanced / red bold.
func _pip(diff: int, locked: bool) -> Control:
	var c := Palette.SAFE
	if diff == 1:
		c = Palette.WARN
	elif diff >= 2:
		c = Palette.DANGER
	if locked:
		c = Color(c, 0.5)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(13, 13)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(7)
	s.border_color = Color(0, 0, 0, 0.4)
	s.set_border_width_all(1)
	dot.add_theme_stylebox_override("panel", s)
	return dot


func _status(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(150, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
