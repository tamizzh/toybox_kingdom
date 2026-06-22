class_name DrawKit
extends RefCounted

# Reusable "sticker" drawing primitives in the JindoBlu / 1234-Player-Games style:
# thick black outline + soft drop shadow + bright flat fill + rounded shapes.
# All helpers are static and draw onto any CanvasItem passed as `ci`.

const OUTLINE := Color("17191f")
const SHADOW  := Color(0, 0, 0, 0.16)

# ── Round blob: filled circle with drop shadow and shiny catch-light. ──
static func blob(ci: CanvasItem, pos: Vector2, r: float, fill: Color, ow: float = 5.0, shadow: bool = true) -> void:
	if shadow:
		ci.draw_circle(pos + Vector2(0, r * 0.16 + 3.0), r, SHADOW)
	ci.draw_circle(pos, r, fill)
	# Primary shine — soft upper-left blob
	ci.draw_circle(pos + Vector2(-r * 0.27, -r * 0.31), r * 0.40,
		Color(1, 1, 1, 0.28))
	# Secondary catch-light — crisp bright dot for the shiny-toy read
	ci.draw_circle(pos + Vector2(-r * 0.36, -r * 0.42), r * 0.16,
		Color(1, 1, 1, 0.72))

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

# ── Outlined filled polygon with a drop shadow (sticker building blocks). ──
static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, ow: float = 3.0) -> void:
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, 4))
	ci.draw_colored_polygon(sh, SHADOW)
	ci.draw_colored_polygon(pts, fill)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, OUTLINE, ow, true)

# ── HUD pictograms (build toolbar + action stack). Drawn centred at `center`,
# sized to radius `r`. Dispatch through hud_glyph(); unknown kinds fall back to
# the gameplay action_glyph set so nothing renders blank. ──
static func hud_glyph(ci: CanvasItem, center: Vector2, r: float, kind: String, col: Color = Color.WHITE) -> void:
	match kind:
		"castle": castle(ci, center, r, col)
		"tower": tower(ci, center, r, col)
		"farm": farm(ci, center, r, col)
		"barracks": barracks(ci, center, r, col)
		"shield": shield(ci, center, r, col)
		"map", "pin": pin(ci, center, r, col)
		"coin": coin(ci, center, r, col)
		_: action_glyph(ci, center, r, kind, col)

# ── Castle: crenellated keep with a central gate. ──
static func castle(ci: CanvasItem, center: Vector2, r: float, col: Color = Color.WHITE) -> void:
	var w := r * 1.5
	var h := r * 1.2
	var x0 := center.x - w * 0.5
	var top := center.y - h * 0.5
	var bot := center.y + h * 0.5
	var merlon := w / 5.0
	# body with 3 merlons (battlements) along the top edge
	var pts := PackedVector2Array([
		Vector2(x0, bot), Vector2(x0, top + merlon * 0.6),
		Vector2(x0, top), Vector2(x0 + merlon, top),
		Vector2(x0 + merlon, top + merlon * 0.6), Vector2(x0 + merlon * 2.0, top + merlon * 0.6),
		Vector2(x0 + merlon * 2.0, top), Vector2(x0 + merlon * 3.0, top),
		Vector2(x0 + merlon * 3.0, top + merlon * 0.6), Vector2(x0 + merlon * 4.0, top + merlon * 0.6),
		Vector2(x0 + merlon * 4.0, top), Vector2(x0 + w, top),
		Vector2(x0 + w, top + merlon * 0.6), Vector2(x0 + w, bot),
	])
	_poly(ci, pts, col)
	# gate
	var gw := w * 0.24
	var gate := Rect2(center.x - gw * 0.5, bot - h * 0.45, gw, h * 0.45)
	ci.draw_rect(gate, OUTLINE)

# ── Tower: tall keep with battlements and a pennant flag. ──
static func tower(ci: CanvasItem, center: Vector2, r: float, col: Color = Color.WHITE) -> void:
	var w := r * 0.95
	var h := r * 1.5
	var x0 := center.x - w * 0.5
	var top := center.y - h * 0.4
	var bot := center.y + h * 0.6
	var m := w / 3.0
	var pts := PackedVector2Array([
		Vector2(x0, bot), Vector2(x0, top),
		Vector2(x0 + m, top), Vector2(x0 + m, top - m * 0.6),
		Vector2(x0 + m * 2.0, top - m * 0.6), Vector2(x0 + m * 2.0, top),
		Vector2(x0 + w, top), Vector2(x0 + w, bot),
	])
	_poly(ci, pts, col)
	# flag pole + pennant
	var pole_top := Vector2(center.x, top - m * 1.7)
	ci.draw_line(Vector2(center.x, top - m * 0.6), pole_top, OUTLINE, 3.0)
	_poly(ci, PackedVector2Array([
		pole_top, pole_top + Vector2(r * 0.6, r * 0.18), pole_top + Vector2(0, r * 0.36)]),
		col, 2.5)

