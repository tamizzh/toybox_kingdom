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

# ── Crown: chunky 3-spike crown with jewels. Replaces the 👑 emoji. ──
static func crown(ci: CanvasItem, center: Vector2, w: float, fill: Color = Color("ffc31f"), ow: float = 4.0) -> void:
	var half := w * 0.5
	var h := w * 0.62
	var by := h * 0.42
	var pts := PackedVector2Array([
		center + Vector2(-half, by),
		center + Vector2(-half, -h * 0.12),
		center + Vector2(-half * 0.42, h * 0.06),
		center + Vector2(0, -h * 0.58),
		center + Vector2(half * 0.42, h * 0.06),
		center + Vector2(half, -h * 0.12),
		center + Vector2(half, by),
	])
	var shadow_pts := PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(0, 4))
	ci.draw_colored_polygon(shadow_pts, SHADOW)
	ci.draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, OUTLINE, ow, true)
	var gem := fill.lightened(0.45)
	for peak in [Vector2(-half, -h * 0.12), Vector2(0, -h * 0.58), Vector2(half, -h * 0.12)]:
		ci.draw_circle(center + peak, w * 0.08, OUTLINE)
		ci.draw_circle(center + peak, w * 0.08 - 2.0, gem)

# ── Five-pointed star. Replaces the ⭐/🎲 emoji slots. ──
static func star(ci: CanvasItem, center: Vector2, r: float, fill: Color = Color("ffd23f"), ow: float = 4.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad: float = r if i % 2 == 0 else r * 0.46
		var ang := -PI * 0.5 + float(i) * PI / 5.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	var shadow_pts := PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(0, 4))
	ci.draw_colored_polygon(shadow_pts, SHADOW)
	ci.draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, OUTLINE, ow, true)

# ── Trophy cup. Replaces the 🏆 emoji on the results stat line. ──
static func trophy(ci: CanvasItem, center: Vector2, w: float, fill: Color = Color("ffc31f"), ow: float = 4.0) -> void:
	var hw := w * 0.5
	# Cup bowl — trapezoid wider at the top.
	var cup := PackedVector2Array([
		center + Vector2(-hw, -w * 0.55),
		center + Vector2(hw, -w * 0.55),
		center + Vector2(hw * 0.55, -w * 0.02),
		center + Vector2(-hw * 0.55, -w * 0.02),
	])
	# Handles — outlined rings either side of the bowl.
	for sx in [-1.0, 1.0]:
		var hc := center + Vector2(sx * hw * 0.95, -w * 0.42)
		ci.draw_arc(hc, w * 0.26, 0, TAU, 20, OUTLINE, ow + 3.0)
		ci.draw_arc(hc, w * 0.26, 0, TAU, 20, fill, ow)
	# Stem + base.
	ci.draw_rect(Rect2(center + Vector2(-w * 0.08, -w * 0.04), Vector2(w * 0.16, w * 0.28)), fill)
	var base := Rect2(center + Vector2(-w * 0.26, w * 0.24), Vector2(w * 0.52, w * 0.14))
	ci.draw_rect(base, fill)
	ci.draw_rect(base, OUTLINE, false, ow)
	# Bowl fill + outline on top.
	ci.draw_colored_polygon(cup, fill)
	var outline := cup.duplicate()
	outline.append(cup[0])
	ci.draw_polyline(outline, OUTLINE, ow, true)

# ── Clock face: outlined disc with two hands. For the HUD timer pill. ──
static func clock(ci: CanvasItem, center: Vector2, r: float, fill: Color = Color("ffd23f"), ow: float = 4.0) -> void:
	ci.draw_circle(center + Vector2(0, 3), r, SHADOW)
	ci.draw_circle(center, r, OUTLINE)
	ci.draw_circle(center, r - ow, fill)
	# little top button
	ci.draw_rect(Rect2(center + Vector2(-r * 0.16, -r - r * 0.22), Vector2(r * 0.32, r * 0.26)), OUTLINE)
	# hands
	ci.draw_line(center, center + Vector2(0, -r * 0.55), OUTLINE, ow * 0.7)
	ci.draw_line(center, center + Vector2(r * 0.42, r * 0.10), OUTLINE, ow * 0.7)

