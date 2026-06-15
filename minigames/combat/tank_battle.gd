extends MiniGameBase3D

# Top-down tanks in REAL 3D. Move + shoot. Last tank alive wins.
# Each player drives the actual tank.glb model; the joystick turns it in 3D and
# fires 3D bullets in the facing direction.

const TANK := preload("res://tank.glb")
const BULLET := preload("res://shared/bullet3d.gd")

const TANK_SCALE := 0.62
const TANK_SPEED := 6.5
const BULLET_SPEED := 18.0
const FIRE_COOLDOWN := 0.5

var _facing := {}     # id -> Vector3 (XZ)
var _cool := {}

func _setup_round() -> void:
	win_condition = WinType.LAST_ALIVE
	action_label = "FIRE"
	add_child(build_arena())
	spawn_avatars(corner_spawns(2.0))
	for p in players:
		_facing[p.id] = Vector3(1, 0, 0)
		_cool[p.id] = 0.0
		var av = avatars[p.id]
		av.speed = TANK_SPEED
		av.set_model(TANK, TANK_SCALE, 0.0)
		_tint_tank(av, p.color)   # paint each tank its player colour so it's identifiable
	# Instruction shown by the HUD tagline banner.

# Recolour every mesh of a tank model to the player's colour (keeps tracks a
# touch darker so the silhouette still reads).
func _tint_tank(av: Node, color: Color) -> void:
	_tint_recursive(av, color)

func _tint_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var n := node.name.to_lower()
		if "outline" not in n:
			var m := StandardMaterial3D.new()
			m.albedo_color = color if ("track" not in n and "wheel" not in n) else color.darkened(0.55)
			m.roughness = 0.45
			m.metallic = 0.05
			(node as MeshInstance3D).material_override = m
	for child in node.get_children():
		_tint_recursive(child, color)

func _game_process(delta: float) -> void:
	for p in players:
		if not p.alive:
			continue
		var mv := InputManager.get_move(p.id)
		if mv.length() > 0.2:
			_facing[p.id] = Vector3(mv.x, 0, mv.y).normalized()
		_cool[p.id] = maxf(0.0, _cool[p.id] - delta)
		if InputManager.get_action(p.id) and _cool[p.id] <= 0.0:
			_cool[p.id] = FIRE_COOLDOWN
			_shoot(p)

func _shoot(p: PlayerData) -> void:
	var av = avatars[p.id]
	var b := BULLET.new()
	add_child(b)
	b.global_position = av.global_position + _facing[p.id] * 1.8 + Vector3(0, 0.9, 0)
	b.setup(p.id, _facing[p.id], p.color, BULLET_SPEED)
	b.hit_player.connect(func(target, _owner): eliminate(target))
	av.pop()

func _compute_results() -> Dictionary:
	return survivor_results(3)
