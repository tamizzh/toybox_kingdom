class_name Bullet
extends Area2D

# Reusable projectile for shooters/tank. Detects avatars (physics layer 1).

signal hit_player(target_id, owner_id)

var velocity: Vector2 = Vector2.ZERO
var owner_id: int = -1
var speed: float = 620.0
var life: float = 2.5
var radius: float = 9.0
var color: Color = Color.WHITE

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func setup(p_owner_id: int, direction: Vector2, col: Color, p_speed: float = 620.0) -> void:
	owner_id = p_owner_id
	speed = p_speed
	velocity = direction.normalized() * speed
	color = col
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is PlayerController and body.player_id != owner_id and not body.dead:
		hit_player.emit(body.player_id, owner_id)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
