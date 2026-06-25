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
const Campaign := preload("res://toybox_kingdoms/data/campaign.gd")
const Minimap := preload("res://toybox_kingdoms/ui/minimap.gd")
const GlyphIcon := preload("res://toybox_kingdoms/ui/glyph_icon.gd")
const Scatter := preload("res://toybox_kingdoms/env/scatter.gd")
const GrassTexture := preload("res://toybox_kingdoms/env/grass_texture.gd")
const TerritoryGround := preload("res://toybox_kingdoms/grid/territory_ground.gd")
const Flags := preload("res://toybox_kingdoms/kingdom/flags.gd")
const Windmills := preload("res://toybox_kingdoms/kingdom/windmills.gd")

const GW := 128
const GH := 96
const CELL := 0.6
const HOME_R := 5
const N_KINGDOMS := 8           # 1 human + 7 AI
const HUMAN_INPUT_ID := 0
const HUMAN_SPEED := 7.0          # human's base carve speed (faster than AI_SPEED 6.3)
const BARRACKS_SPEED := 0.55      # each BARRACKS makes your king carve this much faster
const SPEED_CAP := 11.0           # speed ceiling so boosts stay controllable
const AI_SPEED := 6.3
const AI_DECIDE_EVERY := 4        # re-run each AI brain every Nth physics frame (~15Hz),
								  # staggered by kid so they never all decide on one frame
const RESPAWN_TIME := 1.2
const BLOB_SCALE := 0.62         # rival ruler blob size (incl. after respawn)
const KING_SCALE := 0.75         # YOUR Crowned Toy King reads bigger than rivals
const MATCH_DURATION := 300.0   # seconds (5 min — long enough for the castle-war to play out)
# A match ends ONLY two ways: every rival is conquered (last kingdom standing), or
# the timer runs out. There is NO instant land-threshold win — you play the full
# clock unless you wipe everyone out. At timeout you WIN only if you hold at least
# WIN_PCT of the toybox; otherwise you lose.
const WIN_PCT := 0.50           # land you must hold AT TIMEOUT to win

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
var _flags
var _windmills
var _kingdom_t := 0.0
var _terr_rebuild_t := 0.0
var _minimap_t := 0.0           # rate-limits the minimap's full 2nd-scene render
var _minimap_pending := false   # board changed but its render is still throttled
# Decoration rebuilds (full-board scans) only re-run when ownership actually changed
# since they last ran, and populace/flags alternate ticks so they never spike together.
var _last_pop_version := -1
var _last_flag_version := -1
var _decor_phase := 0
var _frame := 0                 # physics frame counter (drives staggered AI decides)

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
var _build_btns := {}           # kind -> {"btn","cost","cost_label","icon","title"}
var _timer_panel: PanelContainer
var _last_secs := -1

var _dbg := false
var _dbg_t := 0.0
var _fps_label: Label           # on-screen perf overlay (toggle with F3)
var _fps_t := 0.0

# ── campaign stage (read from SaveManager; falls back to the N_KINGDOMS default) ──
var _stage := 0
var _n_kingdoms := N_KINGDOMS    # this match's kingdom count (1 human + rivals)
var _rival_diffs: Array = []     # per-rival AI difficulty for this stage
var _stage_msg := ""             # results banner ("Stage cleared!" / "Campaign complete!")

