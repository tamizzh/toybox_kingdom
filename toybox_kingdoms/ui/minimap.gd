extends Control

# ── Whole-board minimap: a painted ownership texture (no second scene render) ──
# Paints one pixel per _MM_SCALE×_MM_SCALE block of grid cells into a small
# ImageTexture, then lets the GPU bilinear-upscale it to MAP size. At scale 3 the
# texture is 128×96 (12k pixels) regardless of the 384×288 grid — 9× cheaper than
# painting one pixel per cell, with no visible quality loss at minimap display size.

const MAP := Vector2(230, 172)
const RADIUS := 18.0

const WILD  := Color("2c3038")
const FROST := Color(0.78, 0.90, 0.97, 1.0)   # ice blue — matches territory_ground frozen zone

# One minimap pixel covers this many grid cells in each axis.
# 384/3 = 128, 288/3 = 96 → same pixel density as the original 128×96 grid.
const _MM_SCALE := 4

var _markers: Array = []
var _grid
var _colors := {}
var _img: Image
var _tex: ImageTexture
var _buf: PackedByteArray   # reused RGBA8 scratch at texture resolution
var _gw := 0                # full grid width  (for land_mask / active-zone indexing)
var _gh := 0                # full grid height
var _tw := 0                # texture width  = _gw / _MM_SCALE
var _th := 0                # texture height = _gh / _MM_SCALE
var _dirty := true
var _active_w: int = -1
var _active_h: int = -1
var _land_mask: PackedByteArray   # WORLD_CONQUEST per-cell mask at full grid resolution
var _base_built := false
var _cr := PackedByteArray()   # per-oid lightened colour bytes (index = kingdom id)
var _cg := PackedByteArray()
var _cb := PackedByteArray()

func setup(gw: int, gh: int, _world = null, _cell: float = 0.6, _cam_env = null) -> void:
	_gw = gw
	_gh = gh
	_tw = gw / _MM_SCALE
	_th = gh / _MM_SCALE
	custom_minimum_size = MAP
	size = MAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_img = Image.create(_tw, _th, false, Image.FORMAT_RGBA8)
	_img.fill(WILD)
	_tex = ImageTexture.create_from_image(_img)
	_buf = PackedByteArray()
	_buf.resize(_tw * _th * 4)
	_base_built = false

func set_active_half(aw: int, ah: int) -> void:
	_active_w = aw
	_active_h = ah
	_base_built = false
	_dirty = true

func set_land_mask(mask: PackedByteArray) -> void:
	_land_mask = mask
	_base_built = false
	_dirty = true

func update_territory(grid, colors: Dictionary) -> void:
	_grid = grid
	_colors = colors
	_dirty = true

func request_render() -> void:
	_dirty = true

func set_markers(m: Array) -> void:
	_markers = m
	queue_redraw()

var _frame_tex: Texture2D
const _WIN_L := 0.0386
const _WIN_R := 0.9496
const _WIN_T := 0.0635
const _WIN_B := 0.9048

func set_frame(tex: Texture2D) -> void:
	_frame_tex = tex
	queue_redraw()

func _frame_rect() -> Rect2:
	var fw := MAP.x / (_WIN_R - _WIN_L)
	var fh := MAP.y / (_WIN_B - _WIN_T)
	return Rect2(Vector2(-_WIN_L * fw, -_WIN_T * fh), Vector2(fw, fh))

func _process(_delta: float) -> void:
	if _dirty and _grid != null:
		_dirty = false
		_repaint()
		queue_redraw()

# Is the grid cell (gx, gy) / flat-index gi frozen (ocean or outside active zone)?
func _is_frozen(gi: int, gx: int, gy: int, use_mask: bool,
		ax0: int, ay0: int, ax1: int, ay1: int) -> bool:
	if use_mask:
		return _land_mask[gi] == 0
	return gx < ax0 or gx >= ax1 or gy < ay0 or gy >= ay1

# Paint the static frost/wild backdrop into _buf at texture resolution, once per setup.
func _build_base() -> void:
	var use_mask := _land_mask.size() == _gw * _gh
	var ax0 := 0; var ay0 := 0; var ax1 := _gw; var ay1 := _gh
	if not use_mask and _active_w > 0 and _active_h > 0:
		ax0 = (_gw - _active_w) / 2
		ay0 = (_gh - _active_h) / 2
		ax1 = ax0 + _active_w
		ay1 = ay0 + _active_h
	var frost_r := int(FROST.r * 255.0); var frost_g := int(FROST.g * 255.0); var frost_b := int(FROST.b * 255.0)
	var wild_r  := int(WILD.r  * 255.0); var wild_g  := int(WILD.g  * 255.0); var wild_b  := int(WILD.b  * 255.0)
	for ty in _th:
		var trow := ty * _tw
		var gy := ty * _MM_SCALE
		var grow := gy * _gw
		for tx in _tw:
			var gx := tx * _MM_SCALE
			var gi := grow + gx
			var o := (trow + tx) * 4
			if _is_frozen(gi, gx, gy, use_mask, ax0, ay0, ax1, ay1):
				_buf[o] = frost_r; _buf[o+1] = frost_g; _buf[o+2] = frost_b
			else:
				_buf[o] = wild_r;  _buf[o+1] = wild_g;  _buf[o+2] = wild_b
			_buf[o+3] = 255
	_base_built = true

