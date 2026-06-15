extends Control

# On-screen analog stick. Feeds InputManager.set_move each frame.
# Styled to match the toy-box reference: player-coloured knob + dark-outlined ring.

var player_id: int = 0
var radius: float = 110.0
var player_color: Color = Color("f02828")   # set by touch_controls
var _touch_index: int = -1
var _value: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	InputManager.set_move(player_id, _value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_set_from(event.position)
		elif not event.pressed and event.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_set_from(event.position)

func _set_from(pos: Vector2) -> void:
	var off := pos - size * 0.5
	if off.length() > radius:
		off = off.normalized() * radius
	_value = off / radius
	queue_redraw()

func _reset() -> void:
	_touch_index = -1
	_value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var ring_col := player_color

	# Drop shadow under base
	draw_circle(c + Vector2(0, 4), radius, Color(0, 0, 0, 0.20))
	# Dark outline ring (base plate)
	draw_circle(c, radius, DrawKit.OUTLINE)
	# Player-colour translucent base fill
	draw_circle(c, radius - 4.0, Color(ring_col, 0.28))
	# Bright ring edge
	draw_arc(c, radius - 4.0, 0, TAU, 80, Color(ring_col, 0.90), 3.5)

	# Cardinal directional arrows (N/S/E/W)
	for i in 4:
		var angle := TAU * i / 4.0 - PI * 0.5  # start at top
		var dir := Vector2(cos(angle), sin(angle))
		var tip := c + dir * (radius * 0.80)
		var base_l := c + dir * (radius * 0.58) + Vector2(-dir.y, dir.x) * (radius * 0.14)
		var base_r := c + dir * (radius * 0.58) - Vector2(-dir.y, dir.x) * (radius * 0.14)
		var arrow := PackedVector2Array([tip, base_l, base_r])
		draw_colored_polygon(arrow, Color(1, 1, 1, 0.55))

	# Knob
	var knob_r := radius * 0.44
	var knob_c := c + _value * (radius - knob_r * 0.7)
	# Knob shadow
	draw_circle(knob_c + Vector2(0, 4), knob_r, Color(0, 0, 0, 0.25))
	# Knob outline
	draw_circle(knob_c, knob_r, DrawKit.OUTLINE)
	# Knob fill — player colour
	draw_circle(knob_c, knob_r - 3.5, ring_col)
	# Knob highlight
	draw_circle(knob_c + Vector2(0, -knob_r * 0.28), knob_r * 0.46, Color(1, 1, 1, 0.22))
