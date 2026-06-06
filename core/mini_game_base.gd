class_name MiniGameBase
extends Node2D

# Abstract template for every mini-game. Subclasses override the virtual
# methods and reuse the shared helpers so each game stays tiny.

enum WinType { LAST_ALIVE, HIGH_SCORE, FAST_TIME }

signal round_finished(results)      # { player_id: points }
signal time_changed(seconds_left)
signal status_changed(text)

@export var game_title: String = "Mini Game"
@export var round_duration: float = 30.0
@export var win_condition: WinType = WinType.HIGH_SCORE

var category: String = ""
var slug: String = ""
var arena_color: Color = Palette.ARENA_BG

# Set true while a game with an illustrated arena background is active, so shared
# helpers (e.g. WallArena) skip their opaque dark floor and let the art show.
static var has_arena_art: bool = false

const PLAYER_AVATAR := preload("res://players/player_avatar.tscn")

# Design-space play area (HUD occupies the top ~150px). Spans the 1560-wide
# landscape design space, centred on Palette.CENTER_X.
var arena_rect: Rect2 = Rect2(70, 160, 1420, 500)

var players: Array = []          # Array[PlayerData]
var avatars: Dictionary = {}     # id -> PlayerController
var elapsed: float = 0.0

var _timer: RoundTimer
var _finished: bool = false
var _counting_down: bool = false

# ------------------------------------------------------------------ lifecycle
func start_game(player_list: Array) -> void:
	players = player_list
	has_arena_art = AssetKit.arena(category) != null
	for p in players:
		p.reset_round()
	_timer = RoundTimer.new()
	add_child(_timer)
	_timer.tick.connect(func(t): time_changed.emit(t))
	_timer.finished.connect(_on_time_up)
	_setup_round()
	status_changed.emit(game_title)
	_start_countdown()

func _start_countdown() -> void:
	_counting_down = true
	for av in avatars.values():
		av.auto_input = false

	var overlay := Label.new()
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(Palette.DESIGN_W, Palette.DESIGN_H)
	overlay.add_theme_font_size_override("font_size", 150)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	for n in [3, 2, 1]:
		overlay.text = str(n)
		overlay.add_theme_color_override("font_color", Palette.ACCENT)
		overlay.modulate = Color.WHITE
		var tw := create_tween()
		tw.tween_property(overlay, "modulate:a", 0.1, 0.75)
		await tw.finished

	overlay.text = "GO!"
	overlay.add_theme_color_override("font_color", Palette.SAFE)
	overlay.modulate = Color.WHITE
	var tw2 := create_tween()
	tw2.tween_property(overlay, "modulate:a", 0.0, 0.45)
	await tw2.finished
	overlay.queue_free()

	_counting_down = false
	for av in avatars.values():
		av.auto_input = true
	_timer.start(round_duration)

func _process(delta: float) -> void:
	if _finished or _counting_down:
		return
	elapsed += delta
	_game_process(delta)

# -------------------------------------------------------------- virtuals (override)
func _setup_round() -> void:
	pass

func _game_process(_delta: float) -> void:
	pass

func _compute_results() -> Dictionary:
	return {}

func _on_time_up() -> void:
	finish_round(_compute_results())

# ------------------------------------------------------------------ shared helpers
func draw_background(color: Color = Color(0, 0, 0, 0)) -> void:
	# Alpha-0 sentinel => use this game's category arena colour.
	var c := color if color.a > 0.0 else arena_color
	var bg := ColorRect.new()
	bg.color = c
	bg.position = Vector2(-260, -220)
	bg.size = Vector2(2080, 1160)
	bg.z_index = -100
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Illustrated arena background (if a Firefly PNG was added for this category).
	var art := AssetKit.arena(category)
	if art:
		_build_arena_bg(art)
		return

# Fill the whole screen with the arena art with no crop. If the art is wide
# enough (≈19.5:9) it covers edge-to-edge; if it's 16:9 it is fitted to the
# screen height (no vertical distortion) and a horizontal 9-slice stretches only
# the flat centre, keeping the decorated left/right borders crisp.
const SLICE_FRAC := 0.16   # fraction of width kept crisp on each side

static var _np_cache: Dictionary = {}

func _build_arena_bg(art: Texture2D) -> void:
	var iw := float(art.get_width())
	var ih := float(art.get_height())
	var fit_w := Palette.DESIGN_H * iw / ih   # width when scaled to screen height
	if fit_w >= Palette.DESIGN_W - 2.0:
		# Already wide enough to cover the screen without side gaps.
		_add_arena_layer(art, Vector2(-20, -20),
			Vector2(Palette.DESIGN_W + 40.0, Palette.DESIGN_H + 40.0),
			TextureRect.STRETCH_KEEP_ASPECT_COVERED, Color.WHITE, -100)
		return
	var npr := NinePatchRect.new()
	npr.texture = _height_fit_texture(art, int(round(fit_w)))
	npr.position = Vector2.ZERO
	npr.size = Vector2(Palette.DESIGN_W, Palette.DESIGN_H)
	var m := int(fit_w * SLICE_FRAC)
	npr.patch_margin_left = m
	npr.patch_margin_right = m
	npr.patch_margin_top = 0
	npr.patch_margin_bottom = 0
	npr.z_index = -100
	npr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(npr)

