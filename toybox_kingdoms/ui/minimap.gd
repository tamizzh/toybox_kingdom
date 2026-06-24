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
var _dirty := true        # re-render only when the board changed (capture/retint), not on a timer

func setup(gw: int, gh: int, world: World3D, cell: float, cam_env: Environment = null) -> void:
	custom_minimum_size = MAP
	size = MAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vp = SubViewport.new()
	_vp.size = VP
	_vp.world_3d = world                                  # share the main 3D world
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_DISABLED                  # MSAA on a shared-world SubViewport trips a mipmap/framebuffer bug
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = gh * cell * 1.06                           # board height fills the view (4:3)
	cam.near = 1.0
	cam.far = 220.0
	cam.position = Vector3(0, 100, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)             # straight down; +X right, +Z down
	# Own environment: the world's depth fog (ends ~64u) would otherwise render this
	# 100u-high top-down camera's whole view as solid dark fog (black map). Camera3D.environment
	# overrides the WorldEnvironment for just this viewport. We use a fog-free COPY of the real
	# board env (passed in) so the minimap matches the main view exactly — same ambient, ACES,
	# saturation and glow. Fall back to a simple lit env if none is supplied.
	if cam_env != null:
		cam.environment = cam_env
	else:
		var menv := Environment.new()
		menv.background_mode = Environment.BG_COLOR
		menv.background_color = Color("0a0d12")
		menv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		menv.ambient_light_color = Color("cfe0ee")
		menv.ambient_light_energy = 0.55
		menv.tonemap_mode = Environment.TONE_MAPPER_ACES
		cam.environment = menv
	_vp.add_child(cam)
	cam.current = true

	_tex = _vp.get_texture()

# Kept for call-site compatibility — the live render replaces per-cell painting.
func update_territory(_grid, _colors: Dictionary) -> void:
	pass

# Terrain is fixed; only ownership tinting changes. Call this when the board is
# dirty (a plate was captured/retinted) so we re-render exactly then — not on a
# blind timer. One extra render is queued for the next _process tick.
func request_render() -> void:
	_dirty = true

func set_markers(m: Array) -> void:
	_markers = m

func _process(_delta: float) -> void:
	# Re-render only when something changed; the dots on top redraw every frame.
	if _dirty:
		_dirty = false
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
