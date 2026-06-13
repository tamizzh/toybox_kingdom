extends MiniGameBase3D

# Wait for GREEN, then tap. First valid tap scores; early tap = disqualified
# for that round. Most round wins takes it. (UI on the 2D overlay)

var _phase := "wait"
var _t := 1.5
var _dq := {}
var _msg: Label
var _panel: ColorRect

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	make_label("Tap on GREEN — don't jump early!", Vector2(400, 96), 22)
	_panel = make_bar(Vector2(440, 260), Vector2(400, 170), Palette.DANGER)
	_msg = make_label("WAIT...", Vector2(560, 300), 56, Palette.ACCENT)
	_new_wait()

func _new_wait() -> void:
	_phase = "wait"
	_t = randf_range(0.8, 2.4)
	_dq = {}
	_panel.color = Palette.DANGER
	_msg.text = "WAIT..."

func _game_process(delta: float) -> void:
	match _phase:
		"wait":
			_t -= delta
			for p in players:
				if InputManager.get_action_just(p.id):
					_dq[p.id] = true
			if _t <= 0.0:
				_phase = "go"
				_panel.color = Palette.SAFE
				_msg.text = "GO!"
		"go":
			for p in players:
				if InputManager.get_action_just(p.id) and not _dq.get(p.id, false):
					p.round_value += 1.0
					_msg.text = "%s!" % p.display_name
					_phase = "cool"
					_cool_then_wait()
					break

func _cool_then_wait() -> void:
	await get_tree().create_timer(0.7).timeout
	if not _finished:
		_new_wait()

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