func _ready() -> void:
	_dbg = OS.get_environment("TBK_DEBUG") == "1"
	var fast := OS.get_environment("TBK_FASTMATCH")
	if fast != "":
		_match_t = float(fast)

	# Load this match's stage from the campaign ladder. Rival count + AI difficulty
	# escalate per stage; the human is always kingdom 0.
	_stage = SaveManager.active_stage()
	_rival_diffs = Campaign.rival_diffs(_stage)
	_n_kingdoms = 1 + _rival_diffs.size()
	AudioManager.play_music("game")
	_apply_render_scale()
	_build_environment()
	_build_ground()

	grid = Grid.new()
	grid.setup(GW, GH)

	# colors first so the renderer can draw every kingdom
	for i in _n_kingdoms:
		var kid := i + 1
		_kids.append(kid)
		_kid_color[kid] = _kingdom_color(i, _n_kingdoms)

	renderer = GridRenderer.new()
	add_child(renderer)
	renderer.setup(grid, CELL, _kid_color)   # trails + flash only now (cube fill removed)

	# spawn kingdoms
	for i in _n_kingdoms:
		_spawn_kingdom(i)

	# castle homes drive road hubs (ground), village clustering (populace) and flags.
	var homes := {}
	for a in _rulers:
		homes[a.kid] = a.home

	# painted-ground territory (checked-in look: green wilderness + raised plates)
	_ground = TerritoryGround.new()
	add_child(_ground)
	_ground.setup(grid, CELL, _kid_color)
	_ground.update()
	renderer.rebuild_borders()   # raised kingdom-coloured walls ring each territory

	# the town layer: houses + citizens rising from claimed land
	_populace = Populace.new()
	add_child(_populace)
	_populace.setup(grid, CELL, _kid_color, homes)
	_populace.rebuild()

	# windmills + border flags: the "living kingdom" dressing
	_windmills = Windmills.new()
	add_child(_windmills)
	_windmills.setup(grid, CELL, _kid_color, homes)
	_windmills.rebuild()
	_flags = Flags.new()
	add_child(_flags)
	_flags.setup(grid, CELL, _kid_color)
	_flags.rebuild()

	# lush wilderness: trees / rocks / bushes on neutral land
	_scatter = Scatter.new()
	add_child(_scatter)
	_scatter.setup(grid, CELL)
	_scatter.rebuild()

	# camera follows the human
	camera = KingdomCamera.new()
	camera.offset = Vector3(0.0, 12.6, 15.2)   # lower, more cinematic 3/4 diorama framing
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
	_build_fps_overlay(_ui_layer)

func _spawn_kingdom(i: int) -> void:
	var kid: int = i + 1
	var info: Dictionary = Roster.info(i)
	_kid_name[kid] = info["name"]
	var home := _home_anchor(i, _n_kingdoms)
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
	av.set_body_scale(KING_SCALE if i == 0 else BLOB_SCALE)
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
		# Stage sets each rival's difficulty (escalating ladder); fall back to the
		# roster's personality diff if this stage doesn't specify one for this rival.
		var diff: int = int(info["diff"])
		if i - 1 < _rival_diffs.size():
			diff = int(_rival_diffs[i - 1])
		a.ai.setup(diff, 1000 + i * 7)
	else:
		_player = pdata
		av.auto_input = true                # human reads InputManager id 0
		av.speed = HUMAN_SPEED              # base carve speed (BARRACKS stacks on top)
		_attach_king_aura(av, _kid_color[kid])   # glowing ground ring → never lose your king

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

# Render the 3D board at a fraction of the screen resolution on phones and upscale
# it — the blocky toybox art still reads cleanly while we reclaim a lot of fragment
# load (the per-cell ground shader is fill-rate heavy). The 2D HUD/minimap is drawn
# by CanvasLayers, so it stays at full crispness. Desktop renders at native scale;
# set TBK_LOWRES=<0..1> to preview the mobile path on desktop.
const MOBILE_RENDER_SCALE := 0.75

func _apply_render_scale() -> void:
	var scale := 1.0
	if DeviceMode.is_mobile:
		scale = MOBILE_RENDER_SCALE
	var override := OS.get_environment("TBK_LOWRES")
	if override != "":
		scale = clampf(float(override), 0.25, 1.0)
	if is_equal_approx(scale, 1.0):
		return
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale

