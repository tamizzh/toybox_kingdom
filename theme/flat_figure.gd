class_name FlatFigure
extends Node2D

# Sticker-style avatar: a chunky round mascot with a thick black outline,
# a soft drop shadow, two little feet, and googly eyes — the JindoBlu look.

@export var color: Color = Color.WHITE
@export var radius: float = 26.0

var look_dir: Vector2 = Vector2(0, 0.25)   # where the eyes glance
var body_tex: Texture2D = null             # optional Firefly character body
var body_color_as_line: bool = false       # keep body neutral; show colour as a bar below
var face_angle: float = 0.0                 # rotate the body sprite (radians); 0 = gun right

func set_color(c: Color) -> void:
	color = c
	queue_redraw()

func set_body_texture(t: Texture2D) -> void:
	body_tex = t
	queue_redraw()

func set_radius(r: float) -> void:
	radius = r
	queue_redraw()

func set_look(dir: Vector2) -> void:
	if dir.length() > 0.05:
		look_dir = dir.normalized()
		queue_redraw()

func set_face_angle(a: float) -> void:
	face_angle = a
	queue_redraw()

func pop() -> void:
	# Snappy squash/stretch feedback via node scale (~180ms, springy).
	scale = Vector2(1.28, 0.78)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2.ONE, 0.18)

func _draw() -> void:
	var r := radius
	if body_tex:
		_draw_sprite_body(r)
		return
	# ── Procedural mascot (default, no asset present) ──
	# feet — two small darker nubs poking out below the body
	var foot_r := r * 0.32
	for sx in [-1.0, 1.0]:
		DrawKit.blob(self, Vector2(sx * r * 0.46, r * 0.6), foot_r, color.darkened(0.22), 4.0, true)
	# body — big round blob
	DrawKit.blob(self, Vector2.ZERO, r, color, 5.0, true)
	# face
	DrawKit.eyes(self, Vector2(0, -r * 0.06), r, look_dir)

func _draw_sprite_body(r: float) -> void:
	# Character body is a white-fill + black-outline PNG with no eyes; tinting by
	# the player colour turns the white fill into that colour while the black
	# outline stays black. Procedural eyes are drawn on top so faces stay white.
	var box := r * 2.6
	var dest := Rect2(-box * 0.5, -box * 0.5, box, box)
	# body (+ matching shadow) rotated to face movement; gun-right sprite = 0 rad
	if face_angle != 0.0:
		draw_set_transform(Vector2.ZERO, face_angle, Vector2.ONE)
	draw_texture_rect(body_tex, Rect2(dest.position + Vector2(0, r * 0.18 + 3.0), dest.size), false, DrawKit.SHADOW)
	# normally the white body is tinted to the player colour; in "line" mode the
	# body stays neutral white and the colour is shown as a bar underneath.
	var body_tint := Color.WHITE if body_color_as_line else color
	draw_texture_rect(body_tex, dest, false, body_tint)
	if face_angle != 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # reset -> bar/eyes upright
	if body_color_as_line:
		var bw := r * 1.9
		var bh := r * 0.28
		var by := r * 1.00
		DrawKit.card(self, Rect2(-bw * 0.5, by, bw, bh), bh * 0.5, color, 3.0, false)
		return   # tank: no googly eyes
	DrawKit.eyes(self, Vector2(0, -r * 0.10), r, look_dir)
