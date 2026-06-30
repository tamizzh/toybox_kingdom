extends Node

# Autoload singleton. Normalizes input for up to 4 local players.
# Touch controls push state via set_move/set_action.
# Keyboard (P1 WASD+Space, P2 Arrows+Enter) is OR-ed in as a PC convenience.

const MAX_PLAYERS := 4

var _touch_move := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _touch_action := [false, false, false, false]
var _move_now := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

var _action_now := [false, false, false, false]
var _action_prev := [false, false, false, false]
var _action_just := [false, false, false, false]
var _action_released := [false, false, false, false]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_keys()

func _register_keys() -> void:
	_add_key("p1_up", KEY_W)
	_add_key("p1_down", KEY_S)
	_add_key("p1_left", KEY_A)
	_add_key("p1_right", KEY_D)
	_add_key("p1_action", KEY_SPACE)
	_add_key("p1_up", KEY_UP)
	_add_key("p1_down", KEY_DOWN)
	_add_key("p1_left", KEY_LEFT)
	_add_key("p1_right", KEY_RIGHT)
	_add_key("p1_action", KEY_ENTER)
	_add_key("p2_up", KEY_UP)
	_add_key("p2_down", KEY_DOWN)
	_add_key("p2_left", KEY_LEFT)
	_add_key("p2_right", KEY_RIGHT)
	_add_key("p2_action", KEY_ENTER)

func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _process(_delta: float) -> void:
	for id in MAX_PLAYERS:
		var v: Vector2 = _touch_move[id] + _kbd_move(id)
		# length_squared() avoids a sqrt when the vector is already within the unit
		# circle (the common case); normalize (which sqrts) only when clamping is needed.
		if v.length_squared() > 1.0:
			v = v.normalized()
		_move_now[id] = v
		var a := _raw_action(id)
		_action_just[id] = a and not _action_prev[id]
		_action_released[id] = (not a) and _action_prev[id]
		_action_now[id] = a
		_action_prev[id] = a

func _raw_action(id: int) -> bool:
	if _touch_action[id]:
		return true
	if id == 0 and Input.is_action_pressed("p1_action"):
		return true
	if id == 1 and Input.is_action_pressed("p2_action"):
		return true
	return false

func _kbd_move(id: int) -> Vector2:
	var v := Vector2.ZERO
	if id == 0:
		v.x = Input.get_action_strength("p1_right") - Input.get_action_strength("p1_left")
		v.y = Input.get_action_strength("p1_down") - Input.get_action_strength("p1_up")
	elif id == 1:
		v.x = Input.get_action_strength("p2_right") - Input.get_action_strength("p2_left")
		v.y = Input.get_action_strength("p2_down") - Input.get_action_strength("p2_up")
	return v

# ---- Touch controls push here ----
func set_move(id: int, v: Vector2) -> void:
	if id >= 0 and id < MAX_PLAYERS:
		_touch_move[id] = v

func set_action(id: int, down: bool) -> void:
	if id >= 0 and id < MAX_PLAYERS:
		_touch_action[id] = down

# ---- Mini-games read here ----
func get_move(id: int) -> Vector2:
	return _move_now[id]

func get_action(id: int) -> bool:
	return _action_now[id]

func get_action_just(id: int) -> bool:
	return _action_just[id]

func get_action_released(id: int) -> bool:
	return _action_released[id]

func reset() -> void:
	for i in MAX_PLAYERS:
		_touch_move[i] = Vector2.ZERO
		_move_now[i] = Vector2.ZERO
		_touch_action[i] = false
