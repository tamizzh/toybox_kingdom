class_name DrawKit
extends RefCounted

# Reusable "sticker" drawing primitives in the JindoBlu / 1234-Player-Games style:
# thick black outline + soft drop shadow + bright flat fill + rounded shapes.
# All helpers are static and draw onto any CanvasItem passed as `ci`.

const OUTLINE := Color("17191f")
const SHADOW  := Color(0, 0, 0, 0.16)

# ── Round blob: filled circle with a thick black outline and a drop shadow. ──
static func blob(ci: CanvasItem, pos: Vector2, r: float, fill: Color, ow: float = 5.0, shadow: bool = true) -> void:
	if shadow:
		ci.draw_circle(pos + Vector2(0, r * 0.16 + 3.0), r, SHADOW)
	ci.draw_circle(pos, r, OUTLINE)
	ci.draw_circle(pos, r - ow, fill)

# ── Target / pickup dot: outlined disc with a solid centre pip (archery, orbs). ──
static func ring_dot(ci: CanvasItem, pos: Vector2, r: float, fill: Color, pip: Color = OUTLINE) -> void:
	ci.draw_circle(pos + Vector2(0, 3), r, SHADOW)
	ci.draw_circle(pos, r, OUTLINE)
	ci.draw_circle(pos, r - r * 0.18, fill)
	ci.draw_circle(pos, r * 0.34, pip)

# ── Googly eyes: two white outlined circles with dark pupils. The signature face. ──
static func eyes(ci: CanvasItem, center: Vector2, r: float, look: Vector2 = Vector2(0, 0.25)) -> void:
	var ex := r * 0.42
	var ey := -r * 0.08
	var er := r * 0.34
	for sx in [-1.0, 1.0]:
		var e := center + Vector2(sx * ex, ey)
		ci.draw_circle(e, er, OUTLINE)
		ci.draw_circle(e, er - 2.5, Color.WHITE)
		ci.draw_circle(e + look * er * 0.45, er * 0.46, OUTLINE)

# ── Filled rounded rectangle (no outline). Building block for cards. ──
static func rounded_rect(ci: CanvasItem, rect: Rect2, rad: float, col: Color) -> void:
	rad = min(rad, min(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var s := rect.size
	ci.draw_rect(Rect2(p.x + rad, p.y, s.x - 2.0 * rad, s.y), col)
	ci.draw_rect(Rect2(p.x, p.y + rad, s.x, s.y - 2.0 * rad), col)
	ci.draw_circle(p + Vector2(rad, rad), rad, col)
	ci.draw_circle(p + Vector2(s.x - rad, rad), rad, col)
	ci.draw_circle(p + Vector2(rad, s.y - rad), rad, col)
	ci.draw_circle(p + Vector2(s.x - rad, s.y - rad), rad, col)

# ── Sticker card: rounded panel with thick outline + drop shadow. ──
static func card(ci: CanvasItem, rect: Rect2, rad: float, fill: Color, ow: float = 4.0, shadow: bool = true) -> void:
	if shadow:
		rounded_rect(ci, Rect2(rect.position + Vector2(0, 5), rect.size), rad, SHADOW)
	rounded_rect(ci, rect, rad, OUTLINE)
	rounded_rect(ci, Rect2(rect.position + Vector2(ow, ow), rect.size - Vector2(ow, ow) * 2.0), maxf(rad - ow, 2.0), fill)

# ── Thick outlined stroke: a dark underlay line with a coloured line on top. ──
static func stroke(ci: CanvasItem, a: Vector2, b: Vector2, w: float, fill: Color) -> void:
	ci.draw_line(a, b, OUTLINE, w + 4.0)
	ci.draw_line(a, b, fill, w)
	# round the caps
	ci.draw_circle(a, w * 0.5, fill)
	ci.draw_circle(b, w * 0.5, fill)