func _physics_process(delta: float) -> void:
	if _ended:
		return
	_match_t = maxf(0.0, _match_t - delta)

	# 1. drive AI movement (humans move themselves in Avatar3D._physics_process)
	# The AI brain (pathfinding/territory eval) is the heaviest per-frame CPU cost, so
	# it's throttled to ~15Hz and staggered across rulers — the avatar still moves every
	# frame on the last decided heading, so motion stays smooth. (mobile CPU safeguard)
	_frame += 1
	for a in _rulers:
		if a.is_ai and a.alive:
			if (_frame + a.kid) % AI_DECIDE_EVERY == 0:
				a.cached_dir = a.ai.decide(a, self)
			var dir: Vector2 = a.cached_dir
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
	_minimap_t -= delta
	if grid.has_dirty() and _terr_rebuild_t <= 0.0:
		# Only repaint the cells that actually changed since the last tick (the grid's
		# dirty rect) instead of rescanning all 12k cells. A small capture touches a
		# tiny rect; only a board-spanning event (a whole kingdom falling) approaches
		# the old full-scan cost.
		var dmin: Vector2i = grid.dirty_min
		var dmax: Vector2i = grid.dirty_max
		_ground.update(dmin.x, dmin.y, dmax.x, dmax.y)
		renderer.rebuild_borders(dmin.x, dmin.y, dmax.x, dmax.y)
		_minimap_pending = true     # board changed → queue an aerial refresh
		grid.reset_dirty()
		_terr_rebuild_t = 0.1
	# The minimap is a full SECOND scene render, so cap it to ~3/s and always render
	# the latest state — far cheaper than firing it on every 10Hz territory tick.
	if _minimap_pending and _minimap_t <= 0.0:
		_minimap.request_render()
		_minimap_pending = false
		_minimap_t = 0.33
	_kingdom_tick(delta)
	_hud_tick(delta)
	if _fps_label and _fps_label.visible:
		_fps_t -= delta
		if _fps_t <= 0.0:
			_fps_t = 0.25
			_update_fps()
	if _dbg:
		_dbg_tick(delta)

# Grow towns + upgrade castles on a cadence (not every frame).
func _kingdom_tick(delta: float) -> void:
	_kingdom_t -= delta
	if _kingdom_t > 0.0:
		return
	_kingdom_t = 0.4
	# Populace + flags are full-board scans. Skip them when no land changed since the
	# last build, and alternate them across ticks so only one runs per 0.4s spike.
	var v: int = grid.version
	if _decor_phase == 0:
		if v != _last_pop_version:
			_populace.rebuild()
			_last_pop_version = v
		_decor_phase = 1
	else:
		if v != _last_flag_version:
			_flags.rebuild()
			_last_flag_version = v
		_decor_phase = 0
	_windmills.rebuild()
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
	elif alive == 1:
		_end_match(true, "conquest")               # win: last kingdom standing
	elif _match_t <= 0.0:
		_end_match(human_pct >= WIN_PCT, "timeout")  # win only if holding >=50% at the buzzer

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
	var coins: int = int(pct * 300.0) + maxi(0, _n_kingdoms - rank) * 15 + (60 if win else 0)
	SaveManager.add_coins(coins)
	# Advance the campaign ladder on a win (only the frontier stage unlocks new ground).
	if win:
		if SaveManager.clear_stage(_stage):
			if SaveManager.campaign_complete():
				_stage_msg = "Campaign complete!  You rule the toybox 👑"
			else:
				_stage_msg = "Stage cleared!  Next: %s" % Campaign.title(SaveManager.active_stage())
		else:
			_stage_msg = "Stage replayed  ·  %s" % Campaign.title(_stage)
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
		"conquest": sub = "You conquered every rival kingdom!"
		"conquered": sub = "Your kingdom was wiped off the map."
		"timeout":
			if win:
				sub = "Time's up — you ruled %.0f%% of the toybox!" % (pct * 100.0)
			else:
				sub = "Time's up — you held %.0f%% (need 50%%), #%d of %d." % [pct * 100.0, rank, _n_kingdoms]
		_: sub = "You finished #%d of %d." % [rank, _n_kingdoms]
	_result_label(vb, sub, 26, Color.WHITE)

	# Campaign ladder banner (stage cleared / campaign complete / replayed).
	if _stage_msg != "":
		_result_label(vb, _stage_msg, 24, Palette.SAFE if win else Color.WHITE)

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
	a.avatar.set_body_scale(BLOB_SCALE if a.is_ai else KING_SCALE)   # revive() resets scale — re-apply
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
	Color("4d9ef5"), Color("d22323"), Color("33a23a"), Color("ecae12"),
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
	env.background_color = Color("0e1512")   # dark frame → saturated plates pop (checked-in look)

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
	# Forward+ only AND a heavy full-screen pass — off on mobile (where it's either
	# ignored by the render fallback or, on a Forward+ phone, pure cost).
	env.ssao_enabled = not DeviceMode.is_mobile
	env.ssao_intensity = 2.4
	env.ssao_radius = 0.6                    # tight — matches the 0.6 CELL size
	env.ssao_power = 2.0
	env.ssao_detail = 0.6

	# Gentle grade — materials + glow carry the vibrancy now, so the acid is gone.
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.38         # deep, rich toy-plate colours (checked-in look)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# warm key sun — crisp but soft-edged shadows sell the clay relief
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -125, 0)
	key.light_color = Color("ffeccd")        # ~5400K warm sunlight (less amber wash)
	key.light_energy = 1.1                   # warm key (checked-in look)
	key.shadow_enabled = true
	key.shadow_opacity = 0.6
	key.shadow_blur = 1.0                     # was 3.2 → far too mushy
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.5             # kills peter-panning on the plateau
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key.directional_shadow_max_distance = 90.0
	if DeviceMode.is_mobile:
		# Phones: fewer cascades + a nearer shadow distance slashes shadow-pass draw
		# calls (every caster is re-rendered once per cascade). The board still gets
		# grounded contact shadows up close, where they actually read.
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		key.directional_shadow_max_distance = 50.0
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

