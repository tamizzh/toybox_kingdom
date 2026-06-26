extends Control

# ── Whole-board minimap: a painted ownership texture (no second scene render) ──
# Instead of a SubViewport re-rendering the whole 3D world top-down (a full extra
# scene pass every update), we paint ONE pixel per cell straight from the grid's
# ownership data into a tiny 128x96 texture and let the GPU upscale it with bilinear
# smoothing. Wilderness reads as a soft green patchwork; each kingdom is its own
# colour; the ruler dots are drawn on top every frame. Repaint only when the board
# actually changed (throttled by the match), so the per-frame cost is just the dots.

const MAP := Vector2(230, 172)
const RADIUS := 18.0              # rounded-rect corner radius for the map card

# Unoccupied wilderness reads as a flat dark grey — quiet backdrop so owned
# kingdom colours pop. One colour, no patchwork.
const WILD := Color("2c3038")

var _markers: Array = []
var _grid                         # TerritoryGrid (captured on first update_territory)
var _colors := {}                 # kingdom id -> Color
var _img: Image
var _tex: ImageTexture
var _buf: PackedByteArray         # reused RGBA8 scratch — allocation-free repaints
var _gw := 0
var _gh := 0
var _dirty := true                # repaint only when ownership changed, not on a timer

# world / cell / cam_env are accepted for call-site compatibility but unused now that
# the minimap paints from data instead of rendering the 3D world.
func setup(gw: int, gh: int, _world = null, _cell: float = 0.6, _cam_env = null) -> void:
	_gw = gw
	_gh = gh
	custom_minimum_size = MAP
	size = MAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth the board upscale

	_img = Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	_img.fill(WILD)
	_tex = ImageTexture.create_from_image(_img)
	_buf = PackedByteArray()
	_buf.resize(gw * gh * 4)

# The match calls this when the board may have changed (capture/retint). We capture
# the grid + palette and flag a repaint for the next _process tick.
func update_territory(grid, colors: Dictionary) -> void:
	_grid = grid
	_colors = colors
	_dirty = true

# Board went dirty — queue a repaint (same effect as update_territory's flag).
func request_render() -> void:
	_dirty = true

func set_markers(m: Array) -> void:
	_markers = m

func _process(_delta: float) -> void:
	if _dirty and _grid != null:
		_dirty = false
		_repaint()
	queue_redraw()   # the ruler dots redraw every frame on top of the static texture

# Paint one pixel per cell: flat dark grey for wilderness, the kingdom colour
# for owned land. Writes the reused buffer and uploads once (no per-pixel set_pixel).
func _repaint() -> void:
	var n := _gw * _gh
	for i in n:
		var oid: int = _grid.owner[i]
		var col: Color
		if oid == 0:
			col = WILD
		else:
			col = (_colors.get(oid, Color.WHITE) as Color).lightened(0.06)
		var o := i * 4
		_buf[o] = int(col.r * 255.0)
		_buf[o + 1] = int(col.g * 255.0)
		_buf[o + 2] = int(col.b * 255.0)
		_buf[o + 3] = 255
	_img.set_data(_gw, _gh, false, Image.FORMAT_RGBA8, _buf)
	_tex.update(_img)

const _FRAME := Color(0.05, 0.07, 0.12, 0.92)

func _draw() -> void:
	# Rounded backing card (slightly larger than the map).
	_fill_round_rect(Rect2(Vector2(-4, -4), MAP + Vector2(8, 8)), RADIUS + 3.0, _FRAME)
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, MAP), false)
		# The texture is square — repaint the four corners with the frame colour so
		# the map reads as a rounded rect on top of the rounded card.
		_round_corners(Rect2(Vector2.ZERO, MAP), RADIUS, _FRAME)
	for mk in _markers:
		var p: Vector2 = mk["pos"] * MAP
		var c: Color = mk["color"]
		if mk.get("you", false):
			draw_circle(p, 7.0, Color.WHITE)
			draw_circle(p, 4.5, c)
		else:
			draw_circle(p, 4.5, Color(0, 0, 0, 0.6))
			draw_circle(p, 3.0, c)
	# Rounded border on top.
	_stroke_round_rect(Rect2(Vector2.ZERO, MAP), RADIUS, Color(1, 1, 1, 0.30), 2.0)

# ── Rounded-rect helpers (Godot's draw_* has no native rounded rect) ──

# Build the outline polygon of a rounded rect (clockwise), `steps` per corner arc.
func _round_rect_points(r: Rect2, rad: float, steps: int = 6) -> PackedVector2Array:
	rad = min(rad, min(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	# corner: centre of the arc, start angle (degrees), going clockwise +90°
	var corners := [
		[r.position + Vector2(rad, rad), 180.0],                       # top-left
		[r.position + Vector2(r.size.x - rad, rad), 270.0],            # top-right
		[r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],   # bottom-right
		[r.position + Vector2(rad, r.size.y - rad), 90.0],             # bottom-left
	]
	for cn in corners:
		var c: Vector2 = cn[0]
		var a0: float = cn[1]
		for s in steps + 1:
			var a := deg_to_rad(a0 + 90.0 * float(s) / float(steps))
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts

func _fill_round_rect(r: Rect2, rad: float, color: Color) -> void:
	draw_colored_polygon(_round_rect_points(r, rad), color)

func _stroke_round_rect(r: Rect2, rad: float, color: Color, width: float) -> void:
	var pts := _round_rect_points(r, rad)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)

# Cover the four square corners of `r` outside the rounded arc with `color`.
func _round_corners(r: Rect2, rad: float, color: Color) -> void:
	rad = min(rad, min(r.size.x, r.size.y) * 0.5)
	var corners := [
		[r.position, r.position + Vector2(rad, rad), 180.0],
		[r.position + Vector2(r.size.x, 0), r.position + Vector2(r.size.x - rad, rad), 270.0],
		[r.position + r.size, r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],
		[r.position + Vector2(0, r.size.y), r.position + Vector2(rad, r.size.y - rad), 90.0],
	]
	for cn in corners:
		var corner: Vector2 = cn[0]
		var c: Vector2 = cn[1]
		var a0: float = cn[2]
		var pts := PackedVector2Array()
		pts.append(corner)
		var steps := 6
		for s in steps + 1:
			var a := deg_to_rad(a0 + 90.0 * float(s) / float(steps))
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, color)
