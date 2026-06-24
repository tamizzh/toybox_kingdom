extends Node3D

# ── DAY 11-15: AI rivals ─────────────────────────────────────────────────────
# N kingdoms (1 human + AI) on one shared territory grid. Every ruler — human or
# AI — uses the SAME enter_cell seam, enclosure capture, trail-cut death and
# respawn. Humans drive their avatar via InputManager (WASD/touch); AI avatars are
# driven directly from a KingdomAI brain so we aren't limited by InputManager's
# 4-slot cap. Adds a live territory leaderboard and territory-scaled camera zoom.
#
# Run (desktop, WASD): godot --path "<project>" res://toybox_kingdoms/kingdom_match.tscn

const Grid := preload("res://toybox_kingdoms/grid/territory_grid.gd")
const GridRenderer := preload("res://toybox_kingdoms/grid/grid_renderer.gd")
const KingdomCamera := preload("res://toybox_kingdoms/camera/kingdom_camera.gd")
const Avatar := preload("res://players/avatar3d.gd")
const PlayerDataS := preload("res://core/player_data.gd")
const TouchControls := preload("res://ui/touch_controls.gd")
const RulerAgent := preload("res://toybox_kingdoms/kingdom/ruler_agent.gd")
const KingdomAI := preload("res://toybox_kingdoms/ai/kingdom_ai.gd")
const Castle := preload("res://toybox_kingdoms/kingdom/castle.gd")
const Populace := preload("res://toybox_kingdoms/kingdom/populace.gd")
const Roster := preload("res://toybox_kingdoms/data/roster.gd")
const Minimap := preload("res://toybox_kingdoms/ui/minimap.gd")
const GlyphIcon := preload("res://toybox_kingdoms/ui/glyph_icon.gd")
const Scatter := preload("res://toybox_kingdoms/env/scatter.gd")
const GrassTexture := preload("res://toybox_kingdoms/env/grass_texture.gd")
const TerritoryGround := preload("res://toybox_kingdoms/grid/territory_ground.gd")

const GW := 128
const GH := 96
const CELL := 0.6
const HOME_R := 5
const N_KINGDOMS := 8           # 1 human + 7 AI
const HUMAN_INPUT_ID := 0
const HUMAN_SPEED := 7.0
const AI_SPEED := 6.3
const RESPAWN_TIME := 1.2
const BLOB_SCALE := 0.62         # every ruler blob is this size (incl. after respawn)
const MATCH_DURATION := 150.0   # seconds
const WIN_PCT := 0.40           # rule 40% of the toybox = instant domination win

var grid
var renderer
var camera
var _player                     # human PlayerData

var _rulers: Array = []         # Array[RulerAgent]
var _kid_to_agent := {}
var _kids: Array = []
var _kid_color := {}
var _kid_name := {}
var _minimap

var _populace
var _scatter
var _ground
var _world_env: Environment      # the live board env; the minimap reuses a fog-free copy
var _kingdom_t := 0.0
var _terr_rebuild_t := 0.0

var _ended := false
var _match_t := MATCH_DURATION
var _ui_layer: CanvasLayer

var _terr_label: Label
var _time_label: Label
var _pop_label: Label
var _pop_pill_label: Label
var _income_label: Label
var _lb_rows: Array = []        # Array[Label]
var _hud_t := 0.0

# ── in-match economy (the human's kingdom) ───────────────────────────────────
var _coins := 60
var _income := 12.0             # coins per minute (recomputed from land + farms)
var _coin_accum := 0.0
var _farms := 0
var _towers := 0
var _barracks := 0
var _castle_floor := 1          # min castle level bought via the CASTLE button
var _coins_label: Label
var _build_btns := {}           # kind -> Button

var _dbg := false
var _dbg_t := 0.0

func _ready() -> void:
	_dbg = OS.get_environment("TBK_DEBUG") == "1"
	var fast := OS.get_environment("TBK_FASTMATCH")
	if fast != "":
		_match_t = float(fast)
	AudioManager.play_music("game")
	_build_environment()
	_build_ground()

	grid = Grid.new()
	grid.setup(GW, GH)

	# colors first so the renderer can draw every kingdom
	for i in N_KINGDOMS:
		var kid := i + 1
		_kids.append(kid)
		_kid_color[kid] = _kingdom_color(i, N_KINGDOMS)

	renderer = GridRenderer.new()
	add_child(renderer)
	renderer.setup(grid, CELL, _kid_color)   # trails + flash only now (cube fill removed)

	# spawn kingdoms
	for i in N_KINGDOMS:
		_spawn_kingdom(i)

	# NEW painted-ground territory (replaces the territory cubes)
	_ground = TerritoryGround.new()
	add_child(_ground)
	_ground.setup(grid, CELL, _kid_color)
	_ground.update()
	renderer.rebuild_borders()   # raised kingdom-coloured walls ring each territory

	# the town layer: houses + citizens rising from claimed land
	_populace = Populace.new()
	add_child(_populace)
	var homes := {}
	for a in _rulers:
		homes[a.kid] = a.home
	_populace.setup(grid, CELL, _kid_color, homes)
	_populace.rebuild()

	# lush wilderness: trees / rocks / bushes on neutral land
	_scatter = Scatter.new()
	add_child(_scatter)
	_scatter.setup(grid, CELL)
	_scatter.rebuild()

	# camera follows the human
	camera = KingdomCamera.new()
	camera.offset = Vector3(0.0, 15.5, 14.0)   # pulled-back toy-board view
	add_child(camera)
	camera.target = _rulers[0].avatar

	# input + HUD
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var tc := TouchControls.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(tc)
	tc.setup([_player])
	_build_hud(_ui_layer)