func _height_fit_texture(art: Texture2D, w: int) -> Texture2D:
	# Resize once per category (cached) to screen height, so the 9-slice corners
	# render at the right scale and there's no per-round resize hitch.
	if _np_cache.has(category):
		return _np_cache[category]
	var img := art.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(w, int(Palette.DESIGN_H), Image.INTERPOLATE_LANCZOS)
	var t := ImageTexture.create_from_image(img)
	_np_cache[category] = t
	return t

func _add_arena_layer(tex: Texture2D, pos: Vector2, sz: Vector2, stretch: int, tint: Color, z: int) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = pos
	tr.size = sz
	tr.modulate = tint
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = stretch
	tr.z_index = z
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	# Soft vignette: a darker band top & bottom for depth.
	for band in [Vector2(-200, -200), Vector2(-200, 720)]:
		var v := ColorRect.new()
		v.color = Color(0, 0, 0, 0.10)
		v.position = band
		v.size = Vector2(1680, 200)
		v.z_index = -99
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)

func make_rect(r: Rect2, color: Color, z: int = -10) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = color
	cr.position = r.position
	cr.size = r.size
	cr.z_index = z
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)
	return cr

func make_label(text: String, pos: Vector2, font_size: int = 28, color: Color = Palette.ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func spawn_avatars(spawn_points: Array) -> void:
	var body := AssetKit.sprite(slug)   # optional Firefly character body
	for i in players.size():
		var p: PlayerData = players[i]
		var av := PLAYER_AVATAR.instantiate()
		add_child(av)
		av.setup(p)
		if body and av.figure:
			av.figure.set_body_texture(body)
		av.position = spawn_points[i % spawn_points.size()]
		avatars[p.id] = av

func get_avatar(id: int) -> Node:
	return avatars.get(id, null)

func corner_spawns(rect: Rect2, margin: float = 80.0) -> Array:
	return [
		rect.position + Vector2(margin, margin),
		rect.position + rect.size - Vector2(margin, margin),
		rect.position + Vector2(rect.size.x - margin, margin),
		rect.position + Vector2(margin, rect.size.y - margin),
	]

func lane_spawns(rect: Rect2, at_x: float) -> Array:
	var pts := []
	var n := players.size()
	for i in n:
		var y := rect.position.y + rect.size.y * (i + 1.0) / (n + 1.0)
		pts.append(Vector2(at_x, y))
	return pts

func clamp_avatar(av: Node, pad: float = 26.0) -> void:
	av.position.x = clamp(av.position.x, arena_rect.position.x + pad, arena_rect.position.x + arena_rect.size.x - pad)
	av.position.y = clamp(av.position.y, arena_rect.position.y + pad, arena_rect.position.y + arena_rect.size.y - pad)

# -------------------------------------------------------------- elimination / scoring
func eliminate(id: int) -> void:
	var p := _player(id)
	if p and p.alive:
		p.alive = false
		if avatars.has(id):
			avatars[id].set_dead()
		check_last_alive()

func survivors() -> Array:
	var s := []
	for p in players:
		if p.alive:
			s.append(p)
	return s

func check_last_alive() -> void:
	if win_condition != WinType.LAST_ALIVE:
		return
	# Solo: the round ends only when the lone player is eliminated; otherwise they
	# must survive until the timer. Multiplayer: ends when one survivor remains.
	var threshold := 0 if players.size() <= 1 else 1
	if survivors().size() <= threshold:
		finish_round(_compute_results())

func award_by_rank(order: Array) -> Dictionary:
	# order: player ids best-first. 1st gets n-1, last gets 0.
	var results := {}
	var n := order.size()
	if n == 1:
		# Solo: completing/finishing the round earns one point toward the target.
		results[order[0]] = 1
		return results
	for i in n:
		results[order[i]] = maxi(0, n - 1 - i)
	return results

func rank_by_value(values: Dictionary, higher_better: bool = true) -> Dictionary:
	var ids := values.keys()
	ids.sort_custom(func(a, b):
		return values[a] > values[b] if higher_better else values[a] < values[b])
	return award_by_rank(ids)

func survivor_results(points: int = 3) -> Dictionary:
	var results := {}
	for p in players:
		results[p.id] = points if p.alive else 0
	return results

func time_left() -> float:
	return _timer.time_left if _timer else 0.0

func finish_round(results: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	if _timer:
		_timer.stop()
	for p in players:
		if not results.has(p.id):
			results[p.id] = 0
	round_finished.emit(results)

func _player(id: int) -> PlayerData:
	for p in players:
		if p.id == id:
			return p
	return null