# ── HUD design tokens ─────────────────────────────────────────────────────────
# One palette + a couple of helpers so every panel, pill and card reads as one
# cohesive UI instead of a pile of one-off magic colours.
const HUD_INK     := Color(0.05, 0.06, 0.09, 0.90)   # default panel fill
const HUD_INK_HI  := Color(0.10, 0.12, 0.17, 0.94)   # raised / interactive fill
const HUD_STROKE  := Color(1, 1, 1, 0.12)            # hairline border
const HUD_GOLD    := Color("ffd34d")
const HUD_BLUE    := Color("7cb6ff")
const HUD_DIM     := Color(0.74, 0.78, 0.84)         # secondary / caption text

# ── HUD: territory readout + live leaderboard ─────────────────────────────────
func _build_hud(ui: CanvasLayer) -> void:
	_lb_rows.clear()
	_build_scrims(ui)                       # top/bottom gradients lift the HUD off the board

	var kc: Color = _kid_color[_rulers[0].kid]

	# ── top-left: your kingdom card (colour accent + big % + stat rows) ──
	var stat := _hud_panel(Vector2(16, 16), Vector2(286, 176), 18)
	ui.add_child(stat)
	var stat_h := HBoxContainer.new()
	stat_h.add_theme_constant_override("separation", 12)
	stat_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat.add_child(stat_h)
	stat_h.add_child(_accent_bar(kc))
	var stat_v := VBoxContainer.new()
	stat_v.add_theme_constant_override("separation", 3)
	stat_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_h.add_child(stat_v)
	stat_v.add_child(_hud_text(_display_kingdom_name(_rulers[0].kid).to_upper(), 19, kc.lightened(0.35)))
	_terr_label = _hud_text("0.0%", 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	stat_v.add_child(_terr_label)
	stat_v.add_child(_thin_rule())
	var pr := _stat_row("people", HUD_BLUE, "Population")
	stat_v.add_child(pr["row"]); _pop_label = pr["value"]
	var ir := _stat_row("coin", HUD_GOLD, "Coins / min")
	stat_v.add_child(ir["row"]); _income_label = ir["value"]

	# ── top-centre: match countdown ──
	_timer_panel = _hud_panel(Vector2(Palette.CENTER_X - 104, 14), Vector2(208, 64), 20)
	ui.add_child(_timer_panel)
	var th := _pill_row(_timer_panel)
	th.add_theme_constant_override("separation", 9)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_child(_glyph(GlyphIcon.new().setup("clock", HUD_GOLD, 26)))
	_time_label = _hud_text("0:00", 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	th.add_child(_time_label)

	# ── top-right: coins + population pills, then settings ──
	var coins := _hud_panel(Vector2(Palette.DESIGN_W - 446, 16), Vector2(196, 58), 16)
	ui.add_child(coins)
	var ch := _pill_row(coins); ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(_glyph(GlyphIcon.new().setup("coin", HUD_GOLD, 28)))
	_coins_label = _hud_text("0", 26, HUD_GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	ch.add_child(_coins_label)

	var pop := _hud_panel(Vector2(Palette.DESIGN_W - 238, 16), Vector2(160, 58), 16)
	ui.add_child(pop)
	var ph := _pill_row(pop); ph.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_child(_glyph(GlyphIcon.new().setup("people", HUD_BLUE, 28)))
	_pop_pill_label = _hud_text("0", 26, HUD_BLUE, HORIZONTAL_ALIGNMENT_LEFT, true)
	ph.add_child(_pop_pill_label)

	var gear := Button.new()
	gear.text = "SET"
	gear.position = Vector2(Palette.DESIGN_W - 66, 16)
	gear.size = Vector2(50, 58)
	gear.custom_minimum_size = Vector2(50, 58)
	gear.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(gear, HUD_INK_HI, 16)
	_hover_lift(gear)
	ui.add_child(gear)

	# ── right: live leaderboard ──
	var lb := _hud_panel(Vector2(Palette.DESIGN_W - 300, 90), Vector2(284, 350), 16)
	ui.add_child(lb)
	var lb_v := VBoxContainer.new()
	lb_v.add_theme_constant_override("separation", 4)
	lb_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_child(lb_v)
	var lb_title := _hud_text("LEADERBOARD", 18, HUD_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	lb_title.add_theme_constant_override("outline_size", 4)
	lb_v.add_child(lb_title)
	lb_v.add_child(_thin_rule())
	for i in _n_kingdoms:
		var rr := _make_lb_row()
		lb_v.add_child(rr["row"])
		_lb_rows.append(rr)

	_build_action_stack(ui)
	_build_toolbar(ui)

	# Minimap paints from grid data (no 3D render) — no environment needed.
	_minimap = Minimap.new()
	_minimap.setup(GW, GH)
	_minimap.position = Vector2(Palette.DESIGN_W - 286, Palette.DESIGN_H - 202)
	ui.add_child(_minimap)

# A glowing, gently-pulsing ground ring fixed under the human's Crowned Toy King so
# you can always pick yourself out of a crowded board. Emissive + additive so it
# reads as light, not a painted decal. Cheap: one mesh, one looping tween.
func _attach_king_aura(av, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.80
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, 0.85)
	m.emission_enabled = true
	m.emission = color.lightened(0.25)
	m.emission_energy_multiplier = 2.2
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, 0.07, 0)
	av.add_child(ring)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector3(1.14, 1.0, 1.14), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE)

# Radial vignette over the 3D view (under the HUD). Darkens the busy edges so the
# eye lands on the centre of the action — the cheapest "premium screenshot" trick.
func _build_vignette(ui: CanvasLayer) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0.05, 0.03, 0.02, 0.20))   # gentle warm corner falloff, not a dim
	grad.set_offset(0, 0.72)
	grad.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tr)

