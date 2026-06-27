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
const TerritorySlabs := preload("res://toybox_kingdoms/grid/territory_slabs.gd")
const Flags := preload("res://toybox_kingdoms/kingdom/flags.gd")
const Windmills := preload("res://toybox_kingdoms/kingdom/windmills.gd")
const Decor := preload("res://toybox_kingdoms/kingdom/decorations.gd")
const CaptureFX := preload("res://toybox_kingdoms/fx/capture_fx.gd")
const Ocean := preload("res://toybox_kingdoms/env/ocean.gd")
const Roads := preload("res://toybox_kingdoms/kingdom/roads.gd")

const GW := 128
const GH := 96
const CELL := 0.6
const HOME_R := 5
const N_KINGDOMS := 8           # 1 human + 7 AI
const HUMAN_INPUT_ID := 0
const HUMAN_SPEED := 6.7          # human's base carve speed (faster than AI_SPEED 5.04) — snappier walk
const BARRACKS_SPEED := 0.44      # each BARRACKS makes your king carve this much faster
const SPEED_CAP := 9.8            # speed ceiling so boosts stay controllable
const AI_SPEED := 5.04            # 20% slower
var _ai_decide_every: int = 4     # re-run each AI brain every Nth physics frame (~15Hz);
								  # raised to 6 on mobile (~10Hz) — avatars still move smoothly on cached heading
const RESPAWN_TIME := 1.2
# Claimed cells rise into a raised plateau in the ground shader (territory_ground.gd
# `plateau`). Avatars sit at Y=0, so without this lift their feet + the king's ground
# ring sink into owned tiles. Raise the avatar by the plateau height while it stands
# on claimed land (smoothly, so the step on/off the plate isn't a pop).
const CLAIMED_LIFT := 0.20       # must track territory_slabs.gd SLAB_H (avatars ride the slab top)
const GROUND_LERP := 12.0        # how fast the avatar settles to the new ground height
const BLOB_SCALE := 0.93         # rival ruler blob size (incl. after respawn) — 1.5× base
const KING_SCALE := 1.125        # YOUR Crowned Toy King reads bigger than rivals — 1.5× base
const MATCH_DURATION := 300.0   # seconds (5 min — long enough for the castle-war to play out)
# A match ends ONLY two ways: every rival is conquered (last kingdom standing), or
# the timer runs out. There is NO instant land-threshold win — you play the full
# clock unless you wipe everyone out. At timeout you WIN only if you hold at least
# WIN_PCT of the toybox; otherwise you lose.
const WIN_PCT := 0.50           # land you must hold AT TIMEOUT to win

# ── ENDLESS mode (truly endless — a chain of escalating islands) ───────────────
# A RUN is a sequence of islands. CONQUER an island (be the last kingdom standing) →
# fly to the next, harder island with your score carried forward. LOSE all your castles
# → the run ends and the total score is banked. The chain is UNTIMED: there is no clock
# and no timeout — you advance only by winning, you end only by dying. Each island
# reloads the scene with a harder config.

# ── DAILY CHALLENGE mode ───────────────────────────────────────────────────────
# A single, date-SEEDED timed run — the same board for every player that day — scored
# like one endless island. First completion of the day pays a streak reward.
const DAILY_DURATION := 150.0
const DAILY_DIFFICULTY := 2             # fixed mid difficulty (≈ endless island 2) for a meaty single run

var grid
var renderer
var camera
var _player                     # human PlayerData

var _rulers: Array = []         # Array[RulerAgent]
var _kid_to_agent := {}
var _kids: Array = []
var _kid_color := {}
var _kid_label := {}        # colour-matched HUD/leaderboard name ("Your Kingdom" for the human)
var _kid_name := {}
var _kid_tier := {}        # kid -> castle tier (1..4); gates which decorations unlock
var _minimap

var _populace
var _scatter
var _ground
var _slabs
var _flags
var _windmills
var _decor
var _roads
var _road_tick := 0          # counts _kingdom_tick calls; roads rebuild every N ticks
var _last_road_version := -1
var _kingdom_t := 0.0
var _terr_rebuild_t := 0.0
var _minimap_t := 0.0           # rate-limits the minimap's full 2nd-scene render
var _minimap_pending := false   # board changed but its render is still throttled
# Decoration rebuilds (full-board scans) only re-run when ownership actually changed
# since they last ran, and populace/flags alternate ticks so they never spike together.
var _last_pop_version := -1
var _last_flag_version := -1
var _last_decor_version := -1
var _decor_phase := 0
var _frame := 0                 # physics frame counter (drives staggered AI decides)