func _spawn_kingdom(i: int) -> void:
	var kid: int = i + 1
	var info: Dictionary = Roster.info(i)
	_kid_name[kid] = info["name"]
	var home := _home_anchor(i, N_KINGDOMS)
	grid.seed_kingdom(kid, home.x, home.y, HOME_R)

	var a := RulerAgent.new()
	a.kid = kid
	a.home = home
	a.last_cell = home
	a.is_ai = (i != 0)

	var pdata = PlayerDataS.new(i)
	pdata.color = _kid_color[kid]
	pdata.is_ai = a.is_ai
	var av = Avatar.new()
	add_child(av)
	av.setup(pdata)
	av.set_body_scale(BLOB_SCALE)            # smaller toy blob (reads better up close)
	# spawn to the RIGHT of the castle so the blob is visible, not hidden inside the
	# keep. Still on home soil (within HOME_R) so no trail starts.
	var spawn_cell := Vector2i(mini(home.x + 4, GW - 1), home.y)
	av.global_position = _c2w(spawn_cell.x, spawn_cell.y, 0.0)
	a.last_cell = spawn_cell
	# No walls in this world; let rulers pass through each other so AI never sticks.
	av.collision_layer = 0
	av.collision_mask = 0
	a.avatar = av

	if a.is_ai:
		av.auto_input = false
		a.ai = KingdomAI.new()
		a.ai.setup(int(info["diff"]), 1000 + i * 7)   # personality drives behaviour
	else:
		_player = pdata
		av.auto_input = true                # human reads InputManager id 0

	# castle at home, starts as a lone keep and grows with the realm
	var castle = Castle.new()
	add_child(castle)
	castle.position = _c2w(home.x, home.y, 0.0)
	castle.set_color(_kid_color[kid])
	castle.update_tier(_castle_tier(grid.territory_count(kid)))
	a.castle = castle
	a.castles = [{"cell": home, "node": castle}]

	# floating name tag so you can tell who's who on the board
	var tag := Label3D.new()
	tag.text = info["name"]
	tag.modulate = _kid_color[kid]
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.outline_size = 10
	tag.font_size = 56
	tag.pixel_size = 0.011
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = _c2w(home.x, home.y, 0.0) + Vector3(0, 4.4, 0)
	add_child(tag)
	a.name_tag = tag

	_rulers.append(a)
	_kid_to_agent[kid] = a

func _castle_tier(n: int) -> int:
	# Higher thresholds so the castle levels gradually over a match, not instantly.
	if n < 300:
		return 1
	elif n < 800:
		return 2
	elif n < 1800:
		return 3
	return 4

# Half-width (disc radius, in cells) of a castle's footprint at a given tier. The GLB
# spans ±1.63 model units (corner-tower outer edge) and is drawn at scale 0.86+tier*0.12
# (see castle.gd), so this is the real ground the castle covers. A conqueror must own
# every cell in this disc before the castle falls — the bigger it has grown, the more
# territory they must engulf. ceil() so the whole model is always enclosed.
const CASTLE_HALF_SPAN := 1.63
func _castle_radius(tier: int) -> int:
	var scale := 0.86 + float(tier) * 0.12
	return int(ceil(CASTLE_HALF_SPAN * scale / CELL))

func _physics_process(delta: float) -> void:
	if _ended:
		return
	_match_t = maxf(0.0, _match_t - delta)

	# 1. drive AI movement (humans move themselves in Avatar3D._physics_process)
	for a in _rulers:
		if a.is_ai and a.alive:
			var dir: Vector2 = a.ai.decide(a, self)
			a.avatar.velocity = Vector3(dir.x, 0.0, dir.y) * AI_SPEED
			a.avatar.move_and_slide()
			if dir.length() > 0.1:
				a.avatar.face(dir)

	# 2. grid stepping + respawn for every ruler
	for a in _rulers:
		if a.eliminated:
			continue
		if not a.alive:
			a.respawn_t -= delta
			if a.respawn_t <= 0.0:
				_respawn(a)
			continue
		_clamp(a.avatar)
		var c := _w2c(a.avatar.global_position)
		if c != a.last_cell:
			_advance_agent(a, c)

	# 3. render + ui
	renderer.update_trails(_kids)
	# Throttle full territory rebuilds to <=10/s — mobile safeguard (claims still
	# show instantly via the flash; the slab catches up within 0.1s).
	_terr_rebuild_t -= delta
	if grid.has_dirty() and _terr_rebuild_t <= 0.0:
		_ground.update()
		renderer.rebuild_borders()
		grid.reset_dirty()
		_terr_rebuild_t = 0.1
	_kingdom_tick(delta)
	_hud_tick(delta)
	if _dbg:
		_dbg_tick(delta)