# Soft top + bottom gradient scrims. They darken the busy 3D board behind the
# HUD just enough that white text + panels always read — the single biggest
# "polished" tell, and it costs almost nothing.
func _build_scrims(ui: CanvasLayer) -> void:
	for top in [true, false]:
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.40 if top else 0.34))
		grad.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 4
		tex.height = 256
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			tr.set_anchors_preset(Control.PRESET_TOP_WIDE)
			tr.offset_bottom = 150.0
		else:
			tr.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			tr.offset_top = -148.0
			tr.flip_v = true
		ui.add_child(tr)

# Thin rounded colour bar — the kingdom's identity stripe down the stat card.
func _accent_bar(color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(6, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = color.lightened(0.1)
	st.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", st)
	return p

# Wrap a GlyphIcon so it sits nicely (vertically centred) inside an HBox.
func _glyph(icon: Control) -> Control:
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

# An HBox that fills a pill panel, used to lay an icon beside a value label.
func _pill_row(panel: PanelContainer) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hb)
	return hb

# One stat line in the kingdom card: icon · caption (left) · value (right). The
# returned "value" label is what _hud_tick repaints each refresh.
func _stat_row(glyph: String, color: Color, caption: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_glyph(GlyphIcon.new().setup(glyph, color, 18)))
	var cap := _hud_text(caption, 19, HUD_DIM)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap)
	var value := _hud_text("0", 21, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
	row.add_child(value)
	return {"row": row, "value": value}

# Hover/press feel for a button: a gentle scale lift on hover, settle on exit.
# Scales around the centre so HBox-laid cards don't shove their neighbours.
func _hover_lift(b: Button, lift := 1.06) -> void:
	b.pivot_offset = b.custom_minimum_size * 0.5
	b.mouse_entered.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(lift, lift), 0.10).set_trans(Tween.TRANS_BACK))
	b.mouse_exited.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK))

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
	# Panel wrapper so the human's row (and the leader) can carry a tinted
	# highlight behind the rank · chip · name · % layout.
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(252, 32)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 6
	bg.content_margin_right = 6
	bg.content_margin_top = 1
	bg.content_margin_bottom = 1
	wrap.add_theme_stylebox_override("panel", bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(row)
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
	var you := _hud_text("YOU", 13, Color(0.06, 0.07, 0.10))
	you.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	you.add_theme_constant_override("outline_size", 0)
	var you_wrap := PanelContainer.new()
	you_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	you_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var yst := StyleBoxFlat.new()
	yst.bg_color = HUD_GOLD
	yst.set_corner_radius_all(6)
	yst.content_margin_left = 6
	yst.content_margin_right = 6
	yst.content_margin_top = 1
	yst.content_margin_bottom = 1
	you_wrap.add_theme_stylebox_override("panel", yst)
	you_wrap.add_child(you)
	you_wrap.visible = false
	var pct := _hud_text("", 19, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(54, 0)
	row.add_child(rank)
	row.add_child(dot)
	row.add_child(nm)
	row.add_child(you_wrap)
	row.add_child(pct)
	return {"row": wrap, "bg": bg, "rank": rank, "chip": dst, "name": nm, "you": you_wrap, "pct": pct}

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
			vb.add_child(_hud_text(str(a["cost"]), 14, HUD_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(vb)
		_hover_lift(b)
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

# Per-building accent — a colour-coded top stripe so the four cards read apart
# at a glance instead of being four identical dark boxes.
const BUILD_ACCENT := {
	"castle": Color("ffd34d"), "tower": Color("7cb6ff"),
	"farm": Color("64d77a"), "barracks": Color("f06a5a"),
}

func _add_build_card(parent: Node, label: String, cost: int, kind: String) -> void:
	var accent: Color = BUILD_ACCENT.get(kind, HUD_GOLD)
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 106)
	_style_button(b, Color("141b24"), 16)
	b.pressed.connect(func() -> void: _buy_building(kind, cost))
	# coloured accent stripe pinned to the top edge of the card
	var stripe := Panel.new()
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_left = 10; stripe.offset_right = -10
	stripe.offset_top = 7; stripe.offset_bottom = 12
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sst := StyleBoxFlat.new()
	sst.bg_color = accent
	sst.set_corner_radius_all(3)
	stripe.add_theme_stylebox_override("panel", sst)
	b.add_child(stripe)
	# sticker icon + name + coin-cost, stacked and centred inside the card
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon: Control = GlyphIcon.new().setup(kind, Color.WHITE, 44)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(icon)
	vb.add_child(_hud_text(label, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var cr := _cost_row(cost)
	vb.add_child(cr["row"])
	b.add_child(vb)
	_hover_lift(b, 1.05)
	parent.add_child(b)
	_build_btns[kind] = {"btn": b, "cost": cost, "cost_label": cr["label"]}

# Centred "🪙 250" cost row using the DrawKit coin glyph. Returns the row and its
# value Label so affordability can recolour the number.
func _cost_row(cost: int) -> Dictionary:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c: Control = GlyphIcon.new().setup("coin", HUD_GOLD, 20)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(c)
	var l := _hud_text(str(cost), 17, HUD_GOLD)
	hb.add_child(l)
	return {"row": hb, "label": l}

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
	# Every building boosts YOUR own conquest — the economy fuels expansion instead of
	# sitting on the side. The toast names the effect so the payoff is legible.
	var fx := ""
	match kind:
		"castle":
			_castle_floor = mini(_castle_floor + 1, 4)
			for c in _rulers[0].castles:
				if c["node"] != null:
					c["node"].update_tier(maxi(c["node"].tier, _castle_floor))
			fx = "Castle Lv %d — siege bigger keeps" % _castle_floor
		"tower":
			_towers += 1
			_rulers[0].defense += 1
			fx = "Defense +1 — harder to conquer (×%d)" % _towers
		"farm":
			_farms += 1
			fx = "Coins/min up — more to spend (×%d)" % _farms
		"barracks":
			_barracks += 1
			_apply_human_speed()
			fx = "Faster carve — claim more, faster (×%d)" % _barracks
	_toast(fx, _kid_color[_rulers[0].kid])

# Recompute the human king's carve speed from the base + BARRACKS owned (capped).
func _apply_human_speed() -> void:
	if _rulers.is_empty() or _rulers[0].avatar == null:
		return
	_rulers[0].avatar.speed = minf(HUMAN_SPEED + float(_barracks) * BARRACKS_SPEED, SPEED_CAP)

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
	_pop_label.text = "%d" % pop
	_income_label.text = "%d" % int(round(_income))
	_coins_label.text = "%d" % _coins
	_pop_pill_label.text = "%d" % pop

	# affordability: dim build cards you can't afford, gold→red on the cost.
	for kind in _build_btns:
		var bd: Dictionary = _build_btns[kind]
		var afford: bool = _coins >= int(bd["cost"])
		bd["btn"].modulate = Color(1, 1, 1, 1.0) if afford else Color(0.78, 0.80, 0.84, 0.92)
		bd["cost_label"].add_theme_color_override("font_color", HUD_GOLD if afford else Palette.DANGER)

	var secs := int(ceil(_match_t))
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	# final-15s urgency: tick red and punch the pill once per second.
	if secs != _last_secs:
		_last_secs = secs
		if secs <= 15 and secs > 0 and _timer_panel != null:
			_time_label.add_theme_color_override("font_color", Palette.DANGER.lightened(0.15))
			_timer_panel.pivot_offset = _timer_panel.size * 0.5
			var tw := _timer_panel.create_tween()
			tw.tween_property(_timer_panel, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_BACK)
			tw.tween_property(_timer_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
		elif secs > 15:
			_time_label.add_theme_color_override("font_color", Color.WHITE)

	var standings: Array = []
	for kid in _kids:
		standings.append({"kid": kid, "n": grid.territory_count(kid)})
	standings.sort_custom(func(x, y): return x["n"] > y["n"])
	var human_kid: int = _rulers[0].kid
	for r in _lb_rows.size():
		var e: Dictionary = standings[r]
		var rr: Dictionary = _lb_rows[r]
		var kc: Color = _kid_color[e["kid"]]
		var lead := r == 0
		var mine: bool = e["kid"] == human_kid
		rr["rank"].text = "%d" % (r + 1)
		rr["chip"].bg_color = kc
		rr["name"].text = _display_kingdom_name(e["kid"])
		rr["name"].add_theme_color_override("font_color",
			Color.WHITE if (lead or mine) else Color(0.84, 0.87, 0.91))
		rr["name"].add_theme_font_override("font",
			ArcadeTheme.font_heavy if (lead or mine) else ArcadeTheme.font)
		rr["you"].visible = mine
		# tint your own row so you can find yourself at a glance; leader gets a faint gold wash.
		rr["bg"].bg_color = (Color(kc, 0.22) if mine else (Color(HUD_GOLD, 0.08) if lead else Color(0, 0, 0, 0)))
		rr["pct"].text = "%.1f%%" % (100.0 * e["n"] / total)
		rr["pct"].add_theme_color_override("font_color", kc.lightened(0.3) if (lead or mine) else Color(0.84, 0.87, 0.91))

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

# On-screen perf overlay: fps, CPU frame time, draw calls, and the live 3D render
# scale (so you can confirm the mobile downscale is active). Default on; F3 toggles.
func _build_fps_overlay(layer: CanvasLayer) -> void:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(18, Palette.DESIGN_H - 32)
	layer.add_child(l)
	_fps_label = l

func _toggle_fps() -> void:
	if _fps_label:
		_fps_label.visible = not _fps_label.visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_toggle_fps()

func _update_fps() -> void:
	var fps := Engine.get_frames_per_second()
	var cpu := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var scale: float = get_viewport().scaling_3d_scale
	_fps_label.text = "%d fps   cpu %.1f ms (phys %.1f)   %d draws   3D %.0f%%" \
		% [fps, cpu, phys, draws, scale * 100.0]
	var col := Color(0.55, 1.0, 0.55)        # green: smooth
	if fps < 30:
		col = Color(1.0, 0.5, 0.5)           # red: janky
	elif fps < 55:
		col = Color(1.0, 0.92, 0.5)          # yellow: marginal
	_fps_label.add_theme_color_override("font_color", col)

func _dbg_tick(delta: float) -> void:
	_dbg_t -= delta
	if _dbg_t > 0.0:
		return
	_dbg_t = 1.5
	var parts: Array = []
	for kid in _kids:
		parts.append("k%d=%d" % [kid, grid.territory_count(kid)])
	print("[dbg] ", " ".join(parts))
