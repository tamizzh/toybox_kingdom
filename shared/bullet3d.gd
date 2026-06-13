class_name Bullet3D
extends Area3D

# Simple 3D projectile travelling on the XZ plane. Emits hit_player when it
# overlaps an Avatar3D that isn't its owner.

signal hit_player(target_id, owner_id)

var velocity: Vector3 = Vector3.ZERO
var owner_id: int = -1
var life: float = 2.2

func setup(p_owner: int, dir: Vector3, color: Color, spd: float) -> void:
	owner_id = p_owner
	velocity = dir.normalized() * spd
	collision_layer = 0
	collision_mask = 1            # detect avatars (layer 1)
	monitoring = true

	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.28
	col.shape = s
	add_child(col)

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5
	mi.material_override = m
	add_child(mi)

	body_entered.connect(_on_body_entered)

func _physics_process(dt: float) -> void:
	global_position += velocity * dt
	life -= dt
	if life <= 0.0:
		queue_free()

func _on_body_entered(b: Node) -> void:
	if b is Avatar3D and b.player_id != owner_id and not b.dead:
		hit_player.emit(b.player_id, owner_id)
		queue_free()