# Grow towns + upgrade castles on a cadence (not every frame).
func _kingdom_tick(delta: float) -> void:
	_kingdom_t -= delta
	if _kingdom_t > 0.0:
		return
	_kingdom_t = 0.4
	_populace.rebuild()
	_minimap.update_territory(grid, _kid_color)
	for a in _rulers:
		if a.eliminated:
			continue
		var new_tier := _castle_tier(grid.territory_count(a.kid))
		var leveled := false
		for c in a.castles:
			if c["node"] != null and c["node"].tier != new_tier:
				c["node"].update_tier(new_tier)
				leveled = true
		if leveled and not a.is_ai:
			AudioManager.play("round_win")   # your kingdom leveled up
			camera.shake(0.14)
			_ring(_c2w(a.home.x, a.home.y, 0.0), _kid_color[a.kid])

	_check_conquests()
	_check_match_end()

# A castle is captured when a RIVAL owns its cell AND their castle is at least the
# same level. The conqueror KEEPS the castle (now owns both); the loser only falls
# when ALL their castles are taken — then their remaining land goes to the last
# conqueror. A weaker attacker can't take it: the castle holds + reclaims its core.
func _check_conquests() -> void:
	for b in _rulers:
		if b.eliminated:
			continue
		var lost: Array = []
		var last_conq = null
		for c in b.castles:
			var cell: Vector2i = c["cell"]
			var ho: int = grid.get_owner(cell.x, cell.y)
			if ho == b.kid or ho == 0:
				continue
			var conq = _kid_to_agent.get(ho)
			if conq == null:
				continue
			var ctier: int = (c["node"].tier if c["node"] != null else 1)
			# The castle holds until the conqueror has covered its WHOLE footprint — and
			# the footprint grows with tier, so a castle that has grown larger must be
			# engulfed over more ground before it can be taken (owning the centre alone is
			# no longer enough). The centre is part of this disc, so `ho` is necessarily
			# the sole owner of the whole footprint when this passes.
			if not grid.region_fully_owned(cell.x, cell.y, _castle_radius(ctier), ho):
				continue
			var def_tier: int = ctier + b.defense
			var conq_tier: int = (conq.castle.tier if conq.castle != null else 1) + conq.defense
			if conq_tier >= def_tier:
				_capture_castle(c, b, conq)      # conqueror gains this castle + its region
				lost.append(c)
				last_conq = conq
			else:
				grid.seed_kingdom(b.kid, cell.x, cell.y, HOME_R)   # holds, reclaims core
				if b == _rulers[0] or conq == _rulers[0]:
					_toast("%s's castle held!" % _kid_name[b.kid], _kid_color[b.kid])
		for c in lost:
			b.castles.erase(c)
		if not b.castles.is_empty():
			# primary castle/home follows the first surviving castle
			b.castle = b.castles[0]["node"]
			b.home = b.castles[0]["cell"]
			if b.name_tag:
				b.name_tag.position = _c2w(b.home.x, b.home.y, 0.0) + Vector3(0, 4.4, 0)
		elif last_conq != null:
			_eliminate(b, last_conq)

# Hand castle `c` to `conq`: take only the land NEAREST to this castle (the slice
# between it and `b`'s other castles), retint it, add it to the conqueror's set.
func _capture_castle(c: Dictionary, b, conq) -> void:
	var others: Array = []
	for oc in b.castles:
		if oc != c:
			others.append(oc["cell"])
	grid.transfer_nearest(b.kid, conq.kid, c["cell"], others)
	var wpos := _c2w(c["cell"].x, c["cell"].y, 0.0)
	if c["node"] != null:
		c["node"].set_color(_kid_color[conq.kid])
		c["node"]._pop()                       # castle bounces as it changes hands
	_ring(wpos, _kid_color[conq.kid])
	conq.castles.append(c)
	if conq == _rulers[0]:
		_toast("You captured a castle!", _kid_color[conq.kid])
		AudioManager.play("win")
		camera.shake(0.24)
	elif b == _rulers[0]:
		AudioManager.play("eliminate", 0.8)
		camera.shake(0.28)

# Expanding shockwave ring on the ground (capture / level-up VFX).
func _ring(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.1
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.5, 0)
	add_child(mi)
	var tw := mi.create_tween()
	tw.parallel().tween_property(mi, "scale", Vector3(9, 1, 9), 0.5)
	tw.parallel().tween_property(m, "albedo_color", Color(color, 0.0), 0.5)
	tw.tween_callback(mi.queue_free)

# A ruler with no castles left is out; their scattered land goes to the conqueror.
func _eliminate(b, conq) -> void:
	b.eliminated = true
	b.alive = false
	grid.clear_trail(b.kid)
	grid.transfer_all(b.kid, conq.kid)
	if b.avatar:
		b.avatar.visible = false
	if b.name_tag:
		b.name_tag.visible = false
	_toast("%s conquered %s!" % [_kid_name[conq.kid], _kid_name[b.kid]], _kid_color[conq.kid])