# ── Farm: barn silhouette (gable roof + body + door). ──
static func farm(ci: CanvasItem, center: Vector2, r: float, col: Color = Color.WHITE) -> void:
	var w := r * 1.5
	var x0 := center.x - w * 0.5
	var top := center.y - r * 0.65
	var eave := center.y - r * 0.12
	var bot := center.y + r * 0.65
	var pts := PackedVector2Array([
		Vector2(x0, bot), Vector2(x0, eave),
		Vector2(center.x, top), Vector2(x0 + w, eave),
		Vector2(x0 + w, bot),
	])
	_poly(ci, pts, col)
	# door
	var dw := w * 0.26
	ci.draw_rect(Rect2(center.x - dw * 0.5, bot - r * 0.6, dw, r * 0.6), OUTLINE)

# ── Barracks: crossed swords (military muster). ──
static func barracks(ci: CanvasItem, center: Vector2, r: float, col: Color = Color.WHITE) -> void:
	for s in [-1.0, 1.0]:
		var tip := center + Vector2(s * r * 0.8, -r * 0.8)
		var hilt := center + Vector2(-s * r * 0.7, r * 0.8)
		stroke(ci, hilt, tip, 5.0, col)
		# crossguard near the hilt
		var dir := (tip - hilt).normalized()
		var perp := Vector2(-dir.y, dir.x) * r * 0.28
		var guard := hilt + dir * r * 0.3
		stroke(ci, guard - perp, guard + perp, 4.0, col)

# ── Shield: heater shield with a centre divide. ──
static func shield(ci: CanvasItem, center: Vector2, r: float, col: Color = Color.WHITE) -> void:
	var w := r * 1.3
	var top := center.y - r * 0.9
	var pts := PackedVector2Array([
		Vector2(center.x - w * 0.5, top),
		Vector2(center.x + w * 0.5, top),
		Vector2(center.x + w * 0.5, center.y + r * 0.05),
		Vector2(center.x, center.y + r * 1.0),
		Vector2(center.x - w * 0.5, center.y + r * 0.05),
	])
	_poly(ci, pts, col)
	ci.draw_line(Vector2(center.x, top + 3.0), Vector2(center.x, center.y + r * 0.78),
		Color(OUTLINE, 0.5), 2.5)

# ── Pin: map location marker (teardrop + hole). ──
static func pin(ci: CanvasItem, center: Vector2, r: float, col: Color = Color.WHITE) -> void:
	var head := center + Vector2(0, -r * 0.25)
	var hr := r * 0.62
	# point
	_poly(ci, PackedVector2Array([
		head + Vector2(-hr * 0.72, hr * 0.55),
		head + Vector2(hr * 0.72, hr * 0.55),
		center + Vector2(0, r * 1.0)]), col, 2.5)
	ci.draw_circle(head + Vector2(0, 4), hr, SHADOW)
	ci.draw_circle(head, hr, col)
	ci.draw_arc(head, hr, 0, TAU, 28, OUTLINE, 3.0)
	ci.draw_circle(head, hr * 0.36, OUTLINE)

# ── Coin: outlined gold disc with an inner ring + sparkle (for cost rows). ──
static func coin(ci: CanvasItem, center: Vector2, r: float, col: Color = Color("ffc31f")) -> void:
	ci.draw_circle(center + Vector2(0, 3), r, SHADOW)
	ci.draw_circle(center, r, OUTLINE)
	ci.draw_circle(center, r - 2.5, col)
	ci.draw_arc(center, r * 0.62, 0, TAU, 24, col.darkened(0.22), 2.0)
	# upper-left catch-light + a tiny sparkle pip in the middle
	ci.draw_circle(center + Vector2(-r * 0.32, -r * 0.34), r * 0.20, col.lightened(0.5))
	ci.draw_circle(center, r * 0.16, col.lightened(0.4))
