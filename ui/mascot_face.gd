class_name MascotFace
extends Control

# Small 2D cartoon mascot face for HUD score pills, the shop and menus — the same
# big-eyed blob look as the 3D avatars, drawn cheaply at any size. Matches the
# round red/blue character heads in the reference art (snake_target / race_target).

var color: Color = Palette.PLAYER_COLORS[0]
var _blink_t: float = 0.0
var _blink: float = 1.0   # 1 = open, 0 = shut

func set_color(c: Color) -> void:
	color = c
	queue_redraw()

func _process(delta: float) -> void:
	# Occasional blink for personality.
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.0, 5.0)
		var tw := create_tween()
		tw.tween_method(func(v): _blink = v; queue_redraw(), 1.0, 0.05, 0.07)
		tw.tween_method(func(v): _blink = v; queue_redraw(), 0.05, 1.0, 0.09)

func _draw() -> void:
	var c := size * 0.5
	var r: float = min(size.x, size.y) * 0.5
	# Body
	draw_circle(c, r, color, true, -1.0, true)
	# Soft top shine
	draw_circle(c + Vector2(-r * 0.30, -r * 0.34), r * 0.30,
		Color(1, 1, 1, 0.22), true, -1.0, true)
	# Dark rim
	draw_arc(c, r - 1.0, 0.0, TAU, 40, color.darkened(0.30), 2.0, true)

	# Eyes
	var eye_r := r * 0.30
	var eye_dx := r * 0.34
	var eye_y := c.y - r * 0.06
	var le := Vector2(c.x - eye_dx, eye_y)
	var re := Vector2(c.x + eye_dx, eye_y)
	var open := maxf(_blink, 0.06)
	# White of eye (squashed vertically when blinking)
	_draw_oval(le, eye_r, eye_r * open, Color.WHITE)
	_draw_oval(re, eye_r, eye_r * open, Color.WHITE)
	# Pupils
	var pr := eye_r * 0.52
	var pupil := Color(0.06, 0.05, 0.10)
	_draw_oval(le + Vector2(eye_r * 0.16, eye_r * 0.10), pr, pr * open, pupil)
	_draw_oval(re + Vector2(eye_r * 0.16, eye_r * 0.10), pr, pr * open, pupil)
	# Cheeks
	var cheek := Color(1.0, 0.55, 0.55, 0.35)
	draw_circle(Vector2(c.x - r * 0.46, c.y + r * 0.30), r * 0.14, cheek, true, -1.0, true)
	draw_circle(Vector2(c.x + r * 0.46, c.y + r * 0.30), r * 0.14, cheek, true, -1.0, true)

func _draw_oval(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * maxf(ry, 0.5)))
	draw_colored_polygon(pts, col)