func _check_match_end() -> void:
	var human = _rulers[0]
	var human_pct: float = float(grid.territory_count(human.kid)) / float(GW * GH)
	var alive := 0
	for a in _rulers:
		if not a.eliminated:
			alive += 1
	if human.eliminated:
		_end_match(false, "conquered")
	elif human_pct >= WIN_PCT:
		_end_match(true, "domination")
	elif alive == 1:
		_end_match(true, "conquest")
	elif _match_t <= 0.0:
		_end_match(_human_rank() == 1, "timeout")

func _human_rank() -> int:
	var mine: int = grid.territory_count(_rulers[0].kid)
	var rank := 1
	for a in _rulers:
		if a == _rulers[0]:
			continue
		if grid.territory_count(a.kid) > mine:
			rank += 1
	return rank

# ── match end + results ───────────────────────────────────────────────────────
func _end_match(win: bool, reason: String) -> void:
	if _ended:
		return
	_ended = true
	if _rulers[0].avatar:
		_rulers[0].avatar.auto_input = false   # freeze the human (AI halts via the early return)
	var pct: float = float(grid.territory_count(_rulers[0].kid)) / float(GW * GH)
	var rank := _human_rank()
	var coins: int = int(pct * 300.0) + maxi(0, N_KINGDOMS - rank) * 15 + (60 if win else 0)
	SaveManager.add_coins(coins)
	AudioManager.play("round_win" if win else "eliminate")
	if _dbg:
		print("[end] win=%s reason=%s rank=%d pct=%.1f coins=%d" % [win, reason, rank, pct * 100.0, coins])
	_show_results(win, reason, rank, pct, coins)

