class_name PlayerController
extends CharacterBody2D

# Generic reusable avatar. Reads InputManager by default; games can also
# drive it manually via move_manual(). Collides with arena walls (layer 2)
# but passes through other avatars (handled per-game by distance checks).

@export var speed: float = 320.0
@export var auto_input: bool = true
@export var momentum: float = 0.0      # 0 = snappy; >0 enables sliding (ice)
@export var acceleration: float = 2200.0

var data: PlayerData
var player_id: int = 0
var radius: float = 26.0
var dead: bool = false

@onready var figure: FlatFigure = $Figure
@onready var shape: CollisionShape2D = $Shape

func setup(p: PlayerData) -> void:
	data = p
	player_id = p.id
	figure.set_color(p.color)
	figure.set_radius(radius)

func _physics_process(delta: float) -> void:
	if dead or not auto_input:
		return
	apply_movement(InputManager.get_move(player_id), delta)

func apply_movement(dir: Vector2, delta: float) -> void:
	var target := dir * speed
	if momentum > 0.0:
		velocity = velocity.move_toward(target, acceleration * delta)
	else:
		velocity = target
	move_and_slide()

func move_manual(dir: Vector2, delta: float) -> void:
	apply_movement(dir, delta)

func set_dead() -> void:
	dead = true
	velocity = Vector2.ZERO
	visible = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

func revive(pos: Vector2) -> void:
	dead = false
	visible = true
	position = pos
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 2)

func pop() -> void:
	if figure:
		figure.pop()