var _ended := false
var _match_t := MATCH_DURATION
var _elapsed := 0.0              # seconds since the match began (analytics timing)
var _first_capture_logged := false
var _is_first_match := false    # player's first-ever match → guided coach + pure-carve HUD
var _coach: Control             # the first-match coaching banner (dismissed on first claim)
var _coach_label: Label         # coach text (swaps "draw a loop" → "return home")
var _mode := "campaign"         # "campaign" | "endless"
var _endless_island := 0        # which island of the endless run this is (0-based)
var _peak_pct := 0.0            # highest land fraction the human held on THIS island
var _rivals_conquered := 0      # rival kingdoms the human eliminated on THIS island
var _endless_score := 0         # final run total (set when the run ends); also the daily score
var _endless_is_best := false
var _daily_streak := 0          # daily-challenge results display
var _daily_reward := 0
var _daily_first := false
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
var _coins_chip: Control        # the top-right coins pill (pops when you earn land)
var _fx                         # CaptureFX node (confetti + coin bursts)
var _fx_cooldown := 0.0         # rate-limit player capture bursts
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

	# Configure rivals + match length from the mode. ENDLESS is a fixed hard run; CAMPAIGN
	# escalates per stage. The human is always kingdom 0. A TBK_FASTMATCH override always
	# wins so the headless harness can still run short matches.
	_mode = SaveManager.mode()
	if OS.get_environment("TBK_ENDLESS") == "1":
		_mode = "endless"
	if OS.get_environment("TBK_DAILY") == "1":
		_mode = "daily"
	if _mode == "daily":
		# Seed the global RNG from the date so the board (scatter/decor) is identical for
		# everyone today; AI brains already seed deterministically. A fixed mid difficulty
		# keeps the daily a single comparable challenge.
		seed(SaveManager.daily_seed())
		_rival_diffs = _endless_rivals_for(DAILY_DIFFICULTY)
		_n_kingdoms = 1 + _rival_diffs.size()
		if fast == "":
			_match_t = DAILY_DURATION
	elif _mode in ["endless", "timed"]:
		# UNTIMED: you advance ONLY by conquering the island (last kingdom standing);
		# only losing all your castles ends the run. No clock, no timeout.
		_endless_island = SaveManager.endless_island()
		_rival_diffs = _endless_rivals_for(_endless_island)
		_n_kingdoms = 1 + _rival_diffs.size()
	else:
		_stage = SaveManager.active_stage()
		_rival_diffs = Campaign.rival_diffs(_stage)
		_n_kingdoms = 1 + _rival_diffs.size()
		if fast == "":
			_match_t = Campaign.duration(_stage)
	# The very first match the player ever starts gets the guided coach + a pure-carve
	# HUD (no build economy yet). Counted once here so a "Play Again" reload is match 2+.
	# Run modes (endless/timed) are never a first-match — no coach / no deferral.
	# TBK_FIRSTMATCH=1 forces the first-match path for QA without resetting the save.
	_is_first_match = _mode == "campaign" and (SaveManager.stat("matches_played") == 0 \
		or OS.get_environment("TBK_FIRSTMATCH") == "1")
	SaveManager.bump_stat("matches_played")
	Analytics.match_start(_stage, _n_kingdoms, _mode, 0.0 if _mode in ["endless", "timed"] else _match_t)
	if _mode == "campaign":
		Analytics.progression("start", "stage_%d" % _stage)
	AudioManager.play_music("game")
	_apply_render_scale()
	if DeviceMode.is_mobile:
		_ai_decide_every = 6        # ~10 Hz AI decisions; avatars still move every frame on cached heading
	_build_environment()
	_build_ground()

	grid = Grid.new()
	grid.setup(GW, GH)

	# colors first so the renderer can draw every kingdom
	for i in _n_kingdoms:
		_kids.append(i + 1)
	_assign_kingdom_colors()

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

	# painted-ground territory: flat wilderness plane (territory_ground) + thick raised
	# colour slabs on claimed land (territory_slabs) → the paper-cutout look of the target
	_ground = TerritoryGround.new()
	add_child(_ground)
	_ground.setup(grid, CELL, _kid_color)
	_ground.update()
	# Walls-only: territory_slabs draws just the perimeter wall blocks (no raised slab
	# plates), sitting on the flat ground so claimed land stays flat.
	_slabs = TerritorySlabs.new()
	add_child(_slabs)
	_slabs.setup(grid, CELL, _kid_color)
	_slabs.rebuild()

	# the town layer: houses + citizens rising from claimed land. All these props sit on
	# claimed cells, so the whole layer is lifted onto the slab top (CLAIMED_LIFT).
	_populace = Populace.new()
	add_child(_populace)
	_populace.position.y = CLAIMED_LIFT
	_populace.setup(grid, CELL, _kid_color, homes)
	_populace.rebuild()

	# windmills + border flags: the "living kingdom" dressing
	_windmills = Windmills.new()
	add_child(_windmills)
	_windmills.position.y = CLAIMED_LIFT
	_windmills.setup(grid, CELL, _kid_color, homes)
	_windmills.rebuild()
	# (Border flags removed — user request; the brick walls now read the frontier.)
	_decor = Decor.new()
	add_child(_decor)
	_decor.position.y = CLAIMED_LIFT
	_decor.setup(grid, CELL, homes)
	_decor.rebuild()

	# dirt roads connecting each kingdom's buildings to its castle
	_roads = Roads.new()
	add_child(_roads)
	_roads.position.y = CLAIMED_LIFT   # sit on top of the claimed-land plateau (same as populace/windmills/decor)
	_roads.populace     = _populace
	_roads.windmills_ref = _windmills
	_roads.decor_ref    = _decor
	_roads.setup(grid, homes)
	for a in _rulers:
		_roads.rebuild(a.kid, _kid_tier.get(a.kid, 1), grid.territory_count(a.kid))
	_last_road_version = grid.version

	# lush wilderness: trees / rocks / bushes on neutral land
	_scatter = Scatter.new()
	add_child(_scatter)
	_scatter.setup(grid, CELL)
	_scatter.rebuild()

	# capture-celebration particles (confetti + coins), fired on the player's claims
	_fx = CaptureFX.new()
	add_child(_fx)

	# camera follows the human — framing is a player setting (SaveManager.camera_mode):
	#   "hero" = cinematic 3/4 diorama (default), "map" = steep near-top-down flat-paper view
	camera = KingdomCamera.new()
	add_child(camera)
	_apply_camera_mode(SaveManager.camera_mode())
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

	# Endless: on islands after the first, fade in from the clear-wipe cover so the jump
	# reads as continuous; announce the island either way.
	if _mode in ["endless", "timed"]:
		if _endless_island > 0:
			_endless_intro()
			_toast("ISLAND %d   ·   Score %s" % [_endless_island + 1, _comma(SaveManager.endless_run_score())], Palette.WARN)
		else:
			_toast("ISLAND 1", Palette.WARN)
	elif _mode == "campaign":
		# Tell the player which stage of the 10-stage campaign they're on.
		_toast("STAGE %d/%d   ·   %s" % [_stage + 1, Campaign.count(), Campaign.title(_stage)], Palette.WARN)

