extends Control

# Game-picker tile with a unique procedural icon for each of the 30 games.
# Icon area has a colored fill; white line-art on top so every game is distinct.

signal tile_pressed(index: int)

const TILE_W := 236.0
const TILE_H := 158.0
const ICON_H := 114.0   # height of coloured icon zone

var entry: Dictionary = {}
var idx: int = 0

var _hover: bool = false
var _down: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(TILE_W, TILE_H)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var cat: String = entry.get("category", "")
	var cat_color: Color = Palette.category_color(cat)

	var title_l := Label.new()
	title_l.text = entry.get("title", "???")
	title_l.add_theme_font_size_override("font_size", 13)
	title_l.add_theme_color_override("font_color", Palette.ACCENT)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.position = Vector2(2, ICON_H + 6)
	title_l.size = Vector2(TILE_W - 4, 18)
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_l)

	var cat_l := Label.new()
	cat_l.text = cat.to_upper()
	cat_l.add_theme_font_size_override("font_size", 10)
	cat_l.add_theme_color_override("font_color", cat_color)
	cat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_l.position = Vector2(2, ICON_H + 22)
	cat_l.size = Vector2(TILE_W - 4, 13)
	cat_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cat_l)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_down = event.pressed
		if not event.pressed:
			tile_pressed.emit(idx)
		queue_redraw()
	elif event is InputEventScreenTouch:
		_down = event.pressed
		if not event.pressed:
			tile_pressed.emit(idx)
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true; queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false; _down = false; queue_redraw()

func _draw() -> void:
	if entry.is_empty():
		return
	var cat: String = entry.get("category", "")
	var cat_color: Color = Palette.category_color(cat)
	var w := TILE_W

	# ── Sticker card ─────────────────────────────────────────────────────────
	DrawKit.card(self, Rect2(4, 4, w - 8, TILE_H - 8), 18.0, Palette.ARENA_FLOOR, 4.0, true)

	# ── Bright icon panel (rounded, inset) ───────────────────────────────────
	var panel := cat_color
	if _hover: panel = cat_color.lightened(0.12)
	if _down:  panel = cat_color.lightened(0.24)
	var panel_rect := Rect2(14, 14, w - 28, ICON_H - 18)
	DrawKit.rounded_rect(self, panel_rect, 13.0, panel)

	# ── Illustrated thumbnail (Firefly PNG) or procedural icon fallback ──────
	var art := AssetKit.thumb(MiniGameRegistry.slug(entry))
	if art:
		var pad := 6.0
		var ir := Rect2(panel_rect.position + Vector2(pad, pad), panel_rect.size - Vector2(pad, pad) * 2.0)
		draw_texture_rect(art, ir, false)
		if _down:
			draw_rect(ir, Color(1, 1, 1, 0.12))
	else:
		var cx := w * 0.5
		var cy := (ICON_H - 4) * 0.5
		_draw_game_icon(idx, Vector2(cx, cy), 30.0, DrawKit.OUTLINE)

# ── Per-game unique icon ───────────────────────────────────────────────────
# All icons use W (white/near-white) and D (dim white) on the colored bg.