func _show_results(win: bool, reason: String, rank: int, pct: float, coins: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.09, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.62, 0.3)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(center)

	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("23203f")
	st.border_color = Color(Palette.WARN if win else Palette.DANGER, 0.9)
	st.set_border_width_all(4)
	st.set_corner_radius_all(24)
	st.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	_result_label(vb, "VICTORY!" if win else "DEFEATED", 64,
		Palette.WARN if win else Palette.DANGER)
	var sub := ""
	match reason:
		"domination": sub = "You ruled %.0f%% of the toybox!" % (pct * 100.0)
		"conquest": sub = "You conquered every rival kingdom!"
		"conquered": sub = "Your kingdom was wiped off the map."
		_: sub = "You finished #%d of %d." % [rank, N_KINGDOMS]
	_result_label(vb, sub, 26, Color.WHITE)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vb.add_child(spacer)

	# final standings
	var standings: Array = []
	for kid in _kids:
		standings.append({"kid": kid, "n": grid.territory_count(kid)})
	standings.sort_custom(func(x, y): return x["n"] > y["n"])
	var total := float(GW * GH)
	for r in standings.size():
		var e: Dictionary = standings[r]
		_result_label(vb, "%d.   %s   %.1f%%" % [r + 1, _kid_name[e["kid"]], 100.0 * e["n"] / total], 24,
			_kid_color[e["kid"]])

	var coin_lbl := _result_label(vb, "+%d coins   (total %d)" % [coins, SaveManager.coins()],
		28, Palette.WARN)
	coin_lbl.add_theme_constant_override("line_spacing", 12)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	vb.add_child(btns)

	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.add_theme_font_size_override("font_size", 30)
	again.custom_minimum_size = Vector2(240, 64)
	again.pressed.connect(func() -> void:
		AudioManager.play("tap")
		get_tree().reload_current_scene())
	btns.add_child(again)

	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.add_theme_font_size_override("font_size", 30)
	menu.custom_minimum_size = Vector2(240, 64)
	menu.pressed.connect(func() -> void:
		AudioManager.play("tap")
		get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	btns.add_child(menu)

# Brief floating announcement (pops, conquests) that rises and fades.
func _toast(text: String, color: Color = Color.WHITE) -> void:
	if _ui_layer == null:
		return
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(Palette.DESIGN_W, 46)
	l.position = Vector2(0, 156)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	_ui_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(l, "position:y", 132.0, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(l, "position:y", 100.0, 0.5)
	tw.tween_callback(l.queue_free)

func _result_label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

# Walk every cell the avatar crossed this frame, 4-connected (no flood leaks).
func _advance_agent(a, target_cell: Vector2i) -> void:
	var guard := 0
	while a.last_cell != target_cell and guard < 512:
		guard += 1
		var dx: int = target_cell.x - a.last_cell.x
		var dy: int = target_cell.y - a.last_cell.y
		var step: Vector2i = a.last_cell
		if absi(dx) >= absi(dy):
			step.x += signi(dx)
		else:
			step.y += signi(dy)
		a.last_cell = step
		var res: Dictionary = grid.enter_cell(a.kid, step.x, step.y)
		var killed: int = int(res.get("killed", 0))
		if killed != 0 and _kid_to_agent.has(killed):
			var victim = _kid_to_agent[killed]
			if victim.alive:
				_kill(victim)
				if a == _rulers[0]:
					_toast("You popped %s!" % _kid_name[killed], Palette.SAFE)
					AudioManager.play("hit", 1.15)
					camera.shake(0.18)
				elif victim == _rulers[0]:
					_toast("%s popped you!" % _kid_name[a.kid], Palette.DANGER)
					AudioManager.play("hit", 0.8)
					camera.shake(0.32)
		if res.get("died", false):
			_kill(a)
			if a == _rulers[0]:
				camera.shake(0.32)
			return
		if int(res.get("captured", 0)) > 0:
			var cap := int(res.get("captured", 0))
			renderer.flash_cells(res.get("cmin", Vector2i(0, 0)), res.get("cmax", Vector2i(-1, 0)),
				_kid_color[a.kid])
			if not a.is_ai:
				AudioManager.play("collect", clampf(1.0 + float(cap) / 1500.0, 1.0, 1.45))
				if cap > 350:
					camera.shake(0.12)

func _kill(a) -> void:
	a.alive = false
	a.respawn_t = RESPAWN_TIME
	if a.avatar:
		a.avatar.set_dead()

func _respawn(a) -> void:
	# No castles left -> elimination is handled in _check_conquests.
	if a.castles.is_empty():
		return
	# respawn from the castle nearest to where the ruler fell
	var pos: Vector3 = a.avatar.global_position
	var spawn: Vector2i = a.castles[0]["cell"]
	var best_d := INF
	for c in a.castles:
		var w := _c2w(c["cell"].x, c["cell"].y, 0.0)
		var d := pos.distance_to(w)
		if d < best_d:
			best_d = d
			spawn = c["cell"]
	a.avatar.revive(_c2w(spawn.x, spawn.y, 0.0))
	a.avatar.set_body_scale(BLOB_SCALE)      # revive() resets visual scale — re-apply so all blobs match
	a.avatar.collision_layer = 0
	a.avatar.collision_mask = 0
	a.last_cell = spawn
	a.alive = true
	if a.ai:
		a.ai.reset()

# nearest living rival's world distance (used by the AI danger sense)
func nearest_enemy_dist(agent) -> float:
	var best := INF
	var pos: Vector3 = agent.avatar.global_position
	for o in _rulers:
		if o == agent or not o.alive:
			continue
		var d: float = pos.distance_to(o.avatar.global_position)
		if d < best:
			best = d
	return best

func _clamp(av) -> void:
	var hx := GW * CELL * 0.5 - CELL
	var hz := GH * CELL * 0.5 - CELL
	av.global_position.x = clampf(av.global_position.x, -hx, hx)
	av.global_position.z = clampf(av.global_position.z, -hz, hz)

# Clamp a world point a little inside the playable area (used by the AI planner).
func world_clamp(v: Vector3) -> Vector3:
	var hx := GW * CELL * 0.5 - CELL * 1.5
	var hz := GH * CELL * 0.5 - CELL * 1.5
	return Vector3(clampf(v.x, -hx, hx), v.y, clampf(v.z, -hz, hz))

# ── coordinate mapping (must match GridRenderer._c2w) ─────────────────────────
func _c2w(cx: int, cy: int, y: float) -> Vector3:
	return Vector3((cx + 0.5 - GW * 0.5) * CELL, y, (cy + 0.5 - GH * 0.5) * CELL)

func _w2c(p: Vector3) -> Vector2i:
	var cx := int(floor(p.x / CELL + GW * 0.5))
	var cy := int(floor(p.z / CELL + GH * 0.5))
	return Vector2i(clampi(cx, 0, GW - 1), clampi(cy, 0, GH - 1))

func _home_anchor(i: int, n: int) -> Vector2i:
	var cols := 4
	var rows := int(ceil(n / float(cols)))
	var col := i % cols
	var row := i / cols
	var x := int(lerpf(16.0, GW - 16.0, col / float(maxi(cols - 1, 1))))
	var y := int(lerpf(16.0, GH - 16.0, row / float(maxi(rows - 1, 1))))
	return Vector2i(x, y)

# The 8 kingdom colours, sampled from the atlas's coloured ground tiles so the
# painted territory matches the art exactly.
# Hues tuned to target_art.png: true distinct primaries (red is RED not orange,
# green is emerald not olive) so the eight kingdoms read as cleanly as the target.
const KINGDOM_COLORS := [
	Color("1a3fb0"), Color("d22323"), Color("33a23a"), Color("ecae12"),
	Color("8a3fc0"), Color("23a6ad"), Color("e87b14"), Color("e2479a"),
]
const KINGDOM_LABELS := [
	"Blue Kingdom", "Red Empire", "Green Dynasty", "Yellow Nation",
	"Purple Realm", "Cyan Kingdom", "Orange Order", "Pink Kingdom",
]

func _kingdom_color(i: int, n: int) -> Color:
	return KINGDOM_COLORS[i % KINGDOM_COLORS.size()]

# ── world dressing ────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0e1512")   # dark frame → saturated plates pop (target look)

	# Distance fog fades the grass continent + forest border into the dark frame,
	# giving the soft misty vignette of the target instead of a hard board edge.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("0e1512")    # fade toward the bg colour
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_depth_begin = 26.0               # play area stays crisp; wilderness recedes
	env.fog_depth_end = 64.0
	env.fog_depth_curve = 1.5
	env.fog_density = 1.0
	env.fog_sky_affect = 1.0

	# Cool sky-ambient fill — kept LOW so shadows stay deep and colours stay rich.
	# (High ambient floods the shadows → SSAO/directional shadow vanish + pastel wash.)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe0ee")
	env.ambient_light_energy = 0.30

	# Filmic highlight rolloff. ACES keeps the punchy toy-colour saturation while
	# rolling off highlights (AgX looked great but desaturated the candy palette).
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0

	# Subtle bloom on bright clay + emissive trails/rings/capture flashes.
	# Glow is supported on Mobile too, so it survives the mobile fallback.
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.05            # only the brightest pixels bloom
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 1.0)
	env.set_glow_level(5, 0.6)

	# Contact AO in cell seams + around castles/props = sculpted toybox depth.
	# Forward+ only; silently ignored under the mobile render fallback.
	env.ssao_enabled = true
	env.ssao_intensity = 2.4
	env.ssao_radius = 0.6                    # tight — matches the 0.6 CELL size
	env.ssao_power = 2.0
	env.ssao_detail = 0.6

	# Gentle grade — materials + glow carry the vibrancy now, so the acid is gone.
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.38         # deep, rich toy-plate colours (target look)
	_world_env = env                         # minimap mirrors this (fog-free) so it matches the board
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# warm key sun — crisp but soft-edged shadows sell the clay relief
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -125, 0)
	key.light_color = Color("ffeccd")        # ~5400K warm sunlight (less amber wash)
	key.light_energy = 1.1                   # was 1.4 → high energy blew colours to pastel
	key.shadow_enabled = true
	key.shadow_opacity = 0.6
	key.shadow_blur = 1.0                     # was 3.2 → far too mushy
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.5             # kills peter-panning on the plateau
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key.directional_shadow_max_distance = 90.0
	add_child(key)
	# cool sky fill — no shadow, just lifts the shadow side toward blue
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 60, 0)
	fill.light_color = Color("bcd4ff")
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)

