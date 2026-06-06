extends Control

# On-screen action button for one player. Feeds InputManager.set_action.

var player_id: int = 0
var radius: float = 64.0
var caption: String = "GO"
var _touch_index: int = -1
var _down: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_set_down(true)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_set_down(false)

func _set_down(v: bool) -> void:
	_down = v
	InputManager.set_action(player_id, v)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, radius, Color(1, 1, 1, 0.50 if _down else 0.18))
	draw_arc(c, radius, 0, TAU, 40, Color(1, 1, 1, 0.40), 4.0)
