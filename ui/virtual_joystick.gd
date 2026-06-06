extends Control

# On-screen analog stick for one player. Feeds InputManager.set_move each frame.
# Supports multitouch (tracks its own touch index) and mouse (PC testing).

var player_id: int = 0
var radius: float = 92.0
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
	draw_circle(c, radius, Color(1, 1, 1, 0.08))
	draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.30), 4.0)
	draw_circle(c + _value * radius, radius * 0.45, Color(1, 1, 1, 0.55))
