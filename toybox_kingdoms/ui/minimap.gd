extends Control

# ── Whole-board minimap: a painted ownership texture (no second scene render) ──
# Instead of a SubViewport re-rendering the whole 3D world top-down (a full extra
# scene pass every update), we paint ONE pixel per cell straight from the grid's
# ownership data into a tiny 128x96 texture and let the GPU upscale it with bilinear
# smoothing. Wilderness reads as a soft green patchwork; each kingdom is its own
# colour; the ruler dots are drawn on top every frame. Repaint only when the board
# actually changed (throttled by the match), so the per-frame cost is just the dots.

const MAP := Vector2(230, 172)

# Two wilderness greens in coarse blocks → a soft patchwork (not a flat slab) once
# the small texture is upscaled. BLOCK is in cells; ~8 keeps patches readable on map.
const WILD_A := Color("3f6b2a")
const WILD_B := Color("4d7e31")
const BLOCK := 8

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
	_img.fill(WILD_A)
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

# Paint one pixel per cell: a soft green patchwork for wilderness, the kingdom colour
# for owned land. Writes the reused buffer and uploads once (no per-pixel set_pixel).
func _repaint() -> void:
	var n := _gw * _gh
	for i in n:
		var oid: int = _grid.owner[i]
		var col: Color
		if oid == 0:
			var cx := i % _gw
			var cy := i / _gw
			col = WILD_A if (((cx / BLOCK) ^ (cy / BLOCK)) & 1) == 0 else WILD_B
		else:
			col = (_colors.get(oid, Color.WHITE) as Color).lightened(0.06)
		var o := i * 4
		_buf[o] = int(col.r * 255.0)
		_buf[o + 1] = int(col.g * 255.0)
		_buf[o + 2] = int(col.b * 255.0)
		_buf[o + 3] = 255
	_img.set_data(_gw, _gh, false, Image.FORMAT_RGBA8, _buf)
	_tex.update(_img)

func _draw() -> void:
	draw_rect(Rect2(Vector2(-4, -4), MAP + Vector2(8, 8)), Color(0.05, 0.07, 0.12, 0.92), true)
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, MAP), false)
	for mk in _markers:
		var p: Vector2 = mk["pos"] * MAP
		var c: Color = mk["color"]
		if mk.get("you", false):
			draw_circle(p, 7.0, Color.WHITE)
			draw_circle(p, 4.5, c)
		else:
			draw_circle(p, 4.5, Color(0, 0, 0, 0.6))
			draw_circle(p, 3.0, c)
	draw_rect(Rect2(Vector2.ZERO, MAP), Color(1, 1, 1, 0.30), false, 2.0)