func _spawn_kingdom(i: int) -> void:
	var kid: int = i + 1
	var info: Dictionary = Roster.info(i)
	_kid_name[kid] = info["name"]
	var home := _home_anchor(i, _n_kingdoms)
	# On the player's very first match, give the human a bigger starting blob: a larger
	# home is an easier target to loop back to, so the very first claim lands fast (the
	# time-to-first-capture metric). Rivals + all later matches use the standard HOME_R.
	var home_r := HOME_R
	if i == 0 and _is_first_match:
		home_r = HOME_R + 2
	grid.seed_kingdom(kid, home.x, home.y, home_r)

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
		av.make_royal(_kid_color[kid])      # gold crown + cape → you ARE the Toy King
		_attach_king_aura(av, _kid_color[kid])   # glowing ground ring → never lose your king

	# castle at home, starts as a lone keep and grows with the realm
	var castle = Castle.new()
	add_child(castle)
	castle.position = _c2w(home.x, home.y, CLAIMED_LIFT)   # rest on the raised home slab
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
	# Six levels — kingdoms level up gradually over the 5-minute match.
	# Thresholds are tuned so T4 (the iconic castle) arrives at mid-game and
	# T6 (Capital) is only reached by truly dominant kingdoms.
	if n < 200:   return 1   # Watchtower
	elif n < 500:  return 2   # Twin Towers
	elif n < 1000: return 3   # Keep
	elif n < 1800: return 4   # Castle
	elif n < 2800: return 5   # Fortress
	return 6                  # Capital

# Per-tier half-span: outer edge of the castle model in Godot world units.
# A conqueror must own every cell within this radius before the castle can fall.
const CASTLE_HALF_SPANS := [0.44, 1.09, 1.38, 1.62, 1.88, 2.21]
func _castle_radius(tier: int) -> int:
	var span: float = CASTLE_HALF_SPANS[clampi(tier - 1, 0, CASTLE_HALF_SPANS.size() - 1)]
	return int(ceil(span / CELL))

# Render the 3D board at a fraction of the screen resolution on phones and upscale
# it — the blocky toybox art still reads cleanly while we reclaim a lot of fragment
# load (the per-cell ground shader is fill-rate heavy). The 2D HUD/minimap is drawn
# by CanvasLayers, so it stays at full crispness. Desktop renders at native scale;
# set TBK_LOWRES=<0..1> to preview the mobile path on desktop.
const MOBILE_RENDER_SCALE := 0.75
# NOTE: we deliberately do NOT downscale 3D on web desktop. On gl_compatibility
# (WebGL2), enabling viewport 3D resolution scaling forces an offscreen render
# target + upscale blit, whose extra full-screen pass costs more than the pixels
# it saves — it measured as a net FPS regression. Native full-res is faster there.
# (TBK_LOWRES below still forces a scale for explicit testing if ever needed.)

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
	_elapsed += delta
	_fx_cooldown = maxf(0.0, _fx_cooldown - delta)

	# 1. drive AI movement (humans move themselves in Avatar3D._physics_process)
	# The AI brain (pathfinding/territory eval) is the heaviest per-frame CPU cost, so
	# it's throttled to ~15Hz and staggered across rulers — the avatar still moves every
	# frame on the last decided heading, so motion stays smooth. (mobile CPU safeguard)
	_frame += 1
	for a in _rulers:
		if a.is_ai and a.alive:
			if (_frame + a.kid) % _ai_decide_every == 0:
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
		# Ride on top of the raised plateau on claimed land (feet + ring otherwise sink in).
		var ground_y := CLAIMED_LIFT if grid.get_owner(c.x, c.y) != 0 else 0.0
		a.avatar.global_position.y = lerpf(a.avatar.global_position.y, ground_y,
			clampf(delta * GROUND_LERP, 0.0, 1.0))
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
		if _slabs:
			_slabs.rebuild()   # raised colour cutouts catch up with the new ownership
		_minimap_pending = true     # board changed → queue an aerial refresh
		grid.reset_dirty()
		_terr_rebuild_t = 0.1
	# The minimap is a full SECOND scene render, so cap it to ~3/s and always render
	# the latest state — far cheaper than firing it on every 10Hz territory tick.
	if _minimap_pending and _minimap_t <= 0.0:
		_minimap.request_render()
		_minimap_pending = false
		_minimap_t = 0.5 if DeviceMode.low_gfx else 0.33
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
	_kingdom_t = 0.6 if DeviceMode.low_gfx else 0.4
	# Populace + flags are full-board scans. Skip them when no land changed since the
	# last build, and alternate them across ticks so only one runs per 0.4s spike.
	var v: int = grid.version
	# Rotate the three full-board scans (town / flags / countryside) across ticks so
	# only one spikes per 0.4s; each skips if no land changed since it last ran.
	if _decor_phase == 0:
		if v != _last_pop_version:
			_populace.rebuild(_kid_tier)
			_last_pop_version = v
		_decor_phase = 1
	else:
		if v != _last_decor_version:
			_decor.rebuild(_kid_tier)
			_last_decor_version = v
		_decor_phase = 0
	_windmills.rebuild(_kid_tier)
	# Roads: rebuild every ~10 kingdom ticks (~4 s desktop, ~6 s mobile) when territory
	# changed. Each kingdom's rebuild() does its own delta-skip so it's cheap when nothing moved.
	_road_tick += 1
	var _road_interval := 8 if DeviceMode.low_gfx else 6
	if _road_tick >= _road_interval and grid.version != _last_road_version:
		_last_road_version = grid.version
		_road_tick = 0
		for a in _rulers:
			if not a.eliminated:
				_roads.rebuild(a.kid, _kid_tier.get(a.kid, 1), grid.territory_count(a.kid))
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
		if _kid_tier.get(a.kid, 0) != new_tier:
			_kid_tier[a.kid] = new_tier
			# A tier change unlocks/thickens decoration — force the throttled scans to
			# re-run next tick even if no further land changes (crossing a threshold
			# itself changed the version, but the rebuild this tick used the OLD tier).
			_last_pop_version = -1
			_last_decor_version = -1
			_road_tick = 999   # force road rebuild on next _kingdom_tick (tier unlocks new roads)
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
	if conq == _rulers[0]:
		_rivals_conquered += 1          # endless score input
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
		_end_match(true, "conquest")               # win: last kingdom standing → next island
	elif _match_t <= 0.0 and _mode in ["campaign", "daily"]:
		# Only the timed modes end on the clock (hold >=50% to win). The endless island
		# chain is UNTIMED — it ends only by conquest (advance) or elimination (run over).
		_end_match(human_pct >= WIN_PCT, "timeout")

