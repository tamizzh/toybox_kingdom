extends Control

# Builds per-player joystick + action button clusters in the screen corners.
# Only active players get a cluster.

const Joy := preload("res://ui/virtual_joystick.gd")
const Btn := preload("res://ui/action_button.gd")

var _nodes: Array = []
var _buttons: Array = []   # action buttons, so the per-game verb can be set later

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(players: Array) -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	_buttons.clear()
	# On a keyboard-driven desktop (no touchscreen) the on-screen sticks are just
	# clutter over the play area — skip them. Touch devices always get them.
	if not DeviceMode.has_touch:
		return
	var humans: Array = []
	for p in players:
		if not p.is_ai:   # CPUs are driven by AIController, not on-screen sticks
			humans.append(p)
	var vp := get_viewport_rect().size
	if humans.size() == 1:
		# Solo / vs-CPU: classic single-player layout — move on the left, action on
		# the right (matches the reference art). The opponent shows only as a score chip.
		_make_solo(humans[0].id, humans[0].color, vp)
	else:
		for p in humans:
			_make_pair(p.id, p.color, vp)

func _make_solo(pid: int, color: Color, _vp: Vector2) -> void:
	# Solo: a single floating joystick that pops up wherever the player touches.
	# No action button — movement is the only on-screen control.
	var joy = Joy.new()
	joy.player_id    = pid
	joy.player_color = color
	joy.dynamic      = true
	add_child(joy)
	joy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # catch a touch anywhere
	_nodes.append(joy)

func _make_pair(pid: int, color: Color, vp: Vector2) -> void:
	var w := vp.x
	var h := vp.y
	# Joy radius=110 → diameter=220.  Btn radius=72 → diameter=144.
	var joy = Joy.new()
	joy.player_id = pid
	var btn = Btn.new()
	btn.player_id = pid
	btn.caption   = "ACTION"
	add_child(joy)
	add_child(btn)
	match pid:
		0:  # bottom-left
			joy.position = Vector2(18,  h - 248)
			btn.position = Vector2(256, h - 204)
		1:  # bottom-right
			joy.position = Vector2(w - 238, h - 248)
			btn.position = Vector2(w - 400, h - 204)
		2:  # top-left
			joy.position = Vector2(18,  28)
			btn.position = Vector2(256, 72)
		3:  # top-right
			joy.position = Vector2(w - 238, 28)
			btn.position = Vector2(w - 400, 72)
	# Player colour: passed explicitly so each node draws its own color-aware art
	joy.player_color = color
	btn.player_color = color
	_nodes.append(joy)
	_nodes.append(btn)
	_buttons.append(btn)

# Set the action-button verb for the current game (e.g. "RUN", "FIRE", "BOOST").
func set_action_label(text: String) -> void:
	for btn in _buttons:
		btn.caption = text
		btn.queue_redraw()