func _repaint() -> void:
	if not _base_built:
		_build_base()

	# Precompute per-kingdom lightened colour bytes (avoids Color alloc + Dict.get per pixel).
	_cr.resize(256); _cg.resize(256); _cb.resize(256)
	for oid_key in _colors.keys():
		var oi: int = oid_key
		var lc: Color = (_colors[oi] as Color).lightened(0.06)
		_cr[oi] = int(lc.r * 255.0); _cg[oi] = int(lc.g * 255.0); _cb[oi] = int(lc.b * 255.0)

	var use_mask := _land_mask.size() == _gw * _gh
	var ax0 := 0; var ay0 := 0; var ax1 := _gw; var ay1 := _gh
	if not use_mask and _active_w > 0 and _active_h > 0:
		ax0 = (_gw - _active_w) / 2
		ay0 = (_gh - _active_h) / 2
		ax1 = ax0 + _active_w
		ay1 = ay0 + _active_h
	var wild_r  := int(WILD.r  * 255.0); var wild_g  := int(WILD.g  * 255.0); var wild_b  := int(WILD.b  * 255.0)
	var frost_r := int(FROST.r * 255.0); var frost_g := int(FROST.g * 255.0); var frost_b := int(FROST.b * 255.0)

	# Loop only the owned-bbox in TEXTURE coords (each step covers _MM_SCALE grid cells).
	# Cells outside this box are never owned, so the base backdrop in _buf is already correct.
	var tx0 := 0; var ty0 := 0; var tx1 := -1; var ty1 := -1
	if _grid.has_owned():
		tx0 = _grid.owned_min.x / _MM_SCALE
		ty0 = _grid.owned_min.y / _MM_SCALE
		tx1 = _grid.owned_max.x / _MM_SCALE
		ty1 = _grid.owned_max.y / _MM_SCALE

	for ty in range(ty0, ty1 + 1):
		var trow := ty * _tw
		var gy := ty * _MM_SCALE
		var grow := gy * _gw
		for tx in range(tx0, tx1 + 1):
			var gx := tx * _MM_SCALE
			var gi := grow + gx          # sample top-left cell of the block
			var o := (trow + tx) * 4
			var oid: int = _grid.owner[gi]
			if oid == 0:
				if _is_frozen(gi, gx, gy, use_mask, ax0, ay0, ax1, ay1):
					_buf[o] = frost_r; _buf[o+1] = frost_g; _buf[o+2] = frost_b
				else:
					_buf[o] = wild_r;  _buf[o+1] = wild_g;  _buf[o+2] = wild_b
			else:
				_buf[o] = _cr[oid]; _buf[o+1] = _cg[oid]; _buf[o+2] = _cb[oid]
			_buf[o+3] = 255

	_img.set_data(_tw, _th, false, Image.FORMAT_RGBA8, _buf)
	_tex.update(_img)

const _FRAME := Color(0.05, 0.07, 0.12, 0.92)

func _draw() -> void:
	if _frame_tex == null:
		_fill_round_rect(Rect2(Vector2(-4, -4), MAP + Vector2(8, 8)), RADIUS + 3.0, _FRAME)
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, MAP), false)
		if _frame_tex == null:
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
		draw_texture_rect(_frame_tex, _frame_rect(), false)
	else:
		_stroke_round_rect(Rect2(Vector2.ZERO, MAP), RADIUS, Color(1, 1, 1, 0.30), 2.0)

# ── Rounded-rect helpers ──────────────────────────────────────────────────────

func _round_rect_points(r: Rect2, rad: float, steps: int = 6) -> PackedVector2Array:
	rad = min(rad, min(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(rad, rad), 180.0],
		[r.position + Vector2(r.size.x - rad, rad), 270.0],
		[r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],
		[r.position + Vector2(rad, r.size.y - rad), 90.0],
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
		for s in 7:
			var a := deg_to_rad(a0 + 90.0 * float(s) / 6.0)
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, color)