func _human_rank() -> int:
	var mine: int = grid.territory_count(_rulers[0].kid)
	var rank := 1
	for a in _rulers:
		if a == _rulers[0]:
			continue
		if grid.territory_count(a.kid) > mine:
			rank += 1
	return rank

# Rival line-up for an endless island: the fleet GROWS (3 → 7) and gets BOLDER the
# deeper the run goes, so each island is a step harder than the last.
func _endless_rivals_for(island: int) -> Array:
	var count := clampi(3 + island / 2, 3, 7)
	var floor_diff := clampi(island / 2, 0, 2)        # difficulty floor rises every 2 islands
	var diffs: Array = []
	for i in count:
		# a few rivals run one notch hotter than the floor for variety
		var d := floor_diff + (1 if (floor_diff < 2 and i % 3 == 0) else 0)
		diffs.append(clampi(d, 0, 2))
	return diffs

# One island's score: peak land held dominates, each conquered rival is a big bonus,
# clearing pays a bonus that grows with how deep you are.
func _compute_endless_score(cleared: bool) -> int:
	var clear_bonus := (1000 + _endless_island * 500) if cleared else 0
	return int(round(_peak_pct * 100.0)) * 50 + _rivals_conquered * 500 + clear_bonus

# ── match end + results ───────────────────────────────────────────────────────
func _end_match(win: bool, reason: String) -> void:
	if _ended:
		return
	_ended = true
	if _rulers[0].avatar:
		_rulers[0].avatar.auto_input = false   # freeze the human (AI halts via the early return)
	var pct: float = float(grid.territory_count(_rulers[0].kid)) / float(GW * GH)
	_peak_pct = maxf(_peak_pct, pct)
	var rank := _human_rank()
	var coins: int = int(pct * 300.0) + maxi(0, _n_kingdoms - rank) * 15 + (60 if win else 0)
	Analytics.match_end(win, reason, rank, pct, _elapsed, coins)
	if _mode == "daily":
		# Score the daily like one island; record it (first completion pays the streak
		# reward), pay score coins, then show the daily results. No island chaining.
		_endless_score = _compute_endless_score(win)
		var dres := SaveManager.complete_daily(_endless_score)
		_endless_is_best = dres["is_best"]
		_daily_first = dres["first"]
		_daily_streak = dres["streak"]
		_daily_reward = dres["reward"]
		SaveManager.add_coins(_endless_score / 20)
		AudioManager.play("round_win" if win else "eliminate")
		Analytics.event("daily_end", {
			"score": _endless_score, "win": win, "first": _daily_first,
			"streak": _daily_streak, "reward": _daily_reward, "is_best": _endless_is_best,
		})
		if win and _rulers[0].castles.size() > 0 and is_instance_valid(camera):
			var cap: Vector2i = _rulers[0].castles[0]["cell"]
			var f := _c2w(cap.x, cap.y, 0.0)
			camera.start_victory_orbit(f)
			_victory_fireworks(f, _kid_color[_rulers[0].kid])
			await get_tree().create_timer(2.0).timeout
			if not is_inside_tree():
				return
		_show_results(win, reason, rank, pct, _endless_score / 20 + _daily_reward)
		return
	if _mode in ["endless", "timed"]:
		# win == this island was CLEARED. Bank it; clearing advances to the next island.
		var island_score := _compute_endless_score(win)
		SaveManager.endless_run_bank(island_score, win)
		Analytics.event("endless_island", {
			"island": _endless_island, "cleared": win, "island_score": island_score,
			"run_score": SaveManager.endless_run_score(),
			"peak_pct": snappedf(_peak_pct, 0.001), "rivals": _rivals_conquered,
		})
		if win:
			# Cleared → pay coins for it, celebrate, fly to the next (harder) island.
			SaveManager.add_coins(island_score / 20)
			AudioManager.play("round_win")
			_endless_clear_transition()
			return
		# Run over → total it, bank the best, pay coins, show the final results.
		_endless_score = SaveManager.endless_run_score()
		_endless_is_best = SaveManager.record_endless(_endless_score)
		SaveManager.add_coins(_endless_score / 20)
		AudioManager.play("eliminate")
		Analytics.event("endless_end", {
			"score": _endless_score, "best": SaveManager.endless_best(),
			"is_best": _endless_is_best, "islands": _endless_island,
		})
		_show_results(false, reason, rank, pct, _endless_score / 20)
		SaveManager.endless_run_reset()
		return
	else:
		Analytics.progression("complete" if win else "fail", "stage_%d" % _stage, {"pct": snappedf(pct, 0.001)})
		# Advance the campaign ladder on a win (only the frontier stage unlocks new ground).
		if win:
			if SaveManager.clear_stage(_stage):
				if SaveManager.campaign_complete():
					_stage_msg = "Campaign complete!  You rule the toybox 👑"
				else:
					_stage_msg = "Stage cleared!  Next: %s" % Campaign.title(SaveManager.active_stage())
			else:
				_stage_msg = "Stage replayed  ·  %s" % Campaign.title(_stage)
	SaveManager.add_coins(coins)
	AudioManager.play("round_win" if win else "eliminate")
	if _dbg:
		print("[end] win=%s reason=%s rank=%d pct=%.1f coins=%d" % [win, reason, rank, pct * 100.0, coins])
	# On a win, play a cinematic victory orbit + fireworks over the capital before the
	# results panel slides in — the App Store money-shot. (Defeat shows results at once.)
	if win and _rulers[0].castles.size() > 0 and is_instance_valid(camera):
		var cap_cell: Vector2i = _rulers[0].castles[0]["cell"]
		var focus := _c2w(cap_cell.x, cap_cell.y, 0.0)
		camera.start_victory_orbit(focus)
		_victory_fireworks(focus, _kid_color[_rulers[0].kid])
		await get_tree().create_timer(2.6).timeout
		if not is_inside_tree():
			return
	_show_results(win, reason, rank, pct, coins)

