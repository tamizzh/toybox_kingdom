extends Control

# Builds per-player joystick + action button clusters in the screen corners.
# Only active players get a cluster.

const Joy := preload("res://ui/virtual_joystick.gd")
const Btn := preload("res://ui/action_button.gd")

var _nodes: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(players: Array) -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	for p in players:
		_make_pair(p.id, p.color)

func _make_pair(pid: int, color: Color) -> void:
	const W := 1560.0
	const H := 720.0
	var joy = Joy.new()
	joy.player_id = pid
	var btn = Btn.new()
	btn.player_id = pid
	add_child(joy)
	add_child(btn)
	match pid:
		0:
			joy.position = Vector2(40, H - 234)
			btn.position = Vector2(252, H - 188)
		1:
			joy.position = Vector2(W - 224, H - 234)
			btn.position = Vector2(W - 380, H - 188)
		2:
			joy.position = Vector2(40, 40)
			btn.position = Vector2(252, 86)
		3:
			joy.position = Vector2(W - 224, 40)
			btn.position = Vector2(W - 380, 86)
	joy.modulate = color.lerp(Color.WHITE, 0.45)
	btn.modulate = color
	_nodes.append(joy)
	_nodes.append(btn)