func _build_ground() -> void:
	var wx := GW * CELL
	var wz := GH * CELL

	# The play board sits on a large GRASS continent that runs well past the grid
	# and fades into mist (Environment fog) at the edges — no water, no void.
	# One big matte plane; the forest border (scatter.gd) + fog do the framing.
	var apron := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(wx + 300.0, wz + 300.0)
	apron.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.26, 0.42, 0.17)   # deep wilderness green (recedes so plates pop)
	gm.roughness = 0.98
	gm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	apron.material_override = gm
	apron.position = Vector3(0, 0.02, 0)         # just under the clay board so its edge tucks in
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(apron)

func _box_part(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	mi.material_override = m
	mi.position = pos
	add_child(mi)

# ── HUD: territory readout + live leaderboard ─────────────────────────────────
func _build_hud(ui: CanvasLayer) -> void:
	_lb_rows.clear()

	var stat := _hud_panel(Vector2(16, 16), Vector2(270, 172), 16)
	ui.add_child(stat)
	var stat_v := VBoxContainer.new()
	stat_v.add_theme_constant_override("separation", 4)
	stat.add_child(stat_v)
	stat_v.add_child(_hud_text(_display_kingdom_name(_rulers[0].kid).to_upper(), 20, Color.WHITE))
	_terr_label = _hud_text("0.0%", 44, _kid_color[_rulers[0].kid].lightened(0.25),
		HORIZONTAL_ALIGNMENT_LEFT, true)
	stat_v.add_child(_terr_label)
	stat_v.add_child(_thin_rule())
	_pop_label = _hud_text("Population        0", 22, Color.WHITE)
	stat_v.add_child(_pop_label)
	_income_label = _hud_text("Coins / min       0", 22, Color.WHITE)
	stat_v.add_child(_income_label)

	var timer := _hud_panel(Vector2(Palette.CENTER_X - 96, 14), Vector2(192, 62), 18)
	ui.add_child(timer)
	_time_label = _hud_text("0:00", 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	timer.add_child(_time_label)

	var coins := _hud_panel(Vector2(Palette.DESIGN_W - 430, 16), Vector2(190, 56), 14)
	ui.add_child(coins)
	_coins_label = _hud_text("COINS  0", 25, Color("ffd34d"), HORIZONTAL_ALIGNMENT_CENTER, true)
	coins.add_child(_coins_label)

	var pop := _hud_panel(Vector2(Palette.DESIGN_W - 226, 16), Vector2(150, 56), 14)
	ui.add_child(pop)
	_pop_pill_label = _hud_text("POP  0", 25, Color("62a8ff"), HORIZONTAL_ALIGNMENT_CENTER, true)
	pop.add_child(_pop_pill_label)

	var gear := Button.new()
	gear.text = "SET"
	gear.position = Vector2(Palette.DESIGN_W - 64, 16)
	gear.size = Vector2(48, 56)
	gear.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(gear, Color("17191f"), 14)
	ui.add_child(gear)

	var lb := _hud_panel(Vector2(Palette.DESIGN_W - 292, 88), Vector2(276, 336), 12)
	ui.add_child(lb)
	var lb_v := VBoxContainer.new()
	lb_v.add_theme_constant_override("separation", 6)
	lb.add_child(lb_v)
	lb_v.add_child(_hud_text("LEADERBOARD", 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	for i in N_KINGDOMS:
		var rr := _make_lb_row()
		lb_v.add_child(rr["row"])
		_lb_rows.append(rr)

	_build_action_stack(ui)
	_build_toolbar(ui)

	# fog-free copy of the board environment → minimap matches the main view exactly
	# (the world's depth fog would otherwise black out its 100u-high top-down camera).
	var mm_env := _world_env.duplicate(true) as Environment
	mm_env.fog_enabled = false
	_minimap = Minimap.new()
	_minimap.setup(GW, GH, get_world_3d(), CELL, mm_env)   # live top-down render of the board
	_minimap.position = Vector2(Palette.DESIGN_W - 286, Palette.DESIGN_H - 202)
	ui.add_child(_minimap)

func _hud_panel(pos: Vector2, min_size: Vector2, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	st.border_color = Color(1, 1, 1, 0.10)
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(14)
	# soft drop shadow lifts the panel off the busy 3D scene (the polish tell)
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 8
	st.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", st)
	return p

# One leaderboard row: rank · colour chip · kingdom name · right-aligned %.
# Returns the parts so _hud_tick can repaint them each refresh.
func _make_lb_row() -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(248, 30)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rank := _hud_text("", 19, Color(1, 1, 1, 0.55))
	rank.custom_minimum_size = Vector2(20, 0)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dst := StyleBoxFlat.new()
	dst.bg_color = Color.GRAY
	dst.set_corner_radius_all(7)
	dst.border_color = Color(0, 0, 0, 0.45)
	dst.set_border_width_all(1)
	dot.add_theme_stylebox_override("panel", dst)
	var nm := _hud_text("", 19, Color.WHITE)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pct := _hud_text("", 19, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(54, 0)
	row.add_child(rank)
	row.add_child(dot)
	row.add_child(nm)
	row.add_child(pct)
	return {"row": row, "rank": rank, "chip": dst, "name": nm, "pct": pct}

func _hud_text(text: String, size: int, color: Color,
		align = HORIZONTAL_ALIGNMENT_LEFT, heavy := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heavy and ArcadeTheme.font_heavy:
		l.add_theme_font_override("font", ArcadeTheme.font_heavy)
	return l

func _thin_rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.15)
	r.custom_minimum_size = Vector2(1, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _build_action_stack(ui: CanvasLayer) -> void:
	var actions := [
		{"text": "BOOST", "glyph": "boost", "cost": 80, "y": 392, "color": Color("123c70")},
		{"text": "SHIELD", "glyph": "shield", "cost": 120, "y": 488, "color": Color("174d7a")},
		{"text": "MAP", "glyph": "map", "cost": 0, "y": 584, "color": Color("17191f")},
	]
	for a in actions:
		var b := Button.new()
		b.position = Vector2(26, int(a["y"]))
		b.custom_minimum_size = Vector2(86, 82)
		b.size = Vector2(86, 82)
		_style_button(b, a["color"], 16)
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon: Control = GlyphIcon.new().setup(a["glyph"], Color.WHITE, 34)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(icon)
		vb.add_child(_hud_text(a["text"], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		if int(a["cost"]) > 0:
			vb.add_child(_hud_text(str(a["cost"]), 14, Color("ffd34d"), HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(vb)
		ui.add_child(b)

func _build_toolbar(ui: CanvasLayer) -> void:
	var hb := HBoxContainer.new()
	hb.position = Vector2(Palette.CENTER_X - 268, Palette.DESIGN_H - 118)
	hb.add_theme_constant_override("separation", 10)
	ui.add_child(hb)
	_add_build_card(hb, "CASTLE", 500, "castle")
	_add_build_card(hb, "TOWER", 250, "tower")
	_add_build_card(hb, "FARM", 200, "farm")
	_add_build_card(hb, "BARRACKS", 350, "barracks")

func _add_build_card(parent: Node, label: String, cost: int, kind: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 104)
	_style_button(b, Color("111820"), 14)
	b.pressed.connect(func() -> void: _buy_building(kind, cost))
	# sticker icon + name + coin-cost, stacked and centred inside the card
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon: Control = GlyphIcon.new().setup(kind, Color.WHITE, 46)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(icon)
	vb.add_child(_hud_text(label, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(_cost_row(cost))
	b.add_child(vb)
	parent.add_child(b)
	_build_btns[kind] = b

# Centred "🪙 250" cost row using the DrawKit coin glyph.
func _cost_row(cost: int) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c: Control = GlyphIcon.new().setup("coin", Color("ffc31f"), 20)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(c)
	hb.add_child(_hud_text(str(cost), 17, Color("ffd34d")))
	return hb

func _style_button(b: Button, color: Color, radius: int) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(color, 0.92)
	st.border_color = Color(1, 1, 1, 0.16)
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(8)
	st.shadow_color = Color(0, 0, 0, 0.32)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", st)
	var hover := st.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := st.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.18)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 4)

func _buy_building(kind: String, cost: int) -> void:
	if _coins < cost:
		_toast("Need more coins", Palette.WARN)
		return
	_coins -= cost
	match kind:
		"castle":
			_castle_floor = mini(_castle_floor + 1, 4)
			for c in _rulers[0].castles:
				if c["node"] != null:
					c["node"].update_tier(maxi(c["node"].tier, _castle_floor))
		"tower":
			_towers += 1
			_rulers[0].defense += 1
		"farm":
			_farms += 1
		"barracks":
			_barracks += 1
	_toast("%s built" % kind.capitalize(), _kid_color[_rulers[0].kid])

func _display_kingdom_name(kid: int) -> String:
	return KINGDOM_LABELS[(kid - 1) % KINGDOM_LABELS.size()]

func _population_estimate(owned: int) -> int:
	return maxi(12, int(float(owned) * 0.55) + _farms * 8 + _barracks * 14)

func _build_hud_old(ui: CanvasLayer) -> void:
	var pill := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.07, 0.12, 0.72)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(12)
	pill.add_theme_stylebox_override("panel", st)
	pill.position = Vector2(24, 20)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pill)
	_terr_label = Label.new()
	_terr_label.add_theme_font_size_override("font_size", 28)
	_terr_label.add_theme_color_override("font_color", Color.WHITE)
	pill.add_child(_terr_label)

	# match countdown, centred at the top
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 36)
	_time_label.add_theme_color_override("font_color", Color.WHITE)
	_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_time_label.add_theme_constant_override("outline_size", 6)
	_time_label.position = Vector2(Palette.CENTER_X - 50, 16)
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_time_label)

	var hint := Label.new()
	hint.text = "Leave home · draw a loop · return to claim   ·   cut a rival's trail to pop them!"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("outline_size", 6)
	hint.position = Vector2(24, 78)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hint)

	# leaderboard panel (top-right)
	var lb := PanelContainer.new()
	var lst := StyleBoxFlat.new()
	lst.bg_color = Color(0.05, 0.07, 0.12, 0.72)
	lst.set_corner_radius_all(14)
	lst.set_content_margin_all(12)
	lb.add_theme_stylebox_override("panel", lst)
	lb.position = Vector2(Palette.DESIGN_W - 330, 20)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(lb)
	var vb := VBoxContainer.new()
	lb.add_child(vb)
	var title := Label.new()
	title.text = "KINGDOMS"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vb.add_child(title)
	for i in N_KINGDOMS:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 20)
		vb.add_child(row)
		_lb_rows.append(row)

	# minimap (bottom-right) — the strategic whole-board view
	_minimap = Minimap.new()
	_minimap.setup(GW, GH)
	_minimap.position = Vector2(Palette.DESIGN_W - 258, Palette.DESIGN_H - 200)
	ui.add_child(_minimap)

func _hud_tick(delta: float) -> void:
	var owned: int = grid.territory_count(_rulers[0].kid)
	# Gentle, capped zoom-out as the realm grows (much milder than before — tops at 1.3x).
	camera.zoom = clampf(1.0 + sqrt(float(owned)) / 125.0, 1.0, 1.18)
	_income = 20.0 + float(owned) / 120.0 + float(_farms) * 6.0 + float(_barracks) * 2.0
	_coin_accum += (_income / 60.0) * delta
	if _coin_accum >= 1.0:
		var gained := int(_coin_accum)
		_coins += gained
		_coin_accum -= float(gained)

	_hud_t -= delta
	if _hud_t > 0.0:
		return
	_hud_t = 0.2

	var total := float(GW * GH)
	var pct := 100.0 * owned / total
	var pop := _population_estimate(owned)
	_terr_label.text = "%.1f%%" % pct
	_pop_label.text = "Population        %d" % pop
	_income_label.text = "Coins / min       %d" % int(round(_income))
	_coins_label.text = "COINS  %d" % _coins
	_pop_pill_label.text = "POP  %d" % pop

	var secs := int(ceil(_match_t))
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]

	var standings: Array = []
	for kid in _kids:
		standings.append({"kid": kid, "n": grid.territory_count(kid)})
	standings.sort_custom(func(x, y): return x["n"] > y["n"])
	for r in _lb_rows.size():
		var e: Dictionary = standings[r]
		var rr: Dictionary = _lb_rows[r]
		var kc: Color = _kid_color[e["kid"]]
		var lead := r == 0
		rr["rank"].text = "%d" % (r + 1)
		rr["chip"].bg_color = kc
		rr["name"].text = _display_kingdom_name(e["kid"])
		rr["name"].add_theme_color_override("font_color",
			Color.WHITE if lead else Color(0.86, 0.88, 0.92))
		rr["name"].add_theme_font_override("font",
			ArcadeTheme.font_heavy if lead else ArcadeTheme.font)
		rr["pct"].text = "%.1f%%" % (100.0 * e["n"] / total)
		rr["pct"].add_theme_color_override("font_color", kc.lightened(0.25) if lead else Color(0.86, 0.88, 0.92))

	# minimap ruler dots
	var marks: Array = []
	for a in _rulers:
		if a.eliminated:
			continue
		var mc := _w2c(a.avatar.global_position)
		marks.append({
			"pos": Vector2(float(mc.x) / GW, float(mc.y) / GH),
			"color": _kid_color[a.kid],
			"you": a == _rulers[0],
		})
	_minimap.set_markers(marks)

func _dbg_tick(delta: float) -> void:
	_dbg_t -= delta
	if _dbg_t > 0.0:
		return
	_dbg_t = 1.5
	var parts: Array = []
	for kid in _kids:
		parts.append("k%d=%d" % [kid, grid.territory_count(kid)])
	print("[dbg] ", " ".join(parts))
