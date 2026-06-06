class_name Tank3D
extends SubViewport

# A live 3D tank: renders the real tank.glb model into a texture that the 2D
# avatar displays. The model rotates in true 3D (yaw) to face the joystick.
#
# Usage:
#   var t := Tank3D.new()
#   add_child(t)                     # must be in the tree to render
#   some_sprite.texture = t.get_texture()
#   t.face(Vector2.RIGHT)            # turn the tank toward a 2D direction

const MODEL := preload("res://tank.glb")

# flip these if the turn direction / facing comes out mirrored in-game
const YAW_SIGN := -1.0
const YAW_OFFSET := 0.0

var _yaw: Node3D

func _ready() -> void:
	size = Vector2i(256, 256)
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	own_world_3d = true
	world_3d = World3D.new()

	# rotating pivot holding the model (model forward = +X in Godot)
	_yaw = Node3D.new()
	add_child(_yaw)
	_yaw.add_child(MODEL.instantiate())

	# key + soft ambient via an environment
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, 38, 0)
	key.light_energy = 1.4
	add_child(key)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# orthographic top-down camera with a slight tilt (gun = +X -> image right)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.0
	cam.position = Vector3(0.5, 11.0, 4.5)
	add_child(cam)
	cam.look_at(Vector3(0.5, 0.0, 0.0), Vector3(0, 0, -1))

func set_yaw(rad: float) -> void:
	if _yaw:
		_yaw.rotation.y = YAW_SIGN * rad + YAW_OFFSET

func face(dir: Vector2) -> void:
	if dir.length() > 0.01:
		set_yaw(dir.angle())
