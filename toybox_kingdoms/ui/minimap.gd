extends Control

# ── Whole-board minimap: a live top-down render of the ACTUAL 3D world ─────────
# A SubViewport that shares the main World3D, viewed by an orthographic camera
# looking straight down over the board, gives a real aerial view (plates, grass,
# castles) instead of a pixel-painted blob. The heavy 3D render is throttled to a
# few Hz; the ruler dots are drawn on top every frame.

const MAP := Vector2(230, 172)
const VP := Vector2i(248, 186)      # ~4:3, matches the 128x96 board aspect

var _markers: Array = []
var _vp: SubViewport
var _tex: Texture2D
var _refresh := 0.0

func setup(gw: int, gh: int, world: World3D, cell: float) -> void:
	custom_minimum_size = MAP
	size = MAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vp = SubViewport.new()
	_vp.size = VP
	_vp.world_3d = world                                  # share the main 3D world
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = gh * cell * 1.06                           # board height fills the view (4:3)
	cam.near = 1.0
	cam.far = 220.0
	cam.position = Vector3(0, 100, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)             # straight down; +X right, +Z down
	_vp.add_child(cam)
	cam.current = true

	_tex = _vp.get_texture()

# Kept for call-site compatibility — the live render replaces per-cell painting.
func update_territory(_grid, _colors: Dictionary) -> void:
	pass

func set_markers(m: Array) -> void:
	_markers = m

func _process(delta: float) -> void:
	# Re-render the board a few times a second (territory changes slowly); the dots
	# on top redraw every frame so they stay smooth.
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.3
		if _vp:
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

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