# Island cleared in an endless run: a quick celebratory orbit, then a "sailing to the
# next island" card wipes the screen and we reload — _ready reads the advanced island
# index, builds the next island, and fades IN from the same cover (see _endless_intro).
func _endless_clear_transition() -> void:
	# Camera rises up and away from the cleared island (with a fireworks send-off),
	# then the navy card wipes in over the receding board and we reload.
	if is_instance_valid(camera):
		camera.pull_out(1.3)
	if _rulers[0].castles.size() > 0:
		var cap_cell: Vector2i = _rulers[0].castles[0]["cell"]
		_victory_fireworks(_c2w(cap_cell.x, cap_cell.y, 0.0), _kid_color[_rulers[0].kid])

	# Build the transition card over a high layer (above all HUD), starting transparent.
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 0.0
	layer.add_child(root)
	var cover := ColorRect.new()
	cover.color = Color(0.05, 0.07, 0.13, 1.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cover)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	_result_label(box, "ISLAND %d CLEARED!" % (_endless_island + 1), 56, Palette.SAFE)
	_result_label(box, "⛵  Sailing to Island %d" % (_endless_island + 2), 30, Color.WHITE)
	_result_label(box, "Score  %s" % _comma(SaveManager.endless_run_score()), 30, Palette.WARN)

	# Let the pull-out read for a beat, then wipe the card in over the receding board.
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	get_tree().reload_current_scene()

