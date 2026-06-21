extends Control

# ── Readability: a whole-board minimap ───────────────────────────────────────
# The follow camera only shows your corner, so this gives the strategic view:
# the full territory grid painted into a small ImageTexture (updated on a cadence)
# plus live ruler dots drawn on top (updated every frame). Cheap: one texture
# upload per refresh, a handful of circles per frame.

const MAP := Vector2(230, 172)

var _img: Image
var _tex: ImageTexture
var _gw: int
var _gh: int
var _markers: Array = []

func setup(gw: int, gh: int) -> void:
	_gw = gw
	_gh = gh
	_img = Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.16, 0.15, 0.12, 0.85))
	_tex = ImageTexture.create_from_image(_img)
	custom_minimum_size = MAP
	size = MAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_territory(grid, colors: Dictionary) -> void:
	for y in _gh:
		var row := y * _gw
		for x in _gw:
			var oid: int = grid.owner[row + x]
			if oid == 0:
				_img.set_pixel(x, y, Color(0.16, 0.15, 0.12, 0.85))
			else:
				_img.set_pixel(x, y, colors.get(oid, Color.WHITE))
	_tex.update(_img)
	queue_redraw()

func set_markers(m: Array) -> void:
	_markers = m
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-4, -4), MAP + Vector2(8, 8)), Color(0.05, 0.07, 0.12, 0.9), true)
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
	draw_rect(Rect2(Vector2.ZERO, MAP), Color(1, 1, 1, 0.28), false, 2.0)
