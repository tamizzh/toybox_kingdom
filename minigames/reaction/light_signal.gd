extends MiniGameBase3D

# Traffic-light start. Lights go red, red, GREEN. First to tap on green scores;
# early tap disqualifies that round. (UI on the 2D overlay)

var _phase := "wait"
var _t := 1.5
var _lit := 0
var _dq := {}
var _msg: Label
var _lights: Array = []

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	make_label("Tap when all lights turn GREEN!", Vector2(410, 96), 22)
	for i in 3:
		var lt := make_bar(Vector2(Palette.CENTER_X - 138.0 + i * 100, 282), Vector2(76, 76), Color(Palette.WALL, 0.5))
		_lights.append(lt)
	_msg = make_label("", Vector2(560, 470), 40, Palette.NEUTRAL)
	_new_wait()

func _new_wait() -> void:
	_phase = "wait"
	_t = randf_range(1.0, 2.6)
	_lit = 0
	_dq = {}
	_msg.text = "Get ready..."
	_refresh_lights()

func _refresh_lights() -> void:
	var green := _phase == "go"
	for i in 3:
		var on := green or i < _lit
		var col: Color = (Palette.SAFE if green else Palette.DANGER) if on else Color(Palette.WALL, 0.5)
		_lights[i].color = col

func _game_process(delta: float) -> void:
	match _phase:
		"wait":
			_t -= delta
			_lit = clampi(3 - int(ceil(_t / 0.7)), 0, 3)
			for p in players:
				if InputManager.get_action_just(p.id):
					_dq[p.id] = true
			if _t <= 0.0:
				_phase = "go"
				_msg.text = "GO!"
			_refresh_lights()
		"go":
			for p in players:
				if InputManager.get_action_just(p.id) and not _dq.get(p.id, false):
					p.round_value += 1.0
					_msg.text = "%s scores!" % p.display_name
					_phase = "cool"
					_cool_then_wait()
					break

func _cool_then_wait() -> void:
	await get_tree().create_timer(0.8).timeout
	if not _finished:
		_new_wait()

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