# Fade the next island IN from the same deep cover the clear wipe ended on, so the jump
# between islands reads as one continuous move instead of a hard cut.
func _endless_intro() -> void:
	# Camera descends from high above onto the new island as the cover lifts.
	if is_instance_valid(camera):
		camera.descend(1.3)
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	var cover := ColorRect.new()
	cover.color = Color(0.05, 0.07, 0.13, 1.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	var tw := cover.create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(cover, "color:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)

# A few staggered firework bursts over the capital during the victory orbit.
func _victory_fireworks(focus: Vector3, color: Color) -> void:
	if _fx == null:
		return
	for i in 5:
		if not is_instance_valid(_fx):
			return
		var jitter := Vector3(randf_range(-4.0, 4.0), randf_range(0.0, 3.0), randf_range(-4.0, 4.0))
		_fx.fireworks(focus + jitter, color)
		AudioManager.play("round_win", randf_range(0.9, 1.2))
		await get_tree().create_timer(0.5).timeout

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

	# Run modes: the score chase is the headline. Big score, best/NEW BEST, islands cleared.
	if _mode in ["endless", "timed"]:
		_result_label(vb, "SCORE  %s" % _comma(_endless_score), 46, Palette.WARN)
		if _endless_is_best:
			_result_label(vb, "★  NEW BEST!  ★", 28, Palette.SAFE)
		else:
			_result_label(vb, "Best  %s" % _comma(SaveManager.endless_best()), 22, Color(1, 1, 1, 0.85))
		_result_label(vb, "Islands cleared:  %d" % _endless_island, 22, HUD_DIM)

	# Daily challenge: score + streak; the day's reward (first completion only).
	elif _mode == "daily":
		_result_label(vb, "DAILY  ·  SCORE  %s" % _comma(_endless_score), 42, Palette.WARN)
		_result_label(vb, "STREAK  ·  %d DAY%s" % [_daily_streak, "" if _daily_streak == 1 else "S"], 26, Palette.SAFE)
		if _daily_first:
			_result_label(vb, "Daily reward  +%d coins" % _daily_reward, 24, HUD_GOLD)
		else:
			_result_label(vb, "Already claimed today — best %s" % _comma(SaveManager.daily_best()), 22, HUD_DIM)

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

# 12345 -> "12,345" (thousands separators for the endless score readout).
func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

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
				# Time-to-first-claim is the #1 onboarding/D1 signal — log it once per match.
				if not _first_capture_logged:
					_first_capture_logged = true
					Analytics.first_capture(_elapsed)
					_dismiss_coach()
				AudioManager.play("collect", clampf(1.0 + float(cap) / 1500.0, 1.0, 1.45))
				camera.punch_zoom(clampf(0.02 + float(cap) / 9000.0, 0.02, 0.06))
				if cap > 350:
					camera.shake(0.12)
				# Confetti + coins erupt where the land was claimed (rate-limited so a
				# burst of small captures doesn't spawn a particle storm).
				if _fx_cooldown <= 0.0 and cap >= 12:
					_fx_cooldown = 0.18
					var cmn: Vector2i = res.get("cmin", Vector2i(0, 0))
					var cmx: Vector2i = res.get("cmax", Vector2i(-1, 0))
					var ctr := Vector2i((cmn.x + cmx.x) / 2, (cmn.y + cmx.y) / 2)
					_fx.burst(_c2w(ctr.x, ctr.y, 0.0), _kid_color[a.kid])
					_pop_coins_chip()

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
# Quick scale-pop on the coins chip so the HUD reacts when you earn land.
func _pop_coins_chip() -> void:
	if _coins_chip == null or not is_instance_valid(_coins_chip):
		return
	_coins_chip.scale = Vector2(1.18, 1.18)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_coins_chip, "scale", Vector2.ONE, 0.22)

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

# Assign every kingdom's colour AND its display name together. The HUMAN (kid 1) wears
# their selected cosmetic king colour — so equipping a skin actually recolours their
# king, ground ring and territory — and is labelled "Your Kingdom". Rivals take the
# hardcoded palette colours MOST distinct from the player's (so nothing clashes), each
# keeping the colour-matched name so "Red Empire" is always actually red, etc.
func _assign_kingdom_colors() -> void:
	var human_col: Color = Cosmetics.king_color(SaveManager.selected_pack())
	_kid_color[1] = human_col
	_kid_label[1] = "Your Kingdom"
	var pairs: Array = []
	for i in KINGDOM_COLORS.size():
		pairs.append({"col": KINGDOM_COLORS[i], "label": KINGDOM_LABELS[i]})
	pairs.sort_custom(func(a, b): return _col_dist(a.col, human_col) > _col_dist(b.col, human_col))
	for i in range(1, _n_kingdoms):          # rivals: i = 1.._n-1 → kid = i + 1
		var p: Dictionary = pairs[(i - 1) % pairs.size()]
		_kid_color[i + 1] = p.col
		_kid_label[i + 1] = p.label

func _col_dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

# ── world dressing ────────────────────────────────────────────────────────────
# Camera framing presets (player setting). "hero" = cinematic 3/4 diorama;
# "map" = steep, near-top-down long lens → the flat paper-map read of simple_target.png.
func _apply_camera_mode(mode: String) -> void:
	if camera == null:
		return
	if mode == "map":
		camera.offset = Vector3(0.0, 24.0, 14.0)   # pitch ≈ 60°
		camera.fov = 32.0                            # long lens flattens perspective
	else:
		camera.offset = Vector3(0.0, 12.6, 15.2)   # cinematic 3/4 diorama framing
		camera.fov = 46.0

func _build_environment() -> void:
	var world := preload("res://toybox_kingdoms/world.tscn").instantiate()
	add_child(world)
	# Lighter render path for web and mobile. SSAO + multi-pass glow are the
	# dominant cost on gl_compatibility (WebGL2) and pin a desktop browser at a
	# few fps, so kill them on ANY web build — not just touch/mobile. Shadows stay
	# full-quality on web desktop (Balanced choice); only mobile trims them.
	if DeviceMode.low_gfx:
		var env := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
		env.glow_enabled = false
		env.ssao_enabled = false
		# Trim the shadow cascade on web + mobile. At the near-top-down camera the
		# extra cascade splits / long distance barely read, so a single tighter
		# split saves a meaningful chunk of the depth pass + shadow sampling.
		var key := world.get_node("KeyLight") as DirectionalLight3D
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		key.directional_shadow_max_distance = 28.0

func _build_ground() -> void:
	# The play board is an ISLAND: everything outside the grid rectangle is open sea.
	# One big animated ocean plane sits just below the board (the island is opaque and
	# drawn on top, so water only shows past the coast). The ground shader's coast rim
	# reads as the sandy beach where land meets the surf.
	var ocean := Ocean.new()
	add_child(ocean)
	ocean.setup(Vector2(GW * CELL * 0.5, GH * CELL * 0.5))

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
	var stat := _hud_panel(Vector2(16, 16), Vector2(194, 112), 14)
	ui.add_child(stat)
	var stat_h := HBoxContainer.new()
	stat_h.add_theme_constant_override("separation", 8)
	stat_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat.add_child(stat_h)
	stat_h.add_child(_accent_bar(kc))
	var stat_v := VBoxContainer.new()
	stat_v.add_theme_constant_override("separation", 3)
	stat_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_h.add_child(stat_v)
	stat_v.add_child(_hud_text(_display_kingdom_name(_rulers[0].kid).to_upper(), 14, kc.lightened(0.35)))
	_terr_label = _hud_text("0.0%", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	stat_v.add_child(_terr_label)
	stat_v.add_child(_thin_rule())
	var pr := _stat_row("people", HUD_BLUE, "Population")
	stat_v.add_child(pr["row"]); _pop_label = pr["value"]
	var ir := _stat_row("coin", HUD_GOLD, "Coins / min")
	stat_v.add_child(ir["row"]); _income_label = ir["value"]

	# ── top-centre: match countdown (campaign) / island indicator (endless) ──
	# Endless has no doom-clock — only death ends the run — so the centre pill shows
	# which island you're on instead of a countdown.
	_timer_panel = _hud_panel(Vector2(Palette.CENTER_X - 84, 14), Vector2(168, 52), 16)
	ui.add_child(_timer_panel)
	var th := _pill_row(_timer_panel)
	th.add_theme_constant_override("separation", 8)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	var is_chain := _mode in ["endless", "timed"]
	th.add_child(_glyph(GlyphIcon.new().setup("map" if is_chain else "clock", HUD_GOLD, 22)))
	var init_t := ("ISLAND %d" % (_endless_island + 1)) if is_chain else "0:00"
	_time_label = _hud_text(init_t, 26 if is_chain else 30, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	th.add_child(_time_label)

	# Campaign: a small stage chip under the clock so the player always knows which
	# stage of the ladder they're on (the campaign was otherwise invisible in-match).
	if _mode == "campaign":
		var stage_chip := _hud_panel(Vector2(Palette.CENTER_X - 150, 70), Vector2(300, 32), 12)
		ui.add_child(stage_chip)
		var sr := _pill_row(stage_chip); sr.alignment = BoxContainer.ALIGNMENT_CENTER
		sr.add_child(_hud_text("STAGE %d/%d  ·  %s" % [_stage + 1, Campaign.count(), Campaign.title(_stage)],
			16, HUD_GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	# ── top-right: coins + population pills, then settings ──
	var coins := _hud_panel(Vector2(Palette.DESIGN_W - 374, 16), Vector2(158, 48), 14)
	ui.add_child(coins)
	_coins_chip = coins
	coins.pivot_offset = Vector2(79, 24)   # centre pivot so the earn-pop scales nicely
	var ch := _pill_row(coins); ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(_glyph(GlyphIcon.new().setup("coin", HUD_GOLD, 24)))
	_coins_label = _hud_text("0", 22, HUD_GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	ch.add_child(_coins_label)

	var pop := _hud_panel(Vector2(Palette.DESIGN_W - 204, 16), Vector2(132, 48), 14)
	ui.add_child(pop)
	var ph := _pill_row(pop); ph.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_child(_glyph(GlyphIcon.new().setup("people", HUD_BLUE, 24)))
	_pop_pill_label = _hud_text("0", 22, HUD_BLUE, HORIZONTAL_ALIGNMENT_LEFT, true)
	ph.add_child(_pop_pill_label)

	var gear := Button.new()
	gear.text = "SET"
	gear.position = Vector2(Palette.DESIGN_W - 60, 16)
	gear.size = Vector2(44, 48)
	gear.custom_minimum_size = Vector2(44, 48)
	gear.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(gear, HUD_INK_HI, 16)
	_hover_lift(gear)
	ui.add_child(gear)

	# ── right: live leaderboard ──
	var lb := _hud_panel(Vector2(Palette.DESIGN_W - 200, 78), Vector2(184, 286), 14)
	ui.add_child(lb)
	var lb_v := VBoxContainer.new()
	lb_v.add_theme_constant_override("separation", 3)
	lb_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_child(lb_v)
	var lb_title := _hud_text("LEADERBOARD", 16, HUD_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	lb_title.add_theme_constant_override("outline_size", 4)
	lb_v.add_child(lb_title)
	lb_v.add_child(_thin_rule())
	for i in _n_kingdoms:
		var rr := _make_lb_row()
		lb_v.add_child(rr["row"])
		_lb_rows.append(rr)

	# First-ever match is pure carve-and-claim: defer the build economy (toolbar + boost/
	# shield action stack) so the player learns the core loop before the systems land.
	if not _is_first_match:
		_build_action_stack(ui)
		_build_toolbar(ui)
	else:
		_build_first_match_coach(ui)

	# Minimap paints from grid data (no 3D render) — no environment needed.
	_minimap = Minimap.new()
	_minimap.setup(GW, GH)
	_minimap.position = Vector2(Palette.DESIGN_W - 286, Palette.DESIGN_H - 202)
	ui.add_child(_minimap)

# First-match coach: one friendly, pulsing banner just above the controls that teaches
# the core loop in two beats — "draw a loop" then "return home". Dismissed the instant
# the player closes their first loop (see _dismiss_coach in the capture path).
func _build_first_match_coach(ui: CanvasLayer) -> void:
	var panel := _hud_panel(Vector2(Palette.CENTER_X - 230, Palette.DESIGN_H - 150), Vector2(460, 60), 18)
	panel.pivot_offset = Vector2(230, 30)
	ui.add_child(panel)
	var row := _pill_row(panel)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_glyph(GlyphIcon.new().setup("boost", HUD_GOLD, 24)))
	_coach_label = _hud_text("Leave your land — draw a loop!", 24, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	row.add_child(_coach_label)
	_coach = panel
	# gentle attention pulse
	var tw := panel.create_tween().set_loops()
	tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

# Fade the coach out once it has done its job (first claim closed).
func _dismiss_coach() -> void:
	if _coach == null or not is_instance_valid(_coach):
		return
	var c := _coach
	_coach = null
	_coach_label = null
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(c, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(c.queue_free)

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
	p.custom_minimum_size = Vector2(5, 0)
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
	row.add_child(_glyph(GlyphIcon.new().setup(glyph, color, 14)))
	var cap := _hud_text(caption, 14, HUD_DIM)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap)
	var value := _hud_text("0", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
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
	st.set_content_margin_all(11)
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
	wrap.custom_minimum_size = Vector2(158, 27)
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
	var rank := _hud_text("", 16, Color(1, 1, 1, 0.55))
	rank.custom_minimum_size = Vector2(18, 0)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dst := StyleBoxFlat.new()
	dst.bg_color = Color.GRAY
	dst.set_corner_radius_all(7)
	dst.border_color = Color(0, 0, 0, 0.45)
	dst.set_border_width_all(1)
	dot.add_theme_stylebox_override("panel", dst)
	var nm := _hud_text("", 16, Color.WHITE)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pct := _hud_text("", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(44, 0)
	row.add_child(rank)
	row.add_child(dot)
	row.add_child(nm)
	row.add_child(pct)
	return {"row": wrap, "bg": bg, "rank": rank, "chip": dst, "name": nm, "pct": pct}

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
		{"text": "BOOST", "glyph": "boost", "cost": 80, "y": 400, "color": Color("123c70")},
		{"text": "SHIELD", "glyph": "shield", "cost": 120, "y": 480, "color": Color("174d7a")},
		{"text": "MAP", "glyph": "map", "cost": 0, "y": 560, "color": Color("17191f")},
	]
	for a in actions:
		var b := Button.new()
		b.position = Vector2(20, int(a["y"]))
		b.custom_minimum_size = Vector2(72, 68)
		b.size = Vector2(72, 68)
		_style_button(b, a["color"], 14)
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon: Control = GlyphIcon.new().setup(a["glyph"], Color.WHITE, 28)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(icon)
		vb.add_child(_hud_text(a["text"], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		if int(a["cost"]) > 0:
			vb.add_child(_hud_text(str(a["cost"]), 12, HUD_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(vb)
		_hover_lift(b)
		ui.add_child(b)

func _build_toolbar(ui: CanvasLayer) -> void:
	var hb := HBoxContainer.new()
	hb.position = Vector2(Palette.CENTER_X - 223, Palette.DESIGN_H - 102)
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
	b.custom_minimum_size = Vector2(104, 88)
	_style_button(b, Color("141b24"), 14)
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
	var icon: Control = GlyphIcon.new().setup(kind, Color.WHITE, 36)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(icon)
	vb.add_child(_hud_text(label, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
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
	var c: Control = GlyphIcon.new().setup("coin", HUD_GOLD, 17)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(c)
	var l := _hud_text(str(cost), 14, HUD_GOLD)
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
		Analytics.event("building_denied", {"kind": kind, "cost": cost, "coins": _coins})
		return
	_coins -= cost
	Analytics.building_bought(kind, cost)
	# Every building boosts YOUR own conquest — the economy fuels expansion instead of
	# sitting on the side. The toast names the effect so the payoff is legible.
	var fx := ""
	match kind:
		"castle":
			_castle_floor = mini(_castle_floor + 1, 6)
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
	# Colour-matched names assigned in _assign_kingdom_colors ("Your Kingdom" for the human).
	return _kid_label.get(kid, KINGDOM_LABELS[(kid - 1) % KINGDOM_LABELS.size()])

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
	# Skip while an island-transition camera move owns the zoom.
	if not camera.intro_active():
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

	# First-match coach swaps its message once the player is out drawing a trail.
	if _coach_label != null and is_instance_valid(_coach_label):
		_coach_label.text = ("Now loop back home to claim it!"
			if grid.trail_length(_rulers[0].kid) > 0
			else "Leave your land — draw a loop!")

	var total := float(GW * GH)
	var pct := 100.0 * owned / total
	_peak_pct = maxf(_peak_pct, float(owned) / total)   # endless score input
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

	# Endless island chain (endless/timed) is UNTIMED: the centre pill shows the island,
	# not a countdown. Only campaign/daily show the clock.
	if _mode in ["endless", "timed"]:
		_time_label.text = "ISLAND %d" % (_endless_island + 1)
	else:
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
