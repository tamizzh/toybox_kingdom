extends Control

# On-screen analog stick. Feeds InputManager.set_move each frame.
# Styled to match the toy-box reference: player-coloured knob + dark-outlined ring.
#
# Two layouts:
#   dynamic = false  → fixed stick drawn at the node's own rect (multiplayer corners).
#   dynamic = true   → floating stick: the control fills the screen and the stick
#                      pops up wherever the finger first touches, following the drag.

var player_id: int = 0
var radius: float = 110.0
var player_color: Color = Color("f02828")   # set by touch_controls
var dynamic: bool = false
var _touch_index: int = -1
var _value: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO          # stick centre (dynamic mode)
var _active: bool = false

func _ready() -> void:
	if dynamic:
		# Fill whatever rect the parent gives us so we can catch a touch anywhere.
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
		size = custom_minimum_size
		_origin = size * 0.5
		_active = true   # fixed stick is always visible
		mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	InputManager.set_move(player_id, _value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			if dynamic:
				_origin = event.position
				_active = true
			_set_from(event.position)
		elif not event.pressed and event.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_set_from(event.position)

func _set_from(pos: Vector2) -> void:
	var off := pos - _origin
	if off.length() > radius:
		off = off.normalized() * radius
	_value = off / radius
	queue_redraw()

func _reset() -> void:
	_touch_index = -1
	_value = Vector2.ZERO
	if dynamic:
		_active = false
	queue_redraw()

func _draw() -> void:
	if dynamic and not _active:
		return   # nothing on screen until the finger lands
	var c := _origin if dynamic else size * 0.5
	var ring_col := player_color

	# Drop shadow under base
	draw_circle(c + Vector2(0, 6), radius, Color(0, 0, 0, 0.18))
	# Dark outline ring (base plate)
	draw_circle(c, radius, Color(ring_col, 0.44))
	# Dark navy base plate (target's D-pad look — colour lives on the rim + knob)
	draw_arc(c, radius - 2.0, 0, TAU, 96, Color(ring_col.lightened(0.10), 0.96), 8.0)
	# Bright player-colour ring edge
	draw_arc(c, radius - 14.0, 0, TAU, 96, Color(1, 1, 1, 0.16), 3.0)

	# Cardinal directional arrows (N/S/E/W)
	for i in 4:
		var angle := TAU * i / 4.0 - PI * 0.5  # start at top
		var dir := Vector2(cos(angle), sin(angle))
		var tip := c + dir * (radius * 0.80)
		var base_l := c + dir * (radius * 0.60) + Vector2(-dir.y, dir.x) * (radius * 0.12)
		var base_r := c + dir * (radius * 0.60) - Vector2(-dir.y, dir.x) * (radius * 0.12)
		var arrow := PackedVector2Array([tip, base_l, base_r])
		draw_colored_polygon(arrow, Color(1, 1, 1, 0.85))

	# Knob
	var knob_r := radius * 0.43
	var knob_c := c + _value * (radius - knob_r * 0.7)
	# Knob shadow
	draw_circle(knob_c + Vector2(0, 5), knob_r, Color(0, 0, 0, 0.25))
	# Knob outline
	draw_circle(knob_c, knob_r, Color(ring_col.darkened(0.35), 1.0))
	# Knob fill — player colour
	draw_circle(knob_c, knob_r - 3.5, ring_col)
	# Knob highlight
	draw_circle(knob_c + Vector2(0, -knob_r * 0.28), knob_r * 0.46, Color(1, 1, 1, 0.22))
