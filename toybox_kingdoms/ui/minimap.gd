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
var _active_w: int = -1           # active zone width (-1 = full grid)
var _active_h: int = -1           # active zone height
var _land_mask: PackedByteArray   # WORLD_CONQUEST per-cell mask (empty = not used)

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

func set_active_half(aw: int, ah: int) -> void:
	_active_w = aw
	_active_h = ah
	_dirty = true

func set_land_mask(mask: PackedByteArray) -> void:
	_land_mask = mask
	_dirty = true

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

# A painted frame drawn around the map instead of the procedural card/border. The
# frame art's transparent window was measured (see prep) so the map texture lands
# exactly inside it.
var _frame_tex: Texture2D
# Window of the frame art as fractions of its size: x:[0.0707,0.9265], y:[0.0984,0.8903].
const _WIN_L := 0.0386
const _WIN_R := 0.9496
const _WIN_T := 0.0635
const _WIN_B := 0.9048

func set_frame(tex: Texture2D) -> void:
	_frame_tex = tex
	queue_redraw()

# Rect (in this control's space) to draw the frame at so its window covers the map.
func _frame_rect() -> Rect2:
	var fw := MAP.x / (_WIN_R - _WIN_L)
	var fh := MAP.y / (_WIN_B - _WIN_T)
	return Rect2(Vector2(-_WIN_L * fw, -_WIN_T * fh), Vector2(fw, fh))

func _process(_delta: float) -> void:
	if _dirty and _grid != null:
		_dirty = false
		_repaint()
	queue_redraw()   # the ruler dots redraw every frame on top of the static texture

# Paint one pixel per cell: flat dark grey for wilderness, the kingdom colour
# for owned land. Writes the reused buffer and uploads once (no per-pixel set_pixel).
const FROST := Color(0.78, 0.90, 0.97, 1.0)   # ice blue — matches territory_ground frozen zone

func _repaint() -> void:
	var use_mask := _land_mask.size() == _gw * _gh
	# Rectangular active zone bounds (used when no per-cell mask).
	var ax0 := 0; var ay0 := 0; var ax1 := _gw; var ay1 := _gh
	if not use_mask and _active_w > 0 and _active_h > 0:
		ax0 = (_gw - _active_w) / 2
		ay0 = (_gh - _active_h) / 2
		ax1 = ax0 + _active_w
		ay1 = ay0 + _active_h
	for iy in _gh:
		for ix in _gw:
			var i := iy * _gw + ix
			var col: Color
			var is_frozen: bool
			if use_mask:
				is_frozen = _land_mask[i] == 0
			else:
				is_frozen = ix < ax0 or ix >= ax1 or iy < ay0 or iy >= ay1
			if is_frozen:
				col = FROST
			else:
				var oid: int = _grid.owner[i]
				col = WILD if oid == 0 else (_colors.get(oid, Color.WHITE) as Color).lightened(0.06)
			var o := i * 4
			_buf[o]     = int(col.r * 255.0)
			_buf[o + 1] = int(col.g * 255.0)
			_buf[o + 2] = int(col.b * 255.0)
			_buf[o + 3] = 255
	_img.set_data(_gw, _gh, false, Image.FORMAT_RGBA8, _buf)
	_tex.update(_img)

const _FRAME := Color(0.05, 0.07, 0.12, 0.92)

func _draw() -> void:
	if _frame_tex == null:
		# Rounded backing card (slightly larger than the map).
		_fill_round_rect(Rect2(Vector2(-4, -4), MAP + Vector2(8, 8)), RADIUS + 3.0, _FRAME)
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, MAP), false)
		if _frame_tex == null:
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
	if _frame_tex != null:
		# Painted frame on top — its transparent window lets the map show through.
		draw_texture_rect(_frame_tex, _frame_rect(), false)
	else:
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
