extends Control

# Daily Challenge overlay: shows today's status (available / claimed), the current
# streak, and the reward for completing today, with a PLAY button that launches the
# date-seeded daily run. Added as a child of the main menu; frees itself on Close.

const KINGDOM_MATCH := "res://toybox_kingdoms/kingdom_match.tscn"
const UIKit := preload("res://ui/ui_kit.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color("141a28"), Color("3f4d69")))
	panel.custom_minimum_size = Vector2(600, 400)
	panel.position = Vector2(Palette.CENTER_X - 300, 80)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var done := SaveManager.daily_done_today()
	var streak := SaveManager.daily_streak()
	var next_reward := 100 + maxi(0, streak if done else streak) * 20   # preview the reward at risk/next

	_label(vb, "DAILY CHALLENGE", 40, Color.WHITE)
	_label(vb, "One shared island a day — same board for everyone.", 20, Color(1, 1, 1, 0.8))
	_rule(vb)
	_label(vb, "STREAK  ·  %d DAY%s" % [streak, "" if streak == 1 else "S"], 30, Palette.SAFE)

	if done:
		_label(vb, "Today's done — best %s" % str(SaveManager.daily_best()), 24, Palette.WARN)
		_label(vb, "Come back tomorrow to keep your streak alive!", 20, Color(1, 1, 1, 0.7))
	else:
		_label(vb, "Today's reward:  +%d coins" % next_reward, 24, HUD_GOLD)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vb.add_child(spacer)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	vb.add_child(btns)

	var play_btn := UIKit.stone_btn("REPLAY TODAY" if done else "PLAY TODAY", true, func() -> void:
		AudioManager.play("tap")
		SaveManager.set_mode("daily")
		get_tree().change_scene_to_file(KINGDOM_MATCH), 200)
	btns.add_child(play_btn)

	btns.add_child(UIKit.stone_btn("CLOSE", false, func() -> void:
		AudioManager.play("tap")
		queue_free(), 200))

const HUD_GOLD := Color("ffd34d")

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _rule(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.15)
	r.custom_minimum_size = Vector2(0, 2)
	parent.add_child(r)


func _panel(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(20)
	s.content_margin_left = 28; s.content_margin_right = 28
	s.content_margin_top = 24; s.content_margin_bottom = 24
	return s
