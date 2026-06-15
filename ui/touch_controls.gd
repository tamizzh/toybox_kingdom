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
	for p in players:
		if p.is_ai:
			continue   # CPUs are driven by AIController, not on-screen sticks
		_make_pair(p.id, p.color)

func _make_pair(pid: int, color: Color) -> void:
	const W := 1560.0
	const H := 720.0
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
			joy.position = Vector2(18,  H - 248)
			btn.position = Vector2(256, H - 204)
		1:  # bottom-right
			joy.position = Vector2(W - 238, H - 248)
			btn.position = Vector2(W - 400, H - 204)
		2:  # top-left
			joy.position = Vector2(18,  28)
			btn.position = Vector2(256, 72)
		3:  # top-right
			joy.position = Vector2(W - 238, 28)
			btn.position = Vector2(W - 400, 72)
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