func _draw_game_icon(game_idx: int, c: Vector2, r: float, accent: Color) -> void:
	var W := Color.WHITE
	var D := Color(1, 1, 1, 0.45)
	var A := accent          # category color for inner accent shapes

	match game_idx:
		# ── Racing ────────────────────────────────────────────────────────
		0:  # Sprint Race – running figure with motion streaks
			draw_circle(c + Vector2(0, -r * 0.55), r * 0.22, W)         # head
			draw_rect(Rect2(c.x - 5, c.y - r * 0.3, 10, r * 0.6), W)   # body
			for i in 3:                                                  # motion lines
				var y := c.y + (i - 1) * r * 0.25
				draw_line(c + Vector2(-r, y - c.y), c + Vector2(-r * 0.35, y - c.y), D, 3.0)

		1:  # Lane Switch – three lanes with an avatar mid-switch
			for i in 3:
				var ly := c.y + (i - 1) * r * 0.55
				draw_line(c + Vector2(-r, ly - c.y), c + Vector2(r, ly - c.y), D, 2.0)
			draw_circle(c + Vector2(0, -r * 0.28), r * 0.26, W)         # avatar on middle lane

		2:  # Obstacle Dash – wall with figure leaping over it
			draw_rect(Rect2(c.x + 2, c.y - r * 0.7, 8, r * 1.4), W)   # wall
			draw_circle(c + Vector2(-r * 0.5, -r * 0.55), r * 0.22, A) # figure head (mid-jump)
			draw_line(c + Vector2(-r * 0.5, -r * 0.3), c + Vector2(r * 0.2, -r * 0.6), W, 4.0) # jump arc

		3:  # Ice Slide Race – curved ice trail
			draw_arc(c, r * 0.8, PI * 0.2, PI * 0.9, 20, W, 5.0)
			draw_circle(c + Vector2(r * 0.5, -r * 0.45), r * 0.2, A)   # puck/figure

		4:  # Hill Climb – slope + tiny vehicle
			var pts := PackedVector2Array([c + Vector2(-r, r * 0.5), c + Vector2(r * 0.3, r * 0.5), c + Vector2(r * 0.3, -r * 0.5)])
			draw_polyline(pts, W, 5.0)
			draw_circle(c + Vector2(r * 0.3, -r * 0.5), r * 0.22, A)

		# ── Combat ────────────────────────────────────────────────────────
		5:  # Tank Battle – blocky tank silhouette
			draw_rect(Rect2(c.x - r * 0.8, c.y - r * 0.25, r * 1.6, r * 0.55), W)  # hull
			draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.7, r * 0.7, r * 0.45), D)   # turret
			draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, -r * 1.1), W, 5.0)   # barrel

		6:  # Sword Duel – two crossed swords
			draw_line(c + Vector2(-r * 0.85, -r * 0.85), c + Vector2(r * 0.85, r * 0.85), W, 5.0)
			draw_line(c + Vector2(r * 0.85, -r * 0.85),  c + Vector2(-r * 0.85, r * 0.85), W, 5.0)
			draw_circle(c, r * 0.14, A)

		7:  # Bomb Throw – round bomb with fuse spark
			draw_circle(c + Vector2(0, r * 0.1), r * 0.62, W)
			draw_arc(c + Vector2(0, r * 0.1), r * 0.62, PI * 1.2, PI * 1.6, 12, Color(Palette.ARENA_BG, 1.0), 6.0)  # fuse channel
			draw_line(c + Vector2(r * 0.32, -r * 0.45), c + Vector2(r * 0.55, -r * 0.95), D, 3.0)  # fuse line
			draw_circle(c + Vector2(r * 0.55, -r * 0.95), r * 0.12, A)  # spark

		8:  # Laser Survival – two crossed laser beams
			draw_line(c + Vector2(-r, -r * 0.3), c + Vector2(r, r * 0.3), A, 4.0)
			draw_line(c + Vector2(-r, r * 0.3),  c + Vector2(r, -r * 0.3), A, 4.0)
			draw_rect(Rect2(c.x - r * 0.15, c.y - r * 0.15, r * 0.3, r * 0.3), W)  # player

		9:  # Mini Shooter – bullet leaving a gun barrel
			draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.2, r * 0.55, r * 0.4), W)  # grip
			draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.38, r * 1.0, r * 0.2), W)  # barrel
			draw_circle(c + Vector2(r * 0.75, -r * 0.28), r * 0.14, A)              # bullet

		# ── Growth ────────────────────────────────────────────────────────
		10:  # Snake Battle – S-shaped snake
			var sp := [c + Vector2(-r * 0.6, -r * 0.55), c + Vector2(-r * 0.6, r * 0.0),
			           c + Vector2(r * 0.6, r * 0.0),     c + Vector2(r * 0.6, r * 0.55)]
			draw_polyline(PackedVector2Array(sp), W, 6.0)
			draw_circle(sp[0], r * 0.2, A)  # head

		11:  # Blob Growth – three growing blobs
			draw_circle(c + Vector2(-r * 0.55, r * 0.2), r * 0.22, D)
			draw_circle(c + Vector2(0, r * 0.1),          r * 0.34, D)
			draw_circle(c + Vector2(r * 0.5, -r * 0.1),  r * 0.46, W)

		12:  # Zone Shrink – nested shrinking squares
			draw_rect(Rect2(c.x - r, c.y - r, r * 2, r * 2), D, false, 3.0)
			draw_rect(Rect2(c.x - r * 0.65, c.y - r * 0.65, r * 1.3, r * 1.3), D, false, 3.0)
			draw_rect(Rect2(c.x - r * 0.32, c.y - r * 0.32, r * 0.64, r * 0.64), W, false, 3.0)
			draw_circle(c, r * 0.13, A)

		13:  # King of Arena – crown shape
			var base_y := c.y + r * 0.3
			draw_rect(Rect2(c.x - r * 0.7, base_y - r * 0.25, r * 1.4, r * 0.4), W)  # band
			draw_line(c + Vector2(-r * 0.7, base_y - r * 0.25), c + Vector2(-r * 0.45, base_y - r * 0.7), W, 4.0)
			draw_line(c + Vector2(-r * 0.45, base_y - r * 0.7), c + Vector2(0, base_y - r * 1.0), W, 4.0)
			draw_line(c + Vector2(0, base_y - r * 1.0), c + Vector2(r * 0.45, base_y - r * 0.7), W, 4.0)
			draw_line(c + Vector2(r * 0.45, base_y - r * 0.7), c + Vector2(r * 0.7, base_y - r * 0.25), W, 4.0)

		14:  # Virus Spread – spiky virus ball
			draw_circle(c, r * 0.42, W)
			for i in 6:
				var a := TAU * i / 6.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.42,
				          c + Vector2(cos(a), sin(a)) * r * 0.82, W, 3.0)
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.9, r * 0.12, D)

		# ── Sports ────────────────────────────────────────────────────────
		15:  # Mini Soccer – ball approaching a goal
			draw_rect(Rect2(c.x + r * 0.45, c.y - r * 0.65, 6, r * 1.3), W)  # post
			draw_line(c + Vector2(r * 0.45, -r * 0.65), c + Vector2(r, -r * 0.65), W, 3.0)  # crossbar
			draw_circle(c + Vector2(-r * 0.35, 0), r * 0.36, W)  # ball
			draw_arc(c + Vector2(-r * 0.35, 0), r * 0.36, 0, TAU, 6, Color(Palette.ARENA_BG, 0.5), 2.0)

		16:  # Sumo Push – two circles facing each other
			draw_circle(c + Vector2(-r * 0.42, 0), r * 0.38, W)
			draw_circle(c + Vector2(r * 0.42, 0),  r * 0.38, D)
			draw_line(c + Vector2(-r * 0.42 + r * 0.38, 0), c + Vector2(r * 0.42 - r * 0.38, 0), A, 5.0)  # push line

		17:  # Basketball Rush – hoop with backboard
			draw_rect(Rect2(c.x + r * 0.3, c.y - r, 6, r * 1.4), W)   # backboard edge
			draw_arc(c + Vector2(r * 0.1, r * 0.05), r * 0.35, PI * 0.1, PI * 1.1, 16, W, 4.0)  # hoop arc
			draw_circle(c + Vector2(-r * 0.45, -r * 0.3), r * 0.28, D)  # ball

		18:  # Tug of War – rope with two figures pulling
			draw_line(c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.8, 0), W, 5.0)
			draw_circle(c + Vector2(-r * 0.9, 0), r * 0.2, A)
			draw_circle(c + Vector2(r * 0.9, 0),  r * 0.2, D)

		19:  # Hockey Slide – puck and stick
			draw_line(c + Vector2(-r * 0.3, -r * 0.85), c + Vector2(r * 0.5, r * 0.55), W, 5.0)  # stick
			draw_rect(Rect2(c.x + r * 0.5 - r * 0.4, c.y + r * 0.55 - 5, r * 0.8, 10), W)     # blade
			draw_circle(c + Vector2(-r * 0.5, r * 0.5), r * 0.2, D)                             # puck

		# ── Reaction ──────────────────────────────────────────────────────
		20:  # Reaction Tap – hand with lightning bolt
			draw_circle(c, r * 0.55, D)
			draw_line(c + Vector2(r * 0.1, -r * 0.55), c + Vector2(-r * 0.15, r * 0.05), W, 6.0)
			draw_line(c + Vector2(-r * 0.15, r * 0.05), c + Vector2(r * 0.15, r * 0.05), W, 6.0)
			draw_line(c + Vector2(r * 0.15, r * 0.05), c + Vector2(-r * 0.1, r * 0.55), W, 6.0)

		21:  # Stop Timer – timer bar with marker
			draw_rect(Rect2(c.x - r, c.y - r * 0.2, r * 2, r * 0.4), D)
			draw_rect(Rect2(c.x - r, c.y - r * 0.2, r * 1.15, r * 0.4), W)  # filled portion
			draw_rect(Rect2(c.x + r * 0.1, c.y - r * 0.55, 5, r * 0.7), A)  # target line

		22:  # Color Match – four colored squares in a grid
			var sq := r * 0.42
			for row in 2:
				for col in 2:
					var sc: Color = Palette.PLAYER_COLORS[(row * 2 + col) % 4]
					draw_rect(Rect2(c.x + (col - 1) * sq * 1.1, c.y + (row - 1) * sq * 1.1, sq, sq), sc)

		23:  # Light Signal – traffic light tower
			draw_rect(Rect2(c.x - r * 0.3, c.y - r, r * 0.6, r * 2), W)
			draw_circle(c + Vector2(0, -r * 0.55), r * 0.22, Color("e6394a"))   # red
			draw_circle(c + Vector2(0,  0),         r * 0.22, Color("f2c12e"))   # yellow
			draw_circle(c + Vector2(0,  r * 0.55),  r * 0.22, Color("37b34a"))   # green

		24:  # Memory Sequence – numbered circles
			for i in 4:
				var a := TAU * i / 4.0
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.6, r * 0.27, D if i > 0 else W)
			draw_circle(c, r * 0.18, A)

		# ── Platform ──────────────────────────────────────────────────────
		25:  # Falling Platforms – platforms with cracks
			for i in 3:
				var py := c.y + (i - 1) * r * 0.55
				var bw := r * (0.9 - i * 0.15) * (0.7 if i == 1 else 1.0)  # middle one cracking
				draw_rect(Rect2(c.x - bw, py - 5, bw * 2, 10), W if i != 1 else D)
			draw_circle(c + Vector2(0, -r * 0.85), r * 0.2, A)   # player above

		26:  # Lava Rising – wavy lava + figure above
			for i in 5:
				var lx := c.x - r + i * r * 0.5
				var amp := r * 0.2
				draw_arc(Vector2(lx, c.y + r * 0.35), r * 0.2, PI, 0, 8, Color("e65c00", 0.9), 4.0)
			draw_circle(c + Vector2(0, -r * 0.35), r * 0.24, W)   # player head

		27:  # Jump Gap – two platforms with player mid-air
			draw_rect(Rect2(c.x - r, c.y + r * 0.2, r * 0.7, r * 0.5), W)   # left platform
			draw_rect(Rect2(c.x + r * 0.35, c.y + r * 0.2, r * 0.7, r * 0.5), W)  # right platform
			draw_circle(c + Vector2(0, -r * 0.2), r * 0.22, A)   # player in air

		28:  # Moving Block Escape – blocks with motion arrows
			draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.35, r * 0.7, r * 0.7), D)  # block
			draw_line(c + Vector2(r * 0.5, 0), c + Vector2(r * 0.95, 0), W, 4.0)    # right arrow
			draw_line(c + Vector2(r * 0.8, -r * 0.18), c + Vector2(r * 0.95, 0), W, 4.0)
			draw_line(c + Vector2(r * 0.8,  r * 0.18), c + Vector2(r * 0.95, 0), W, 4.0)
			draw_circle(c + Vector2(-r * 0.7, r * 0.7), r * 0.18, A)   # player avoiding

		29:  # Rotating Platform – disc with spin arrows
			draw_arc(c, r * 0.75, 0, TAU, 40, D, 5.0)
			draw_arc(c, r * 0.75, 0,       PI * 1.1, 20, W, 5.0)
			draw_line(c + Vector2(0, -r * 0.75), c + Vector2(r * 0.22, -r * 0.55), W, 4.0)  # arrow tip
			draw_circle(c + Vector2(r * 0.75, 0), r * 0.2, A)   # player on edge

		_:  # Fallback – category icon
			draw_circle(c, r * 0.6, W)