# ── Small pictographic action-button glyph (boost/run/fire/jump/throw/slash). ──
static func action_glyph(ci: CanvasItem, center: Vector2, r: float, kind: String, col: Color = Color.WHITE) -> void:
	var dk := OUTLINE
	match kind:
		"boost", "star":
			star(ci, center, r, col, 3.0)
		"fire", "shoot", "fire!":
			# flame teardrop
			var f := PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r * 0.7, r * 0.2),
				center + Vector2(0, r), center + Vector2(-r * 0.7, r * 0.2)])
			ci.draw_colored_polygon(f, col)
			var fo := f.duplicate(); fo.append(f[0])
			ci.draw_polyline(fo, dk, 3.0, true)
		"jump", "hop":
			# up chevron
			ci.draw_line(center + Vector2(-r * 0.7, r * 0.4), center + Vector2(0, -r * 0.6), col, 6.0)
			ci.draw_line(center + Vector2(r * 0.7, r * 0.4), center + Vector2(0, -r * 0.6), col, 6.0)
			ci.draw_line(center + Vector2(-r * 0.7, r * 0.9), center + Vector2(0, -r * 0.1), col, 6.0)
			ci.draw_line(center + Vector2(r * 0.7, r * 0.9), center + Vector2(0, -r * 0.1), col, 6.0)
		"throw", "bomb":
			ci.draw_circle(center, r * 0.62, col)
			ci.draw_circle(center, r * 0.62, dk, false, 3.0)
			ci.draw_line(center + Vector2(0, -r * 0.62), center + Vector2(r * 0.5, -r), col, 4.0)
		"slash", "sword", "hit":
			stroke(ci, center + Vector2(-r * 0.7, r * 0.7), center + Vector2(r * 0.7, -r * 0.7), 5.0, col)
		"tap":
			# Finger tap: small filled circle (the touch point)
			ci.draw_circle(center + Vector2(0, r * 0.30), r * 0.48, col)
			ci.draw_circle(center + Vector2(0, r * 0.30), r * 0.48, dk, false, 3.0)
			# Ripple rings
			ci.draw_arc(center + Vector2(0, r * 0.30), r * 0.72, 0, TAU, 48, Color(col, 0.55), 2.5)
			ci.draw_arc(center + Vector2(0, r * 0.30), r * 0.95, 0, TAU, 48, Color(col, 0.28), 2.0)
		"hold":
			# Crown: 3-point crown silhouette
			crown(ci, center, r, col, 3.0)
		"kick":
			# Boot kick: angled foot shape
			stroke(ci, center + Vector2(-r * 0.6, r * 0.3), center + Vector2(r * 0.6, -r * 0.5), 6.0, col)
			stroke(ci, center + Vector2(r * 0.6, -r * 0.5), center + Vector2(r * 0.8, r * 0.3), 6.0, col)
		"run":
			# Running figure: head + leaning torso + striding legs + swinging arms.
			var head := center + Vector2(r * 0.28, -r * 0.62)
			ci.draw_circle(head, r * 0.30, col)
			ci.draw_circle(head, r * 0.30, dk, false, 3.0)
			var hip := center + Vector2(-r * 0.05, r * 0.18)
			# torso (lean forward)
			stroke(ci, head + Vector2(0, r * 0.28), hip, 5.0, col)
			# legs in stride
			var knee := hip + Vector2(r * 0.45, r * 0.30)
			stroke(ci, hip, knee, 5.0, col)
			stroke(ci, knee, knee + Vector2(r * 0.10, r * 0.55), 5.0, col)
			stroke(ci, hip, hip + Vector2(-r * 0.45, r * 0.55), 5.0, col)
			stroke(ci, hip + Vector2(-r * 0.45, r * 0.55), hip + Vector2(-r * 0.70, r * 0.85), 5.0, col)
			# arms swinging
			var shoulder := center + Vector2(r * 0.10, -r * 0.18)
			stroke(ci, shoulder, shoulder + Vector2(r * 0.55, r * 0.10), 5.0, col)
			stroke(ci, shoulder, shoulder + Vector2(-r * 0.45, r * 0.18), 5.0, col)
		_:
			# generic forward arrow
			var t := PackedVector2Array([
				center + Vector2(-r * 0.5, -r * 0.7), center + Vector2(r * 0.7, 0),
				center + Vector2(-r * 0.5, r * 0.7)])
			ci.draw_colored_polygon(t, col)
			var to := t.duplicate(); to.append(t[0])
			ci.draw_polyline(to, dk, 3.0, true)

# ── Thick outlined stroke: a dark underlay line with a coloured line on top. ──
static func stroke(ci: CanvasItem, a: Vector2, b: Vector2, w: float, fill: Color) -> void:
	ci.draw_line(a, b, OUTLINE, w + 4.0)
	ci.draw_line(a, b, fill, w)
	# round the caps
	ci.draw_circle(a, w * 0.5, fill)
	ci.draw_circle(b, w * 0.5, fill)
