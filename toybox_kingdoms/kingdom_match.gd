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
const CountryMasks := preload("res://toybox_kingdoms/data/country_masks.gd")
const TerritorySlabs := preload("res://toybox_kingdoms/grid/territory_slabs.gd")
const Flags := preload("res://toybox_kingdoms/kingdom/flags.gd")
const Windmills := preload("res://toybox_kingdoms/kingdom/windmills.gd")
const Decor := preload("res://toybox_kingdoms/kingdom/decorations.gd")
const CaptureFX := preload("res://toybox_kingdoms/fx/capture_fx.gd")
const Ocean := preload("res://toybox_kingdoms/env/ocean.gd")
const Roads := preload("res://toybox_kingdoms/kingdom/roads.gd")

# Results-screen art. VictoryDefeat.png holds both headline banners; DefeatMenu.png
# carries the sad crying-king mascot we show on a loss. Regions are pixel rects into
# those source sheets (see _banner_tex / _sad_king_tex).
const TEX_BANNERS := preload("res://assets/VictoryDefeat.png")
const TEX_DEFEAT_MENU := preload("res://assets/DefeatMenu.png")
const BANNER_VICTORY_RECT := Rect2(185, 72, 1180, 290)
const BANNER_DEFEAT_RECT := Rect2(244, 472, 1055, 336)
const SAD_KING_RECT := Rect2(610, 365, 390, 280)
# CTA buttons reuse the kit's stone bar (9-slice) with coloured corner caps — green for
# the primary PLAY AGAIN, blue for MAIN MENU — so they match the framed HUD/dialog
# instead of the old glossy candy pills. See _sprite_button.
const BTN_FRAME_GREEN := preload("res://assets/btn_green.png")
const BTN_FRAME_BLUE  := preload("res://assets/btn_blue.png")

const GW_FULL := 384
const GH_FULL := 288
var GW: int = GW_FULL  # actual grid width — overridden to GW_FULL/3=128 for campaign
var GH: int = GH_FULL  # actual grid height — overridden to GH_FULL/3=96 for campaign
const CELL := 0.6   # 384×288 grid at 0.6 wu/cell → world 230×172 wu, each island 3× bigger
const HOME_R := 15  # cells; home blob ≈ 9 wu radius, same proportion of the 3× island
const N_KINGDOMS := 8           # 1 human + 7 AI
const HUMAN_INPUT_ID := 0
const HUMAN_SPEED := 6.7          # human's base carve speed — tuned to local feel. Cells render the
								 # same on-screen size and the follow-cam shows the same local view, so
								 # the speed matches the original good feel (3× was too fast locally).
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
# clock unless you wipe everyone out. At timeout you WIN if you hold the most land.

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

# ── World Conquest mode ────────────────────────────────────────────────────
# When true: endless chain is replaced by 20 countries; each island uses a
# country-shaped land mask instead of the rectangular frozen-zone.
# When false: original rectangular frozen-zone progression is used.
const WORLD_CONQUEST := true

var _active_w: int = GW_FULL   # playable width in cells; cells outside this = frozen zone
var _active_h: int = GH_FULL   # playable height in cells
var _land_mask: PackedByteArray   # WORLD_CONQUEST: 1=land 0=ocean per cell
var _land_bbox := {"x0": 0, "y0": 0, "x1": GW - 1, "y1": GH - 1}  # bbox of land cells

var grid
var renderer
var camera
var _player                     # human PlayerData

var _rulers: Array = []         # Array[RulerAgent]
var _kid_to_agent := {}
var _kids: Array = []
var _kid_color := {}
var _kid_label := {}
var _kid_avatar := {}       # emoji avatar per kid (shown in leaderboard + join/leave toasts)
var _kid_name := {}
var _kid_tier := {}        # kid -> castle tier (1..4); gates which decorations unlock
var _minimap

var _populace
var _scatter
var _ground
var _ocean
var _sdf_dist: PackedInt32Array    # BFS from land outward → 0=land, N=N cells from land (for ocean clamping)
var _inland_sdf: PackedInt32Array  # BFS from coast inward through land → N=how many cells inland (for home placement)
var _home_cells: Array = []        # pre-computed inland spawn positions (WORLD_CONQUEST)
var _slabs
var _flags
var _windmills
var _decor
var _roads
var _road_tick := 0          # counts _kingdom_tick calls; roads rebuild every N ticks
var _last_road_version := -1
var _last_trail_version := -1
var _decor_cooldown := 0.0   # low_gfx: spaces out the heavy populace/decor full-board scans
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
var _coach_trail_started := false   # true once the player first leaves home territory
var _tutorial_tip_shown := {}       # keys of one-time in-match tips already shown
var _trail_tip_timer := 0.0         # counts up once player first leaves home; triggers trail warning
var _mode := "campaign"         # "campaign" | "endless"
var _endless_island := 0        # which island of the endless run this is (0-based)
# Snapshot of the cleared island's overview frame, handed ACROSS the scene reload to
# the next island (static survives reload) so the two islands can slide past each
# other — old exits left, new enters from right (see _endless_clear_transition/_endless_intro).
static var _clear_frame: Image = null
var _peak_pct := 0.0            # highest land fraction the human held on THIS island
var _rivals_conquered := 0      # rival kingdoms the human eliminated on THIS island
var _endless_score := 0         # final run total (set when the run ends); also the daily score
var _endless_is_best := false
var _daily_streak := 0          # daily-challenge results display
var _daily_reward := 0
var _daily_first := false
# ── lives (endless/timed) ──
# Endless is NOT instant-death: you get LIVES_PER_ISLAND free respawns per island. Each
# pop costs a life and respawns you at your castle. Only when lives run out does the
# rewarded-ad revive offer (then game over) kick in. Refilled on each island + on revive.
const LIVES_PER_ISLAND := 3
var _lives := 0
var _life_dots: Array = []      # HUD heart/dot nodes
# ── continue-on-death (rewarded-ad revive) ──
const MAX_CONTINUES := 2        # ad-revives offered per run before it's truly game over
var _continue_pending := false  # an offer is on screen; the world is frozen
var _continue_resolved := false # the current offer was answered (watch / give up / timeout)
var _continues_used := 0
var _continue_cause := "conquered"  # "popped" | "conquered" — drives the offer/results wording
var _continue_panel: Control
var _pause_panel: Control
var _ui_layer: CanvasLayer
var _toast_queue: Array[Dictionary] = []
var _toast_busy: bool = false

var _terr_label: Label
var _time_label: Label
var _pop_label: Label
var _pop_pill_label: Label
var _income_label: Label
var _lb_rows: Array = []        # Array[Label]
var _lb_notif_box: VBoxContainer = null   # join/leave feed below the leaderboard
var _hud_t := 0.0

# ── in-match economy (the human's kingdom) ───────────────────────────────────
var _coins := 60
var _income := 12.0             # coins per minute (recomputed from land + farms)
var _coin_accum := 0.0
var _farms := 0
var _barracks := 0
var _coins_label: Label
var _coins_chip: Control        # the top-right coins pill (pops when you earn land)
var _fx                         # CaptureFX node (confetti + coin bursts)
var _fx_cooldown := 0.0         # rate-limit player capture bursts
var _timer_panel: PanelContainer
var _last_secs := -1

var _map_btn: Button = null
var _map_active := false        # true while the top-down map view is on

# ── power-ups ─────────────────────────────────────────────────────────────────
const PU_SPEED       := "speed"   # 5 s speed burst to SPEED_CAP
const PU_GHOST       := "ghost"   # 6 s ghost — trail cannot be cut by enemies
const PU_BOMB        := "bomb"    # instant radius-4 land grab
const PU_CLEAR       := "clear"   # instant trail erase — panic button
const PU_FREEZE      := "freeze"  # 5 s — all enemies move at 40% speed
const PU_MAGNET      := "magnet"  # instant radius-6 neutral land pull
const PU_SPEED_DUR   := 5.0
const PU_GHOST_DUR   := 6.0
const PU_FREEZE_DUR  := 5.0
const PU_BOMB_RADIUS   := 4
const PU_MAGNET_RADIUS := 6
const PU_SPAWN_INTERVAL := 25.0   # seconds between spawn waves
const PU_PER_WAVE    := 3         # how many pickups appear per wave
const PU_SPEED_BOOST := 3.5       # extra speed added on top of current avatar speed

# Power-up models preloaded at parse time. Using load() inside _make_pu_node() blocks
# the main thread on the first GLB parse (a few ms) — on a 25s spawn cadence that's
# the "stutters at times" hitch. Preloading moves the cost to startup.
const PU_SCENES := {
	PU_SPEED:  preload("res://assets/powerups/pu_speed.glb"),
	PU_GHOST:  preload("res://assets/powerups/pu_ghost.glb"),
	PU_BOMB:   preload("res://assets/powerups/pu_bomb.glb"),
	PU_CLEAR:  preload("res://assets/powerups/pu_clear.glb"),
	PU_FREEZE: preload("res://assets/powerups/pu_freeze.glb"),
	PU_MAGNET: preload("res://assets/powerups/pu_magnet.glb"),
}

var _powerup_cells  := {}   # Vector2i -> String (type)
var _powerup_nodes  := {}   # Vector2i -> Node3D (the pickup mesh+light)
var _pu_disc_mats   := {}   # type -> StandardMaterial3D (one per type, created once)
var _pu_disc_mesh: CylinderMesh = null   # shared across all discs
var _pu_spawn_t     := 10.0 # countdown to first wave (short delay so match starts clean)
var _freeze_t: float = 0.0  # board-level freeze remaining (seconds)
var _freeze_by: int  = 0    # kid who cast freeze (not affected by the slow)

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
	_make_dbg_overlay()
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
		# only running out of LIVES ends the run. No clock, no timeout.
		_endless_island = SaveManager.endless_island()
		var _env_island := OS.get_environment("TBK_ISLAND")
		if _env_island != "":
			_endless_island = int(_env_island)
		_rival_diffs = _endless_rivals_for(_endless_island)
		if WORLD_CONQUEST:
			# Load the country shape for this island (clamped to 0-19).
			var cidx := clampi(_endless_island, 0, CountryMasks.COUNTRIES.size() - 1)
			var entry: Dictionary = CountryMasks.COUNTRIES[cidx]
			_land_mask = CountryMasks.decode_mask(entry["mask_hex"])
			_land_bbox = CountryMasks.mask_bbox(_land_mask)
			# Active clamping rect = land bbox with 2-cell outset so avatars walk to the shore.
			_active_w = clampi(_land_bbox["x1"] - _land_bbox["x0"] + 4, 10, GW)
			_active_h = clampi(_land_bbox["y1"] - _land_bbox["y0"] + 4, 10, GH)
		else:
			var _dims := _island_dims_for(_endless_island)
			_active_w = _dims.x
			_active_h = _dims.y
		_n_kingdoms = 1 + _rival_diffs.size()
		_lives = LIVES_PER_ISLAND
	else:
		_stage = SaveManager.active_stage()
		_rival_diffs = Campaign.rival_diffs(_stage)
		_n_kingdoms = 1 + _rival_diffs.size()
		if fast == "":
			_match_t = Campaign.duration(_stage)
		GW = GW_FULL / 3   # campaign uses a truly 1/3-size grid (128×96)
		GH = GH_FULL / 3
		_active_w = GW
		_active_h = GH
	# The very first match the player ever starts gets the guided coach + a pure-carve
	# HUD (no build economy yet). Counted once here so a "Play Again" reload is match 2+.
	# TBK_FIRSTMATCH=1 forces the first-match tutorial path for QA without resetting the save.
	# Works for any mode (cold-open now launches endless, not campaign).
	_is_first_match = (SaveManager.stat("matches_played") == 0 \
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
	_ground.set_active_half(Vector2(_active_w * CELL * 0.5, _active_h * CELL * 0.5))
	if WORLD_CONQUEST and _land_mask.size() > 0:
		_ground.set_land_mask(_land_mask)
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
	if WORLD_CONQUEST and _land_mask.size() > 0:
		_scatter.set_land_mask(_land_mask)
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
	_fake_join_intro()

	# Endless: on islands after the first, fade in from the clear-wipe cover so the jump
	# reads as continuous; announce the island either way.
	if _mode in ["endless", "timed"]:
		if _endless_island > 0 and _clear_frame != null:
			# Arrived from an island-CLEAR (the cleared island left us a snapshot): slide the
			# new island in from the right, then zoom in.
			_endless_intro()
		else:
			# Play button / cold boot (first island or a resumed run): no previous island to
			# slide off, so just zoom in — start zoomed-out, name the island, then zoom in.
			_endless_zoom_intro()
	elif _mode == "campaign":
		# Tell the player which stage of the 10-stage campaign they're on.
		_toast("STAGE %d/%d   ·   %s" % [_stage + 1, Campaign.count(), Campaign.title(_stage)], Palette.WARN)

	# First-ever match: a bobbing arrow above the player's castle so they know where home is.
	if _is_first_match:
		_build_castle_indicator(_rulers[0].home, _kid_color[_rulers[0].kid])

func _spawn_kingdom(i: int) -> void:
	var kid: int = i + 1
	var info: Dictionary = Roster.info(i)
	_kid_name[kid] = _kid_label.get(kid, "Player")
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
		av.speed = HUMAN_SPEED + _UpgradesData.speed_bonus_of("speed_boost") * (1.0 if SaveManager.has_upgrade("speed_boost") else 0.0)
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
	tag.text = _kid_label.get(kid, "Player")
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
# NOTE: scaling_3d_scale (viewport 3D resolution scaling) does NOT help on web —
# gl_compatibility still composites the scaled 3D into a full-canvas-res offscreen target
# and blits, so the saving is eaten (measured: ~no change at 0.6). Web instead caps the
# whole frame via content-scale (see below). TBK_LOWRES still forces a 3D scale on native.

# Web renders the canvas at full window size × devicePixelRatio (gl_compatibility), so a
# large or hi-DPI display pushes millions of pixels through the 3D shaders and pins fps —
# it scales ~linearly with window pixels. Cap the WHOLE frame to this internal height and
# upscale once to the window (see _apply_render_scale).
const WEB_RENDER_HEIGHT := 720

func _apply_render_scale() -> void:
	if DeviceMode.is_web:
		# Render EVERYTHING into a fixed viewport (WEB_RENDER_HEIGHT tall) and scale it to
		# the window in one pass (width follows the window aspect, so framing is unchanged).
		# This caps the framebuffer regardless of monitor size / devicePixelRatio — the
		# actual fix for "fps scales with window pixels". The HUD softens on big screens.
		var win := get_window()
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		win.content_scale_size = Vector2i(int(WEB_RENDER_HEIGHT * 16.0 / 9.0), WEB_RENDER_HEIGHT)
		return
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

const _PT_WINDOW := 60
var _pt := {}
var _pt_frame := 0
var _pt_peak := {}      # peak µs seen per key, for spike detection
var _dbg_label: Label   # on-screen timing overlay (null when not shown)
var _last_terr_us := 0  # last [TERR] ground+slabs cost, updated each rebuild
var _last_cap_us  := 0  # last capture cost

func _pt_add(k: String, v: int) -> void:
	_pt[k] = int(_pt.get(k, 0)) + v
	if v > int(_pt_peak.get(k, 0)):
		_pt_peak[k] = v

func _make_dbg_overlay() -> void:
	var cl := CanvasLayer.new(); cl.layer = 128; add_child(cl)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bg.size = Vector2(370, 200)
	bg.position = Vector2(6, 6)
	cl.add_child(bg)
	_dbg_label = Label.new()
	_dbg_label.add_theme_font_size_override("font_size", 13)
	_dbg_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dbg_label.position = Vector2(10, 8)
	_dbg_label.size = Vector2(360, 190)
	cl.add_child(_dbg_label)

func _physics_process(delta: float) -> void:
	if _ended or _continue_pending:
		return    # frozen while a continue offer is on screen
	_match_t = maxf(0.0, _match_t - delta)
	_elapsed += delta
	_fx_cooldown = maxf(0.0, _fx_cooldown - delta)

	var _t0 := Time.get_ticks_usec()

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
			var freeze_mult := 0.4 if (_freeze_t > 0.0 and a.kid != _freeze_by) else 1.0
			a.avatar.velocity = Vector3(dir.x, 0.0, dir.y) * AI_SPEED * freeze_mult
			a.avatar.move_and_slide()
			if dir.length() > 0.1:
				a.avatar.face(dir)

	var _t1 := Time.get_ticks_usec()

	# 2. grid stepping + respawn for every ruler
	for a in _rulers:
		if a.eliminated:
			continue
		if not a.alive:
			a.respawn_t -= delta
			if a.respawn_t <= 0.0:
				_respawn(a)
			continue
		if _clamp(a.avatar, a.is_ai) and a.is_ai:
			# Avatar was pushed out of ocean — stale cached_dir keeps sending it back.
			# Reset the AI plan so it replans inland on the next decide() tick.
			a.cached_dir = Vector2.ZERO
			a.ai.reset()
		var c := _w2c(a.avatar.global_position)
		# Ride on top of the raised plateau on claimed land (feet + ring otherwise sink in).
		var ground_y := CLAIMED_LIFT if grid.get_owner(c.x, c.y) != 0 else 0.0
		a.avatar.global_position.y = lerpf(a.avatar.global_position.y, ground_y,
			clampf(delta * GROUND_LERP, 0.0, 1.0))
		if c != a.last_cell:
			_advance_agent(a, c)

	var _t2 := Time.get_ticks_usec()

	# 3. render + ui
	# Trail cubes are static per cell, so only rebuild the trail MultiMesh when a trail
	# actually changed (extend / capture / death) instead of every frame.
	if grid.trail_version != _last_trail_version:
		_last_trail_version = grid.trail_version
		renderer.update_trails(_kids)

	var _t3 := Time.get_ticks_usec()

	# Throttle full territory rebuilds to <=10/s — mobile safeguard (claims still
	# show instantly via the flash; the slab catches up within 0.1s).
	_terr_rebuild_t -= delta
	_minimap_t -= delta
	if grid.has_dirty() and _terr_rebuild_t <= 0.0:
		var dmin: Vector2i = grid.dirty_min
		var dmax: Vector2i = grid.dirty_max
		var _tg0 := Time.get_ticks_usec(); _ground.update(dmin.x, dmin.y, dmax.x, dmax.y)
		var _ts0 := Time.get_ticks_usec(); if _slabs: _slabs.rebuild()
		var _te0 := Time.get_ticks_usec()
		_last_terr_us = (_te0 - _tg0)
		if _dbg: print("[TERR] ground=%dµs  slabs=%dµs" % [_ts0-_tg0, _te0-_ts0])
		_minimap_pending = true
		grid.reset_dirty()
		_terr_rebuild_t = 0.1
	# The minimap is a full SECOND scene render, so cap it to ~3/s and always render
	# the latest state — far cheaper than firing it on every 10Hz territory tick.
	if _minimap_pending and _minimap_t <= 0.0:
		_minimap.request_render()
		_minimap_pending = false
		_minimap_t = 0.5 if DeviceMode.low_gfx else 0.33

	var _t4 := Time.get_ticks_usec()

	_kingdom_tick(delta)

	var _t5 := Time.get_ticks_usec()

	_tick_powerups(delta)
	_pu_spawn_t -= delta
	if _pu_spawn_t <= 0.0:
		_pu_spawn_t = PU_SPAWN_INTERVAL
		_spawn_powerup_wave()
	_hud_tick(delta)

	var _t6 := Time.get_ticks_usec()
	_pt_add("1_ai_move",   _t1 - _t0)
	_pt_add("2_grid_step", _t2 - _t1)
	_pt_add("3_trails",    _t3 - _t2)
	_pt_add("4_terr",      _t4 - _t3)
	_pt_add("5_kingdom",   _t5 - _t4)
	_pt_add("6_hud_pu",    _t6 - _t5)
	_pt_frame += 1
	if _pt_frame >= _PT_WINDOW:
		var keys := _pt.keys(); keys.sort()
		var out := "[TICK/%d] " % _PT_WINDOW
		for k in keys:
			out += "%s=%dµs  " % [k, _pt[k] / _PT_WINDOW]
		if _dbg: print(out)
		# Update on-screen overlay
		if _dbg_label:
			var total_avg := 0
			for k in _pt: total_avg += _pt[k]
			total_avg /= _PT_WINDOW
			var fps_now := int(1.0 / maxf(get_process_delta_time(), 0.001))
			var txt := "── TICK TIMING (avg/%d frames) ──\n" % _PT_WINDOW
			for k in keys:
				var avg_us: int = _pt[k] / _PT_WINDOW
				var pk: int = int(_pt_peak.get(k, 0))
				txt += "  %s  avg=%dµs  peak=%dµs\n" % [k, avg_us, pk]
			txt += "  TOTAL avg=%dµs\n" % total_avg
			txt += "── SPIKES ──\n"
			txt += "  terr(last)=%dµs\n" % _last_terr_us
			txt += "  capture(last)=%dµs\n" % _last_cap_us
			txt += "  FPS=%d\n" % fps_now
			_dbg_label.text = txt
		_pt_peak.clear()
		_pt.clear(); _pt_frame = 0
	if _fps_label and _fps_label.visible:
		_fps_t -= delta
		if _fps_t <= 0.0:
			_fps_t = 0.25
			_update_fps()
	# "Mind Your Trail" tip: fires 3 s after the player first ventures out.
	if _is_first_match and _coach_trail_started and not _tutorial_tip_shown.has("trail_warning") and not _ended:
		_trail_tip_timer += delta
		if _trail_tip_timer >= 3.0:
			_tutorial_tip_shown["trail_warning"] = true
			_show_tutorial_tip("Mind Your Trail!",
				"Your trail is exposed while you're out.\nA rival can cut it — loop home before they reach you!",
				"res://assets/screenshots/trail.png")
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
	# Rotate the two full-board scans (town / countryside) across ticks so only one spikes
	# per tick; each skips if no land changed since it last ran. On web/mobile (single
	# thread) each scan is a ~tens-of-ms hit, so SPACE THEM OUT: a 100ms stutter every
	# 0.6s reads as jank, but town/citizens popping in ~2s after capture is imperceptible.
	# Desktop keeps them responsive (cooldown 0).
	_decor_cooldown -= delta
	if _decor_cooldown <= 0.0:
		if _decor_phase == 0:
			if v != _last_pop_version:
				var _tp0 := Time.get_ticks_usec(); _populace.rebuild(_kid_tier)
				if _dbg: print("[KT] populace=%dµs" % (Time.get_ticks_usec()-_tp0))
				_last_pop_version = v
			_decor_phase = 1
		else:
			if v != _last_decor_version:
				var _td0 := Time.get_ticks_usec(); _decor.rebuild(_kid_tier)
				if _dbg: print("[KT] decor=%dµs" % (Time.get_ticks_usec()-_td0))
				_last_decor_version = v
			_decor_phase = 0
		_decor_cooldown = 1.2 if DeviceMode.low_gfx else 0.0
	var _tw0 := Time.get_ticks_usec(); _windmills.rebuild(_kid_tier)
	if _dbg: print("[KT] windmills=%dµs" % (Time.get_ticks_usec()-_tw0))
	_road_tick += 1
	var _road_interval := 16 if DeviceMode.low_gfx else 12
	if _road_tick >= _road_interval and grid.version != _last_road_version:
		_last_road_version = grid.version
		_road_tick = 0
		var _tr0 := Time.get_ticks_usec()
		for a in _rulers:
			if not a.eliminated:
				_roads.rebuild(a.kid, _kid_tier.get(a.kid, 1), grid.territory_count(a.kid))
		if _dbg: print("[KT] roads=%dµs" % (Time.get_ticks_usec()-_tr0))
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
		AudioManager.play("eliminate")
	b.eliminated = true
	b.alive = false
	grid.clear_trail(b.kid)
	grid.transfer_all(b.kid, conq.kid)
	if b.avatar:
		b.avatar.visible = false
	if b.name_tag:
		b.name_tag.visible = false
	var em_b: String = _kid_avatar.get(b.kid, "🐱")
	if conq == _rulers[0]:
		_toast("%s  %s was eliminated!" % [em_b, _kid_name[b.kid]], _kid_color[conq.kid])
	elif b == _rulers[0]:
		_toast("%s  %s took your land!" % [_kid_avatar.get(conq.kid, "🐱"), _kid_name[conq.kid]], Palette.DANGER)
	else:
		_lb_notify("%s  %s left the match" % [em_b, _kid_name[b.kid]], Color(_kid_color[b.kid], 0.9))

# Staggered "joined" entries in the leaderboard notification strip at match start.
func _fake_join_intro() -> void:
	for i in range(1, _n_kingdoms):
		var kid := i + 1
		await get_tree().create_timer(0.5 + (i - 1) * 0.5).timeout
		if not is_inside_tree() or _ended:
			return
		var em: String = _kid_avatar.get(kid, "🐱")
		_lb_notify("%s  %s joined" % [em, _kid_name[kid]], _kid_color[kid].lightened(0.2))

# ── continue-on-death (rewarded-ad revive) ────────────────────────────────────
# The human just lost their last castle. Freeze the world and offer a revive: watch a
# rewarded ad to rise again, or give up to the results screen. Auto-declines after a
# few seconds of no answer. TBK_AUTOCONTINUE=1 auto-takes it (headless QA).
func _offer_continue(cause: String = "conquered") -> void:
	_continue_cause = cause
	_continue_pending = true
	_continue_resolved = false
	if _rulers[0].avatar:
		_rulers[0].avatar.auto_input = false
	AudioManager.play("eliminate")
	Analytics.event("continue_offered", {"used": _continues_used, "mode": _mode})
	_build_continue_panel()
	# Hard-pause the whole game while we wait for the revive decision / ad. The panel is
	# PROCESS_MODE_ALWAYS so it stays interactive; create_timer below runs while paused.
	get_tree().paused = true
	if OS.get_environment("TBK_AUTOCONTINUE") == "1":
		await get_tree().create_timer(0.2).timeout
		if not _continue_resolved:
			_take_continue()
		return
	await get_tree().create_timer(6.0).timeout
	if not _continue_resolved and is_inside_tree():
		_decline_continue()

func _take_continue() -> void:
	if _continue_resolved:
		return
	_continue_resolved = true
	# Show a rewarded ad; revive on reward, and always handle close so a no-reward dismiss
	# still un-pauses (otherwise the paused game would freeze).
	MonetizationManager.show_rewarded(_on_continue_reward, "revive", _on_continue_ad_closed)

func _on_continue_reward() -> void:
	get_tree().paused = false
	_continue_pending = false
	_continues_used += 1
	Analytics.event("continue_taken", {"n": _continues_used, "mode": _mode})
	_close_continue_panel()
	_revive_human()

# Rewarded ad closed. If it wasn't earned (dismissed early), resume and end the run.
func _on_continue_ad_closed(earned: bool) -> void:
	if earned:
		return   # _on_continue_reward already handled the revive
	get_tree().paused = false
	_continue_pending = false
	_close_continue_panel()
	_end_match(false, "conquered")

func _decline_continue() -> void:
	if _continue_resolved:
		return
	_continue_resolved = true
	get_tree().paused = false
	Analytics.event("continue_declined", {"used": _continues_used, "mode": _mode})
	_close_continue_panel()
	_continue_pending = false
	_end_match(false, "conquered")

# Rise again. Two cases:
#  • POPPED but kingdom intact (still has castles) → just respawn at a castle, keep
#    everything (the common single-life case).
#  • ELIMINATED (keep conquered) → RECLAIM your keep at home: take the castle back
#    (same node, your colour) and re-seed its region, so the castle is back where it was.
# Score/run is preserved either way.
func _revive_human() -> void:
	var human = _rulers[0]
	human.eliminated = false
	human.alive = true
	var spawn: Vector2i
	if human.castles.is_empty():
		var cell: Vector2i = human.home
		cell.x = clampi(cell.x, HOME_R, GW - 1 - HOME_R)
		cell.y = clampi(cell.y, HOME_R, GH - 1 - HOME_R)
		# Find the conqueror's keep sitting on our home cell and detach it from them.
		var reclaimed = null
		for a in _rulers:
			if a == human:
				continue
			for c in a.castles:
				if c["cell"] == cell:
					reclaimed = c
					a.castles.erase(c)
					break
			if reclaimed != null:
				break
		var castle
		if reclaimed != null and reclaimed["node"] != null:
			castle = reclaimed["node"]      # same keep, given back to you
			castle.set_color(_kid_color[human.kid])
			castle._pop()
		else:
			castle = Castle.new()
			add_child(castle)
			castle.position = _c2w(cell.x, cell.y, CLAIMED_LIFT)
			castle.set_color(_kid_color[human.kid])
		grid.seed_kingdom(human.kid, cell.x, cell.y, HOME_R)
		castle.update_tier(_castle_tier(grid.territory_count(human.kid)))
		human.home = cell
		human.castle = castle
		human.castles = [{"cell": cell, "node": castle}]
		if human.name_tag:
			human.name_tag.visible = true
			human.name_tag.position = _c2w(cell.x, cell.y, 0.0) + Vector3(0, 4.4, 0)
		spawn = Vector2i(mini(cell.x + 4, GW - 1), cell.y)
	else:
		# Popped: kingdom intact — respawn at the nearest castle.
		spawn = human.castles[0]["cell"]
	human.avatar.visible = true
	human.avatar.revive(_c2w(spawn.x, spawn.y, 0.0))
	human.avatar.set_body_scale(KING_SCALE)
	human.avatar.collision_layer = 0
	human.avatar.collision_mask = 0
	human.avatar.auto_input = true
	human.last_cell = spawn
	_lives = LIVES_PER_ISLAND          # the ad-revive grants a fresh set of lives
	_update_lives_hud()
	_ring(_c2w(spawn.x, spawn.y, 0.0), _kid_color[human.kid])
	if is_instance_valid(camera):
		camera.shake(0.2)
	AudioManager.play("round_win")
	_toast("Long live the King!", _kid_color[human.kid])

func _build_continue_panel() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.09, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS   # stay interactive + animate while the game is paused
	_ui_layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.66, 0.25)
	_continue_panel = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	# Same painted stone frame as the results dialog + HUD pills, so the revive prompt
	# reads as one kit instead of a flat bordered rect.
	var panel := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = PANEL_FRAME
	st.texture_margin_left = 20
	st.texture_margin_right = 20
	st.texture_margin_top = 20
	st.texture_margin_bottom = 20
	st.set_content_margin(SIDE_LEFT, 34)
	st.set_content_margin(SIDE_RIGHT, 34)
	st.set_content_margin(SIDE_TOP, 28)
	st.set_content_margin(SIDE_BOTTOM, 28)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := "TRAIL CUT!" if _continue_cause == "popped" else "CONQUERED!"
	var why := ("A rival crossed your trail — out of lives!" if _continue_cause == "popped"
		else "Your last castle was taken!")
	_result_label(vb, title, 56, Palette.DANGER)
	_result_label(vb, why, 22, Palette.WARN.lightened(0.1))
	_result_label(vb, "Watch an ad to rise again and continue your run.", 24, Color.WHITE)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 8); vb.add_child(sp)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	vb.add_child(btns)
	# Green = take the revive (primary), blue = give up — matches the results-screen CTAs.
	var watch := _sprite_button("▶  CONTINUE  (Ad)", BTN_FRAME_GREEN)
	watch.pressed.connect(_take_continue)
	btns.add_child(watch)
	var giveup := _sprite_button("GIVE UP", BTN_FRAME_BLUE)
	giveup.pressed.connect(_decline_continue)
	btns.add_child(giveup)

func _close_continue_panel() -> void:
	if _continue_panel and is_instance_valid(_continue_panel):
		_continue_panel.queue_free()
	_continue_panel = null

func _show_pause_panel() -> void:
	if _pause_panel and is_instance_valid(_pause_panel):
		return
	AudioManager.play("tap")
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.09, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.66, 0.2)
	_pause_panel = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = PANEL_FRAME
	st.texture_margin_left = 20; st.texture_margin_right = 20
	st.texture_margin_top = 20;  st.texture_margin_bottom = 20
	st.set_content_margin(SIDE_LEFT, 34)
	st.set_content_margin(SIDE_RIGHT, 34)
	st.set_content_margin(SIDE_TOP, 28)
	st.set_content_margin(SIDE_BOTTOM, 28)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	_result_label(vb, "SETTINGS", 38, Color.WHITE)

	var sp0 := Control.new(); sp0.custom_minimum_size = Vector2(0, 4); vb.add_child(sp0)

	# ── Music toggle ──
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 12)
	vb.add_child(music_row)
	var music_lbl := Label.new()
	music_lbl.text = "Music"
	music_lbl.add_theme_font_size_override("font_size", 26)
	music_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	music_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	music_row.add_child(music_lbl)
	var music_btn := Button.new()
	music_btn.custom_minimum_size = Vector2(110, 44)
	music_btn.add_theme_font_size_override("font_size", 22)
	music_btn.add_theme_color_override("font_color", Color.WHITE)
	music_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	music_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	music_row.add_child(music_btn)
	var _music_on := SaveManager.music_volume() > 0.01
	var _update_music_btn := func(on: bool) -> void:
		music_btn.text = "ON" if on else "OFF"
		_style_button(music_btn, Color("2a6b46") if on else Color("5a1a1a"), 10, 8)
	_update_music_btn.call(_music_on)
	music_btn.pressed.connect(func() -> void:
		_music_on = not _music_on
		var vol := 0.5 if _music_on else 0.0
		SaveManager.set_music_volume(vol)
		AudioManager.set_music_volume(vol)
		AudioManager.play("tap")
		_update_music_btn.call(_music_on))

	# ── SFX toggle ──
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 12)
	vb.add_child(sfx_row)
	var sfx_lbl := Label.new()
	sfx_lbl.text = "Sound FX"
	sfx_lbl.add_theme_font_size_override("font_size", 26)
	sfx_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	sfx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sfx_row.add_child(sfx_lbl)
	var sfx_btn := Button.new()
	sfx_btn.custom_minimum_size = Vector2(110, 44)
	sfx_btn.add_theme_font_size_override("font_size", 22)
	sfx_btn.add_theme_color_override("font_color", Color.WHITE)
	sfx_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	sfx_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	sfx_row.add_child(sfx_btn)
	var _sfx_on := SaveManager.sfx_volume() > 0.01
	var _update_sfx_btn := func(on: bool) -> void:
		sfx_btn.text = "ON" if on else "OFF"
		_style_button(sfx_btn, Color("2a6b46") if on else Color("5a1a1a"), 10, 8)
	_update_sfx_btn.call(_sfx_on)
	sfx_btn.pressed.connect(func() -> void:
		_sfx_on = not _sfx_on
		var vol := 0.8 if _sfx_on else 0.0
		SaveManager.set_sfx_volume(vol)
		AudioManager.set_sfx_volume(vol)
		if _sfx_on:
			AudioManager.play("tap")
		_update_sfx_btn.call(_sfx_on))

	# ── View toggle ──
	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 12)
	vb.add_child(view_row)
	var view_lbl := Label.new()
	view_lbl.text = "View"
	view_lbl.add_theme_font_size_override("font_size", 26)
	view_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	view_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_row.add_child(view_lbl)
	var view_btn := Button.new()
	view_btn.custom_minimum_size = Vector2(130, 44)
	view_btn.add_theme_font_size_override("font_size", 20)
	view_btn.add_theme_color_override("font_color", Color.WHITE)
	view_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	view_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	view_row.add_child(view_btn)
	var _cur_mode := SaveManager.camera_mode()
	var _update_view_btn := func(mode: String) -> void:
		view_btn.text = "3/4 View" if mode == "hero" else "Top-Down"
		_style_button(view_btn, Color("1a3a6b") if mode == "hero" else Color("3a2a6b"), 10, 8)
	_update_view_btn.call(_cur_mode)
	view_btn.pressed.connect(func() -> void:
		_cur_mode = "map" if _cur_mode == "hero" else "hero"
		SaveManager.set_camera_mode(_cur_mode)
		_apply_camera_mode(_cur_mode)
		AudioManager.play("tap")
		_update_view_btn.call(_cur_mode))

	var sp1 := Control.new(); sp1.custom_minimum_size = Vector2(0, 8); vb.add_child(sp1)

	# ── Action buttons ──
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	vb.add_child(btns)

	var menu_btn := _sprite_button("MAIN MENU", BTN_FRAME_BLUE)
	menu_btn.pressed.connect(func() -> void:
		AudioManager.play("tap")
		get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	btns.add_child(menu_btn)

	var resume_btn := _sprite_button("RESUME", BTN_FRAME_GREEN)
	resume_btn.pressed.connect(_close_pause_panel)
	btns.add_child(resume_btn)

func _close_pause_panel() -> void:
	AudioManager.play("tap")
	if _pause_panel and is_instance_valid(_pause_panel):
		var tw := _pause_panel.create_tween()
		tw.tween_property(_pause_panel, "color:a", 0.0, 0.15)
		tw.tween_callback(_pause_panel.queue_free)
	_pause_panel = null

func _check_match_end() -> void:
	var human = _rulers[0]
	var human_pct: float = float(grid.territory_count(human.kid)) / float(GW * GH)
	var alive := 0
	for a in _rulers:
		if not a.eliminated:
			alive += 1
	if human.eliminated:
		# Killed (all castles lost) → offer a rewarded-ad revive before it's game over.
		if not _ended and not _continue_pending and _continues_used < MAX_CONTINUES:
			_offer_continue("conquered")
		else:
			_end_match(false, "conquered")
	elif alive == 1:
		_end_match(true, "conquest")               # win: last kingdom standing → next island
	elif _match_t <= 0.0 and _mode in ["campaign", "daily"]:
		# Only the timed modes end on the clock (largest land holder wins). The endless island
		# chain is UNTIMED — it ends only by conquest (advance) or elimination (run over).
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

# Rival line-up for an endless island: the fleet GROWS (3 → 7) and gets BOLDER the
# deeper the run goes, so each island is a step harder than the last.
func _island_dims_for(island: int) -> Vector2i:
	match clampi(island, -1, 3):
		0: return Vector2i(80, 60)
		1: return Vector2i(96, 72)
		2: return Vector2i(112, 84)
		_: return Vector2i(128, 96)

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
		SaveManager.add_coins(int(_endless_score / 20 * SaveManager.match_coin_multiplier()))
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
			SaveManager.add_coins(int(island_score / 20 * SaveManager.match_coin_multiplier()))
			AudioManager.play("round_win")
			_endless_clear_transition()
			return
		# Run over → total it, bank the best, pay coins, show the final results.
		_endless_score = SaveManager.endless_run_score()
		_endless_is_best = SaveManager.record_endless(_endless_score)
		SaveManager.add_coins(int(_endless_score / 20 * SaveManager.match_coin_multiplier()))
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
	SaveManager.add_coins(int(coins * SaveManager.match_coin_multiplier()))
	AudioManager.play("round_win" if win else "defeat")
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

# Island cleared in an endless run: a fireworks send-off, then the camera ZOOMS OUT to
# the map-overview vantage (same as the map button). We snapshot that frame and stash it
# across the scene reload — the next island opens zoomed-out and the two islands slide
# past each other (old exits left, new enters from right; see _endless_intro).
func _endless_clear_transition() -> void:
	if is_instance_valid(camera):
		camera.transition_overview(Vector3.ZERO, 1.0)
	if _rulers[0].castles.size() > 0:
		var cap_cell: Vector2i = _rulers[0].castles[0]["cell"]
		_victory_fireworks(_c2w(cap_cell.x, cap_cell.y, 0.0), _kid_color[_rulers[0].kid])

	# Let the zoom-out settle, then grab the overview frame for the slide and reload.
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	# Drawn-frame readback — capture the receding island as it sits in the map vantage.
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	_clear_frame = get_viewport().get_texture().get_image()
	get_tree().reload_current_scene()

# Open the next island ZOOMED-OUT and slide it in: the cleared island's snapshot covers
# the screen, the new island sits one screen to the right, and the pair slides left so
# the old island exits and the new lands centre. Then the camera zooms in to play.
func _endless_intro() -> void:
	if not is_instance_valid(camera):
		return
	var vp := get_viewport()
	var vsize := vp.get_visible_rect().size
	# No snapshot of the cleared island (shouldn't happen on this path) → just zoom in.
	if _clear_frame == null or _clear_frame.is_empty():
		_clear_frame = null
		await _endless_zoom_intro()
		return
	var old_tex := ImageTexture.create_from_image(_clear_frame)
	_clear_frame = null

	# Cover the screen with the cleared-island snapshot BEFORE the first frame draws, so the
	# new island is never glimpsed early. The new island renders live UNDER the cover, framed
	# in the map vantage but panned one screen-width to the right (off the edge).
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	var cover := TextureRect.new()
	cover.texture = old_tex
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.size = vsize
	cover.position = Vector2.ZERO
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)

	camera.snap_overview(Vector3.ZERO)
	var world_w := _overview_world_width(vsize)

	# Slide the cover (cleared island) off to the left while the live new island pans in
	# from the right — they move together as one strip, so no flash and a true parallax.
	var secs := 0.85
	camera.slide_overview_in(world_w, secs)
	var tw := cover.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(cover, "position:x", -vsize.x, secs).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	layer.queue_free()
	if not is_inside_tree():
		return

	# The new island has landed (still zoomed-out) — name it, hold, then zoom in.
	await _island_arrive_beat()

# World-units across the screen at the overview vantage — used to pan the new island in
# from exactly one screen-width away (so the slide matches the cover's pixel slide).
func _overview_world_width(vsize: Vector2) -> float:
	var cam_y: float = camera.global_position.y
	var half_h: float = cam_y * tan(deg_to_rad(camera.fov * 0.5))
	var aspect: float = vsize.x / maxf(vsize.y, 1.0)
	return half_h * 2.0 * aspect

# Open ZOOMED-OUT with the island named, hold a beat, then zoom in — used when there's no
# previous island to slide off (Play button / cold boot): the zoom-in intro minus the swipe.
func _endless_zoom_intro() -> void:
	if not is_instance_valid(camera):
		_toast(_island_display_name(), Palette.WARN)
		return
	camera.snap_overview(Vector3.ZERO)
	await _island_arrive_beat()

# Shared arrival beat: big centred island name + small score banner, hold ~1s while
# zoomed-out, THEN zoom the camera in to play. Both intro paths end here.
func _island_arrive_beat() -> void:
	_show_island_title(_island_display_name())
	var score := SaveManager.endless_run_score()
	if score > 0:
		_toast("%s   ·   Score %s" % [_island_display_name(), _comma(score)], Palette.WARN)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(camera):
		camera.transition_descend(1.0)

# Name of the island/country the player is currently on (country shape in world-conquest
# mode, otherwise the endless island number).
func _island_display_name() -> String:
	if WORLD_CONQUEST:
		var cidx := clampi(_endless_island, 0, CountryMasks.COUNTRIES.size() - 1)
		return str(CountryMasks.COUNTRIES[cidx]["name"])
	return "Island %d" % (_endless_island + 1)

# Big centred island/country name that pops in when the new island lands, holds, then
# fades out as the camera zooms in.
func _show_island_title(title: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 81
	add_child(layer)
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.13))
	lbl.add_theme_constant_override("outline_size", 12)
	lbl.modulate.a = 0.0
	layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.85)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)

# A few staggered firework bursts over the capital during the victory orbit.
func _victory_fireworks(focus: Vector3, color: Color) -> void:
	if _fx == null:
		return
	# Fewer bursts on mobile/web — this is the only ungated VFX and each burst spawns ~40
	# particles. The win still reads as celebratory at 3 bursts.
	var bursts := 3 if DeviceMode.low_gfx else 5
	for i in bursts:
		if not is_instance_valid(_fx):
			return
		var jitter := Vector3(randf_range(-4.0, 4.0), randf_range(0.0, 3.0), randf_range(-4.0, 4.0))
		_fx.fireworks(focus + jitter, color)
		AudioManager.play("round_win", randf_range(0.9, 1.2))
		await get_tree().create_timer(0.5).timeout

func _show_results(win: bool, reason: String, rank: int, pct: float, coins: int) -> void:
	AudioManager.play_music("menu")
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.09, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.62, 0.3)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(center)

	# Same painted stone frame as the HUD pills (9-slice): blue corner caps + stone
	# border fixed, navy middle stretches to the dialog size — so the results panel reads
	# as one kit with the in-match HUD instead of a flat bordered rect.
	var panel := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = PANEL_FRAME
	st.texture_margin_left = 20
	st.texture_margin_right = 20
	st.texture_margin_top = 20
	st.texture_margin_bottom = 20
	st.set_content_margin(SIDE_LEFT, 34)
	st.set_content_margin(SIDE_RIGHT, 34)
	st.set_content_margin(SIDE_TOP, 28)
	st.set_content_margin(SIDE_BOTTOM, 28)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Headline banner sliced from VictoryDefeat.png (replaces the old text title).
	var banner := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = TEX_BANNERS
	atlas.region = BANNER_VICTORY_RECT if win else BANNER_DEFEAT_RECT
	banner.texture = atlas
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.custom_minimum_size = Vector2(440, 440.0 * atlas.region.size.y / atlas.region.size.x)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(banner)

	# Subtitle / mode lines / campaign banner — centered across the full panel width.
	var sub := ""
	match reason:
		"conquest": sub = "You conquered every rival kingdom!"
		"conquered": sub = "Your kingdom was wiped off the map."
		"popped": sub = "You got popped!  Don't let rivals cut your trail."
		"timeout":
			if win:
				sub = "Time's up — you ruled the most land (%.0f%%)!" % (pct * 100.0)
			else:
				sub = "Time's up — you finished #%d of %d with %.0f%%." % [rank, _n_kingdoms, pct * 100.0]
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

	# Standings row. On a loss the crying toy-king (DefeatMenu.png) sits beside the
	# list — pairing it with the tall element keeps the panel balanced and short
	# enough for the 720px-tall landscape screen.
	var midrow := HBoxContainer.new()
	midrow.alignment = BoxContainer.ALIGNMENT_CENTER
	midrow.add_theme_constant_override("separation", 24)
	midrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(midrow)

	if not win:
		var king := TextureRect.new()
		var king_atlas := AtlasTexture.new()
		king_atlas.atlas = TEX_DEFEAT_MENU
		king_atlas.region = SAD_KING_RECT
		king.texture = king_atlas
		king.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		king.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		king.custom_minimum_size = Vector2(210, 210.0 * SAD_KING_RECT.size.y / SAD_KING_RECT.size.x)
		king.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		midrow.add_child(king)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	midrow.add_child(col)

	# final standings
	var standings: Array = []
	for kid in _kids:
		standings.append({"kid": kid, "n": grid.territory_count(kid)})
	standings.sort_custom(func(x, y): return x["n"] > y["n"])
	var total := float(GW * GH)
	for r in standings.size():
		var e: Dictionary = standings[r]
		_result_label(col, "%d.   %s   %.1f%%" % [r + 1, _kid_name[e["kid"]], 100.0 * e["n"] / total], 24,
			_kid_color[e["kid"]])

	var coin_lbl := _result_label(vb, "+%d coins   (total %d)" % [coins, SaveManager.coins()],
		28, Palette.WARN)
	coin_lbl.add_theme_constant_override("line_spacing", 12)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	vb.add_child(btns)

	var again := _sprite_button("PLAY AGAIN", BTN_FRAME_GREEN)
	again.pressed.connect(func() -> void:
		AudioManager.play("tap")
		get_tree().reload_current_scene())
	btns.add_child(again)

	var menu := _sprite_button("MAIN MENU", BTN_FRAME_BLUE)
	menu.pressed.connect(func() -> void:
		AudioManager.play("tap")
		get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	btns.add_child(menu)

# A CTA button skinned with the kit's stone bar (9-slice): coloured corner caps + stone
# border stay crisp, the navy middle stretches. Pressed = the same frame dimmed + nudged
# down a touch so it reads as a press without a second sprite.
func _sprite_button(text: String, frame: Texture2D) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 5)
	b.custom_minimum_size = Vector2(264, 88)
	var sb_normal := _button_stylebox(frame, Color.WHITE)
	var sb_pressed := _button_stylebox(frame, Color(0.82, 0.82, 0.86))
	sb_pressed.set_content_margin(SIDE_TOP, 16)   # text dips on press
	b.add_theme_stylebox_override("normal", sb_normal)
	b.add_theme_stylebox_override("hover", sb_normal)
	b.add_theme_stylebox_override("focus", sb_normal)
	b.add_theme_stylebox_override("disabled", sb_normal)
	b.add_theme_stylebox_override("pressed", sb_pressed)
	return b

func _button_stylebox(frame: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = frame
	sb.modulate_color = tint
	# 9-slice: keep the stone caps un-stretched, stretch only the middle band.
	sb.texture_margin_left = 34
	sb.texture_margin_right = 34
	sb.texture_margin_top = 34
	sb.texture_margin_bottom = 34
	sb.set_content_margin_all(10)
	return sb

# Brief floating announcement (pops, conquests) that rises and fades.
# Messages are queued so rapid-fire events never overlap.
func _toast(text: String, color: Color = Color.WHITE) -> void:
	if _ui_layer == null:
		return
	_toast_queue.push_back({"text": text, "color": color})
	if not _toast_busy:
		_toast_drain()

func _toast_drain() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var entry: Dictionary = _toast_queue.pop_front()
	var l := Label.new()
	l.text = entry["text"]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(get_viewport().get_visible_rect().size.x, 46)
	l.position = Vector2(0, 156)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", entry["color"])
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	_ui_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(l, "position:y", 132.0, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(l, "position:y", 100.0, 0.4)
	tw.tween_callback(l.queue_free)
	tw.tween_callback(_toast_drain)

# Small join/leave entry appended to the strip below the leaderboard.
# Fades in, lingers 2.5 s, fades out. Caps at 3 visible lines.
func _lb_notify(text: String, color: Color) -> void:
	if _lb_notif_box == null or not is_instance_valid(_lb_notif_box):
		return
	while _lb_notif_box.get_child_count() >= 3:
		var oldest: Node = _lb_notif_box.get_child(0)
		if is_instance_valid(oldest):
			oldest.queue_free()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	_lb_notif_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.85, 0.18)
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
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
		# Coach two-beat: once the player first steps off their land, swap the hint
		# from "draw a loop" to "return home to close it".
		if a == _rulers[0] and _is_first_match and not _coach_trail_started:
			if grid.get_owner(step.x, step.y) != a.kid:
				_coach_trail_started = true
				if _coach_label != null:
					_coach_label.text = "Return home to close the loop!"
				if not _tutorial_tip_shown.has("leave_home"):
					_tutorial_tip_shown["leave_home"] = true
					_show_tutorial_tip("Draw a Loop!",
						"Move outside your land and trace a path.\nLoop back home — everything you circle becomes yours!",
						"res://assets/screenshots/loop.png")
		var _ec0 := Time.get_ticks_usec()
		var res: Dictionary = grid.enter_cell(a.kid, step.x, step.y)
		var _ec1 := Time.get_ticks_usec()
		if int(res.get("captured",0)) > 0:
			_last_cap_us = _ec1 - _ec0
			if _dbg: print("[CAP] enter_cell=%dµs cap=%d" % [_last_cap_us, int(res.get("captured",0))])
		_check_powerup_pickup(a, step)
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
					if _is_first_match and not _tutorial_tip_shown.has("first_claim"):
						_tutorial_tip_shown["first_claim"] = true
						_first_claim_celebration()
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

# Endless/timed (PLAY) is SINGLE-LIFE: getting popped ends the run. Campaign keeps the
# forgiving castle-respawn (handled in _respawn below).
func _is_single_life() -> bool:
	return _mode in ["endless", "timed"]

# Dim the lives dots that have been spent.
func _update_lives_hud() -> void:
	for i in _life_dots.size():
		var dot: Control = _life_dots[i]
		if is_instance_valid(dot):
			dot.modulate = Color.WHITE if i < _lives else Color(1, 1, 1, 0.18)

# A small drawn heart for the lives row (no font/emoji dependency → renders everywhere).
class _Heart extends Control:
	var col: Color = Color("e8414e")
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := w * 0.26
		# two top lobes + a bottom point (triangle) → a clean heart silhouette
		draw_circle(Vector2(w * 0.32, h * 0.33), r, col)
		draw_circle(Vector2(w * 0.68, h * 0.33), r, col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.06, h * 0.40),
			Vector2(w * 0.94, h * 0.40),
			Vector2(w * 0.5, h * 0.97),
		]), col)

# A big, brief centred banner so the player clearly sees WHAT happened (e.g. trail cut)
# and the consequence (lives left) — death is never silent/abrupt.
func _death_flash(title: String, sub: String) -> void:
	if _ui_layer == null:
		return
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	_ui_layer.add_child(box)
	var t := _hud_text(title, 60, Palette.DANGER.lightened(0.1), HORIZONTAL_ALIGNMENT_CENTER, true)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(t)
	var s := _hud_text(sub, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(s)
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.7)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)

func _kill(a) -> void:
	a.alive = false
	a.respawn_t = RESPAWN_TIME
	if a.avatar:
		a.avatar.set_dead()
	# Endless/timed: spend a LIFE per pop (free respawn at a castle); only when lives run
	# out does the rewarded-ad revive offer (then game over) kick in.
	if a == _rulers[0] and _is_single_life() and not _continue_pending and not _ended:
		if _lives > 0:
			_lives -= 1
			_update_lives_hud()
			# clear feedback so the player understands WHY they died (a normal respawn at
			# a castle follows automatically via _physics_process / _respawn).
			_death_flash("TRAIL CUT!", "%d %s left" % [_lives, "life" if _lives == 1 else "lives"])
			if is_instance_valid(camera):
				camera.shake(0.32)
		elif _continues_used < MAX_CONTINUES:
			_offer_continue("popped")
		else:
			_end_match(false, "popped")
	# First-match pop: toast so the player knows what happened (coach may already be gone).
	elif a == _rulers[0] and _is_first_match and not _tutorial_tip_shown.has("pop"):
		_tutorial_tip_shown["pop"] = true
		_show_tip_toast("You got popped!", "A rival cut your trail.\nRace home before rivals can reach you!")

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
	return sqrt(nearest_enemy_dist_sq(agent))

# Squared (x/z) distance to the nearest living rival — avoids the per-call sqrt for
# threshold checks. Compare against (threshold * threshold).
func nearest_enemy_dist_sq(agent) -> float:
	var best := INF
	var pos: Vector3 = agent.avatar.global_position
	for o in _rulers:
		if o == agent or not o.alive:
			continue
		var op: Vector3 = o.avatar.global_position
		var dx := op.x - pos.x
		var dy := op.y - pos.y
		var dz := op.z - pos.z
		var d2: float = dx * dx + dy * dy + dz * dz
		if d2 < best:
			best = d2
	return best

func _clamp(av, is_ai: bool = true) -> bool:
	var hx := _active_w * CELL * 0.5 - CELL
	var hz := _active_h * CELL * 0.5 - CELL
	av.global_position.x = clampf(av.global_position.x, -hx, hx)
	av.global_position.z = clampf(av.global_position.z, -hz, hz)
	if WORLD_CONQUEST and _sdf_dist.size() == GW * GH:
		var cx := clampi(int(floor(av.global_position.x / CELL + GW * 0.5)), 0, GW - 1)
		var cy := clampi(int(floor(av.global_position.z / CELL + GH * 0.5)), 0, GH - 1)
		if _land_mask[cy * GW + cx] == 0:
			var d_l := _sdf_dist[cy * GW + clampi(cx - 1, 0, GW - 1)]
			var d_r := _sdf_dist[cy * GW + clampi(cx + 1, 0, GW - 1)]
			var d_u := _sdf_dist[clampi(cy - 1, 0, GH - 1) * GW + cx]
			var d_d := _sdf_dist[clampi(cy + 1, 0, GH - 1) * GW + cx]
			var gx := float(d_l - d_r)
			var gz := float(d_u - d_d)
			var glen := sqrt(gx * gx + gz * gz)
			if glen > 0.001:
				gx /= glen; gz /= glen
			if is_ai:
				# AI: full cell push so it reliably exits the ocean.
				av.global_position.x += gx * CELL
				av.global_position.z += gz * CELL
			else:
				# Player: snap to the exact land/ocean cell edge so they stop at the
				# waterline without being shoved back inland.
				# gx > 0 → land is in the +x direction → snap to right edge of ocean cell
				# gx < 0 → land is in the -x direction → snap to left edge of ocean cell
				if abs(gx) >= abs(gz):
					if gx > 0.0:
						av.global_position.x = (float(cx + 1) - GW * 0.5) * CELL + 0.02
					else:
						av.global_position.x = (float(cx) - GW * 0.5) * CELL - 0.02
				else:
					if gz > 0.0:
						av.global_position.z = (float(cy + 1) - GH * 0.5) * CELL + 0.02
					else:
						av.global_position.z = (float(cy) - GH * 0.5) * CELL - 0.02
			# Zero the velocity component pointing into ocean so it doesn't re-enter next frame.
			if av.velocity.length_squared() > 0.001:
				var dot: float = float(av.velocity.x) * (-gx) + float(av.velocity.z) * (-gz)
				if dot > 0.0:
					av.velocity.x = float(av.velocity.x) - (-gx) * dot
					av.velocity.z = float(av.velocity.z) - (-gz) * dot
			return true
	return false

# Clamp a world point inside the playable area (used by the AI planner).
# In WORLD_CONQUEST mode iterates the SDF gradient until the point is on a land cell,
# so AI waypoints are never left stranded in the ocean.
# Returns the SDF-gradient direction (in XZ Vector2) pointing TOWARD the nearest land
# cell from world position p. Returns Vector2.ZERO when already on land or no mask active.
# Used by the AI to bias expand headings away from the coast.
func land_inward_dir(p: Vector3) -> Vector2:
	if not (WORLD_CONQUEST and _sdf_dist.size() == GW * GH):
		return Vector2.ZERO
	var cx := clampi(int(floor(p.x / CELL + GW * 0.5)), 0, GW - 1)
	var cy := clampi(int(floor(p.z / CELL + GH * 0.5)), 0, GH - 1)
	if _land_mask[cy * GW + cx] == 1:
		return Vector2.ZERO
	var d_l := _sdf_dist[cy * GW + clampi(cx - 1, 0, GW - 1)]
	var d_r := _sdf_dist[cy * GW + clampi(cx + 1, 0, GW - 1)]
	var d_u := _sdf_dist[clampi(cy - 1, 0, GH - 1) * GW + cx]
	var d_d := _sdf_dist[clampi(cy + 1, 0, GH - 1) * GW + cx]
	return Vector2(float(d_l - d_r), float(d_u - d_d)).normalized()

func world_clamp(v: Vector3) -> Vector3:
	var hx := _active_w * CELL * 0.5 - CELL * 1.5
	var hz := _active_h * CELL * 0.5 - CELL * 1.5
	var result := Vector3(clampf(v.x, -hx, hx), v.y, clampf(v.z, -hz, hz))
	if WORLD_CONQUEST and _sdf_dist.size() == GW * GH:
		for _iter in 40:
			var cx := clampi(int(floor(result.x / CELL + GW * 0.5)), 0, GW - 1)
			var cy := clampi(int(floor(result.z / CELL + GH * 0.5)), 0, GH - 1)
			if _land_mask[cy * GW + cx] == 1:
				break
			var d_l := _sdf_dist[cy * GW + clampi(cx - 1, 0, GW - 1)]
			var d_r := _sdf_dist[cy * GW + clampi(cx + 1, 0, GW - 1)]
			var d_u := _sdf_dist[clampi(cy - 1, 0, GH - 1) * GW + cx]
			var d_d := _sdf_dist[clampi(cy + 1, 0, GH - 1) * GW + cx]
			var gx := float(d_l - d_r)
			var gz := float(d_u - d_d)
			var glen := sqrt(gx * gx + gz * gz)
			if glen > 0.001:
				gx /= glen; gz /= glen
			else:
				break
			result.x += gx * CELL
			result.z += gz * CELL
	return result

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
	if WORLD_CONQUEST and _sdf_dist.size() == GW * GH:
		if _home_cells.size() != n:
			_home_cells = _pick_home_cells(n)
		if i < _home_cells.size():
			return _home_cells[i]
	# Original rectangular placement (used when WORLD_CONQUEST = false).
	var cols := 2 if n <= 4 else 4
	var rows := int(ceil(n / float(cols)))
	var col := i % cols
	var row := i / cols
	var margin_x := (GW - _active_w) / 2 + 12
	var margin_y := (GH - _active_h) / 2 + 12
	var x := int(lerpf(float(margin_x), float(GW - margin_x), col / float(maxi(cols - 1, 1))))
	var y := int(lerpf(float(margin_y), float(GH - margin_y), row / float(maxi(rows - 1, 1))))
	return Vector2i(x, y)

# Returns all connected land components sorted largest-first.
# Each entry is an Array of cell indices belonging to that component.
func _land_components() -> Array:
	var visited := PackedByteArray(); visited.resize(GW * GH); visited.fill(0)
	var comps: Array = []
	for start in GW * GH:
		if _land_mask[start] == 0 or visited[start] == 1:
			continue
		var queue: Array = [start]
		var comp: Array = []
		var head := 0
		while head < queue.size():
			var idx: int = queue[head]; head += 1
			if visited[idx] == 1: continue
			visited[idx] = 1; comp.append(idx)
			var x: int = idx % GW; var y: int = idx / GW
			for delta in [[-1,0],[1,0],[0,-1],[0,1]]:
				var nx: int = x + delta[0]; var ny: int = y + delta[1]
				if nx < 0 or nx >= GW or ny < 0 or ny >= GH: continue
				var ni: int = ny * GW + nx
				if _land_mask[ni] == 1 and visited[ni] == 0:
					queue.append(ni)
		comps.append(comp)
	comps.sort_custom(func(a, b): return a.size() > b.size())   # largest first
	return comps

# Greedy inland placement. Always returns exactly n cells on valid land.
# Priority: deeply-inland cells on large islands. Final fallback: any land cell,
# so kingdoms never spawn via the rectangular fallback which ignores the land mask.
func _pick_home_cells(n: int) -> Array:
	var all_comps := _land_components()
	if all_comps.is_empty():
		return []

	# Castles only ever sit on the MAINLAND — the single largest land component.
	# Detached islands (Andaman & Nicobar, Hawaii, Alaska…) still RENDER from the
	# land mask as neutral scenery, but never host a castle/town: homes drive
	# town clustering + roads, and avatars can't cross ocean to reach an island,
	# so confining homes to the mainland keeps every build off the islands.
	var mainland: Array = all_comps[0]
	var mainland_set := PackedByteArray(); mainland_set.resize(GW * GH); mainland_set.fill(0)
	for idx: int in mainland:
		mainland_set[idx] = 1
	var comps: Array = [mainland]

	# ── Build candidates from the real mask ───────────────────────────────────
	# 7 cells at 0.6 wu/cell = 4.2 wu buffer. At 0.2 wu/cell, same 4.2 wu = 21 cells.
	# This guarantees the castle and 6+ cells around it all sit on green land.
	const MIN_INLAND := 21
	var comp_candidates: Array = []
	var total_eligible_land := 0
	for comp in comps:
		var cands: Array = []
		for idx: int in comp:
			if _inland_sdf[idx] >= MIN_INLAND:
				cands.append([_inland_sdf[idx], idx])
		cands.sort_custom(func(a, b): return a[0] > b[0])
		comp_candidates.append(cands)
		total_eligible_land += comp.size()

	# min_sep: minimum Euclidean distance (cells) between any two castles.
	# Must be > 2×HOME_R so home blobs never overlap on spawn.
	var min_sep := maxi(int(sqrt(float(total_eligible_land) / float(n)) * 0.6), 2 * HOME_R + 4)
	var min_sep_sq := min_sep * min_sep

	# Helper: test a candidate cell against all already-chosen cells.
	var dist_ok := func(c: Vector2i, chosen: Array) -> bool:
		for h: Vector2i in chosen:
			var dx := c.x - h.x; var dy := c.y - h.y
			if dx * dx + dy * dy < min_sep_sq: return false
		return true

	# Single largest component first (mainland countries).
	var chosen := _greedy_pick(comp_candidates[0], n, min_sep)
	if chosen.size() >= n:
		print("[HOME] placed %d/%d kingdoms on mainland (min_sep=%d) — cells: %s" % [chosen.size(), n, min_sep, str(chosen)])
		return chosen

	# Multi-island: distribute slots proportionally across eligible components.
	var slots: Array = []
	var remaining := n
	for ci in comps.size():
		if remaining <= 0: slots.append(0); continue
		var share := maxi(1, int(float(comps[ci].size()) / float(total_eligible_land) * n))
		share = mini(share, remaining)
		slots.append(share); remaining -= share
	if remaining > 0: slots[0] += remaining

	var all_chosen: Array = []
	for ci in slots.size():
		if slots[ci] <= 0: continue
		var picked := _greedy_pick(comp_candidates[ci], slots[ci], min_sep, all_chosen)
		if picked.size() < slots[ci]:
			picked = _greedy_pick(comp_candidates[ci], slots[ci], maxi(min_sep / 2, 2 * HOME_R + 2), all_chosen)
		if picked.size() < slots[ci]:
			picked = _greedy_pick(comp_candidates[ci], slots[ci], 2 * HOME_R + 2, all_chosen)
		all_chosen.append_array(picked)

	if all_chosen.size() >= n:
		return all_chosen

	# ── Dilation pass: make the map "larger" ──────────────────────────────────
	# Narrow islands (Java, Sulawesi) have inland_sdf < 7 on the real mask.
	# Grow land by DILATE_R cells → fat islands wide enough for MIN_INLAND=7 depth.
	# Find deep positions on the fat mask, snap each back to the nearest real land cell.
	const DILATE_R := 4
	var fat_mask := _dilate_land_mask(_land_mask, DILATE_R)
	var fat_inland: PackedInt32Array = _build_inland_sdf(fat_mask, GW, GH)

	# 140 at 128×96 → 1260 at 384×288 (same proportional area filter).
	const MIN_COMP_SIZE := 1260
	var fat_comps := _land_components_of(fat_mask)
	var fat_cands: Array = []
	for comp in fat_comps:
		if comp.size() < MIN_COMP_SIZE: continue
		for idx: int in comp:
			if fat_inland[idx] >= MIN_INLAND:
				fat_cands.append([fat_inland[idx], idx])
	fat_cands.sort_custom(func(a, b): return a[0] > b[0])

	for entry in fat_cands:
		if all_chosen.size() >= n: break
		var fat_cell := Vector2i(entry[1] % GW, entry[1] / GW)
		var real_cell := _snap_to_real_land(fat_cell)
		if real_cell.x < 0 or not dist_ok.call(real_cell, all_chosen): continue
		if mainland_set[real_cell.y * GW + real_cell.x] == 0: continue   # mainland only — no island castles
		all_chosen.append(real_cell)

	# ── Safety net: any real land cell, sorted by inland depth ────────────────
	# Progressively relax min_sep until we have n distinct cells.
	# The relaxed sep values still respect the HOME territory radius (HOME_R ≈ 4)
	# so starting blobs don't immediately overlap.
	if all_chosen.size() < n:
		var any_land: Array = []
		for idx in GW * GH:
			if mainland_set[idx] == 1:   # mainland only — islands render but never host a castle
				any_land.append([_inland_sdf[idx], idx])
		any_land.sort_custom(func(a, b): return a[0] > b[0])
		for snet_sep in [min_sep, maxi(min_sep / 2, 2 * HOME_R + 2), 2 * HOME_R + 2, 2 * HOME_R]:
			for entry in any_land:
				if all_chosen.size() >= n: break
				var cell := Vector2i(entry[1] % GW, entry[1] / GW)
				var ok := true
				for h: Vector2i in all_chosen:
					var dx := cell.x - h.x; var dy := cell.y - h.y
					if dx * dx + dy * dy < snet_sep * snet_sep: ok = false; break
				if ok: all_chosen.append(cell)
			if all_chosen.size() >= n: break

	print("[HOME] placed %d/%d kingdoms (min_sep=%d) — cells: %s" % [all_chosen.size(), n, min_sep, str(all_chosen)])
	return all_chosen

# Grow every land cell outward by radius cells (morphological dilation).
func _dilate_land_mask(mask: PackedByteArray, radius: int) -> PackedByteArray:
	var result := PackedByteArray(); result.resize(GW * GH); result.fill(0)
	for i in GW * GH:
		if mask[i] == 0: continue
		var x: int = i % GW; var y: int = i / GW
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy > radius * radius: continue
				var nx: int = x + dx; var ny: int = y + dy
				if nx < 0 or nx >= GW or ny < 0 or ny >= GH: continue
				result[ny * GW + nx] = 1
	return result

# Connected-component BFS on an arbitrary mask (reuses _land_components logic).
func _land_components_of(mask: PackedByteArray) -> Array:
	var visited := PackedByteArray(); visited.resize(GW * GH); visited.fill(0)
	var comps: Array = []
	for start in GW * GH:
		if mask[start] == 0 or visited[start] == 1: continue
		var queue: Array = [start]; var comp: Array = []; var head := 0
		while head < queue.size():
			var idx: int = queue[head]; head += 1
			if visited[idx] == 1: continue
			visited[idx] = 1; comp.append(idx)
			var x: int = idx % GW; var y: int = idx / GW
			for delta in [[-1,0],[1,0],[0,-1],[0,1]]:
				var nx: int = x + delta[0]; var ny: int = y + delta[1]
				if nx < 0 or nx >= GW or ny < 0 or ny >= GH: continue
				var ni: int = ny * GW + nx
				if mask[ni] == 1 and visited[ni] == 0: queue.append(ni)
		comps.append(comp)
	comps.sort_custom(func(a, b): return a.size() > b.size())
	return comps

# Walk the real SDF gradient from a fat-mask cell back onto the original land mask.
func _snap_to_real_land(fat_cell: Vector2i) -> Vector2i:
	var cx: int = clampi(fat_cell.x, 0, GW - 1)
	var cy: int = clampi(fat_cell.y, 0, GH - 1)
	for _iter in 20:
		if _land_mask[cy * GW + cx] == 1:
			return Vector2i(cx, cy)
		var d_l := _sdf_dist[cy * GW + clampi(cx - 1, 0, GW - 1)]
		var d_r := _sdf_dist[cy * GW + clampi(cx + 1, 0, GW - 1)]
		var d_u := _sdf_dist[clampi(cy - 1, 0, GH - 1) * GW + cx]
		var d_d := _sdf_dist[clampi(cy + 1, 0, GH - 1) * GW + cx]
		var gx := float(d_l - d_r); var gz := float(d_u - d_d)
		if abs(gx) >= abs(gz):
			cx += 1 if gx > 0.0 else -1
		else:
			cy += 1 if gz > 0.0 else -1
		cx = clampi(cx, 0, GW - 1); cy = clampi(cy, 0, GH - 1)
	return Vector2i(-1, -1)   # failed to find land

# existing: already-placed cells from OTHER components (cross-island guard).
func _greedy_pick(candidates: Array, n: int, sep: int, existing: Array = []) -> Array:
	var chosen: Array = []
	var sep_sq := sep * sep
	for entry in candidates:
		if chosen.size() >= n: break
		var idx: int = entry[1]
		var cx := idx % GW; var cy := idx / GW
		var ok := true
		for h: Vector2i in chosen:
			var dx := cx - h.x; var dy := cy - h.y
			if dx * dx + dy * dy < sep_sq: ok = false; break
		if ok:
			for h: Vector2i in existing:
				var dx := cx - h.x; var dy := cy - h.y
				if dx * dx + dy * dy < sep_sq: ok = false; break
		if ok: chosen.append(Vector2i(cx, cy))
	return chosen

# The 8 kingdom colours, sampled from the atlas's coloured ground tiles so the
# painted territory matches the art exactly.
# Hues tuned to target_art.png: true distinct primaries (red is RED not orange,
# green is emerald not olive) so the eight kingdoms read as cleanly as the target.
const KINGDOM_COLORS := [
	Color("4d9ef5"), Color("d22323"), Color("33a23a"), Color("ecae12"),
	Color("8a3fc0"), Color("23a6ad"), Color("e87b14"), Color("e2479a"),
]
const FAKE_PLAYER_NAMES := [
	"jake_99", "emma.k", "miguel_r", "sarah_xo", "tommy_g",
	"alex_win", "lucy_k", "kevin88", "mia_2024", "ryan_rx",
	"zoe_kat", "noah_gx", "lily_rx", "ethan_x", "ava_win",
	"mason_g", "olivia99", "liam_top", "sofia_xx", "james_77",
	"aiden_k", "ella_pro", "henry_f", "grace_rx",
]
const FAKE_PLAYER_AVATARS := [
	"🐱", "🦊", "🐻", "🐼", "🦁", "🐯", "🐺", "🦝",
	"🐸", "🐧", "🦉", "🦋", "🐬", "🦄", "🐲", "🦅",
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
	_kid_label[1] = "You"
	_kid_avatar[1] = "👑"
	# Colors: sorted by distance from the human's color so rivals read as distinct.
	var pairs: Array = []
	for i in KINGDOM_COLORS.size():
		pairs.append({"col": KINGDOM_COLORS[i]})
	pairs.sort_custom(func(a, b): return _col_dist(a.col, human_col) > _col_dist(b.col, human_col))
	# Names + avatars: shuffled independently from their pools each match.
	var name_pool: Array = FAKE_PLAYER_NAMES.duplicate()
	var avatar_pool: Array = FAKE_PLAYER_AVATARS.duplicate()
	name_pool.shuffle()
	avatar_pool.shuffle()
	for i in range(1, _n_kingdoms):          # rivals: i = 1.._n-1 → kid = i + 1
		var p: Dictionary = pairs[(i - 1) % pairs.size()]
		_kid_color[i + 1] = p.col
		_kid_label[i + 1] = name_pool[(i - 1) % name_pool.size()]
		_kid_avatar[i + 1] = avatar_pool[(i - 1) % avatar_pool.size()]

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
		var key := world.get_node("KeyLight") as DirectionalLight3D
		if DeviceMode.is_web:
			# WebGL2 renders at full native resolution (no 3D downscale — the offscreen
			# blit regresses there), so the shadow depth pass + per-fragment PCF sampling
			# is a top cost and pins the browser at single-digit fps. Drop shadows on web;
			# the flat near-top-down toy art reads fine with ambient + rim light alone.
			key.shadow_enabled = false
		else:
			# Mobile: trim the cascade. At the near-top-down camera the extra splits /
			# long distance barely read, so one tighter split saves the depth pass cost.
			key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			key.directional_shadow_max_distance = 28.0

func _build_ground() -> void:
	# The play board is an ISLAND: everything outside the grid rectangle is open sea.
	# One big animated ocean plane sits just below the board (the island is opaque and
	# drawn on top, so water only shows past the coast). The ground shader's coast rim
	# reads as the sandy beach where land meets the surf.
	_ocean = Ocean.new()
	add_child(_ocean)
	_ocean.setup(Vector2(GW * CELL * 0.5, GH * CELL * 0.5))
	if WORLD_CONQUEST and _land_mask.size() > 0:
		var sdf := _build_shore_sdf(_land_mask, GW, GH)
		_sdf_dist = sdf["dist"]
		_inland_sdf = _build_inland_sdf(_land_mask, GW, GH)
		_ocean.set_shore_sdf(sdf["img"], 20.0 * CELL)  # 20 cells (12 wu) of foam falloff

# BFS distance-from-shore field: each cell gets the distance (in cells) to the
# nearest land cell. Land cells → 0, adjacent ocean → 1, etc. Capped at 20.
# Returns a GW×GH Image (FORMAT_R8) with R = dist / 20 (0=coast, 1=far).
# Returns {"img": Image, "dist": PackedInt32Array}.
# img  — R8 with R = dist/MAX_D (0=coast, 1=far) for the ocean foam shader.
# dist — raw BFS cell distances (0=land, N=N cells from shore) for movement clamping.
static func _build_shore_sdf(mask: PackedByteArray, w: int, h: int) -> Dictionary:
	var MAX_D := 20   # 20 cells × 0.6 wu/cell = 12 wu shore/foam range
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(MAX_D + 1)
	var queue: Array = []
	for i in w * h:
		if mask[i] == 1:
			dist[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var idx: int = queue[head]; head += 1
		var d: int = dist[idx]
		if d >= MAX_D:
			continue
		var x: int = idx % w
		var y: int = idx / w
		for delta in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var nx: int = x + delta[0]
			var ny: int = y + delta[1]
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			var ni: int = ny * w + nx
			if dist[ni] > d + 1:
				dist[ni] = d + 1
				queue.append(ni)
	var img := Image.create(w, h, false, Image.FORMAT_R8)
	for i in w * h:
		var v := clampf(float(dist[i]) / float(MAX_D), 0.0, 1.0)
		img.set_pixel(i % w, i / w, Color(v, 0.0, 0.0))
	return {"img": img, "dist": dist}

# Inland depth for every land cell: BFS seeded from coastal land (cells adjacent to
# ocean or grid edge) propagating inward.  0=ocean (skip), 1=coastal land, N=N steps inland.
# This is the OPPOSITE direction to _build_shore_sdf and is correct for home placement.
static func _build_inland_sdf(mask: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var dist := PackedInt32Array(); dist.resize(w * h); dist.fill(0)
	var queue: Array = []
	for i in w * h:
		if mask[i] == 0: continue      # ocean — leave at 0, not visited
		var x: int = i % w; var y: int = i / w
		var coastal := false
		for delta in [[-1,0],[1,0],[0,-1],[0,1]]:
			var nx: int = x + delta[0]; var ny: int = y + delta[1]
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				coastal = true; break
			if mask[ny * w + nx] == 0:
				coastal = true; break
		if coastal:
			dist[i] = 1; queue.append(i)
	var head := 0
	while head < queue.size():
		var idx: int = queue[head]; head += 1
		var d: int = dist[idx]
		var x: int = idx % w; var y: int = idx / w
		for delta in [[-1,0],[1,0],[0,-1],[0,1]]:
			var nx: int = x + delta[0]; var ny: int = y + delta[1]
			if nx < 0 or nx >= w or ny < 0 or ny >= h: continue
			var ni: int = ny * w + nx
			if mask[ni] == 0 or dist[ni] != 0: continue   # skip ocean or already visited
			dist[ni] = d + 1; queue.append(ni)
	return dist

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

# Painted toy sprites for the core HUD glyphs (sliced from assets/hud_assets.png).
# Anything not in here still falls back to the procedural GlyphIcon.
const HUD_SPRITES := {
	"coin":   preload("res://assets/hud/coin.png"),
	"people": preload("res://assets/hud/population.png"),
	"clock":  preload("res://assets/hud/clock.png"),
	"map":    preload("res://assets/hud/map.png"),
	"boost":  preload("res://assets/hud/boost.png"),
	"shield": preload("res://assets/hud/shield.png"),
	"gear":   preload("res://assets/hud/gear.png"),
	"pause":  preload("res://assets/hud/pause.png"),
}
# 9-slice version of the signboard (banner/borders fixed, navy middle stretches) so
# the frame fits any kingdom count without distorting the art. Margins below match it.
const LEADERBOARD_NS    := preload("res://assets/leaderboard_ns.png")
const MINIMAP_FRAME     := preload("res://assets/minimap_frame.png")
# Painted "your kingdom" card: castle + three colour rows (blue people, gold coins,
# green land). We drop the live value onto each row (see _statcard_value).
const STATCARD          := preload("res://assets/statcard.png")
# Blue-cornered stone pill frame (9-slice): the kit's plain panel, used as the
# background for every HUD pill so they match the framed cards instead of reading
# as flat black rounded rects.
const PANEL_FRAME       := preload("res://assets/panel_frame.png")
const _UpgradesData     := preload("res://theme/upgrades.gd")

# ── HUD: territory readout + live leaderboard ─────────────────────────────────
func _build_hud(ui: CanvasLayer) -> void:
	_lb_rows.clear()
	_build_scrims(ui)                       # top/bottom gradients lift the HUD off the board

	# ── top-left: your kingdom card (painted sprite, live values on the colour rows) ──
	# The art bakes a castle + three colour rows (blue=people, gold=coins, green=land);
	# we just drop the live value right-aligned onto each row.
	# The PNG is pre-scaled to its display size, so render at native size (no Control
	# sizing fight) and lay the values on by measured row fractions.
	var sc_w := float(STATCARD.get_width())
	var sc_h := float(STATCARD.get_height())
	var stat := TextureRect.new()
	stat.texture = STATCARD
	stat.position = Vector2(16, 14)
	stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(stat)
	# Row centres measured as fractions of the card height (blue/gold/green bands).
	_pop_label    = _statcard_value(stat, sc_w, sc_h, 0.242)
	_income_label = _statcard_value(stat, sc_w, sc_h, 0.505)
	_terr_label   = _statcard_value(stat, sc_w, sc_h, 0.747)

	# ── top-centre: match countdown (campaign) / island indicator (endless) ──
	# Endless has no doom-clock — only death ends the run — so the centre pill shows
	# which island you're on instead of a countdown.
	_timer_panel = _hud_panel(Vector2.ZERO, Vector2(168, 52), 16)
	ui.add_child(_timer_panel)
	_timer_panel.set_anchor(SIDE_LEFT, 0.5)
	_timer_panel.set_anchor(SIDE_RIGHT, 0.5)
	_timer_panel.set_offset(SIDE_LEFT, -84)
	_timer_panel.set_offset(SIDE_RIGHT, 84)
	_timer_panel.set_offset(SIDE_TOP, 14)
	_timer_panel.set_offset(SIDE_BOTTOM, 66)
	var th := _pill_row(_timer_panel)
	th.add_theme_constant_override("separation", 8)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	var is_chain := _mode in ["endless", "timed"]
	th.add_child(_icon("map" if is_chain else "clock", HUD_GOLD, 30))
	var init_t := ("ISLAND %d" % (_endless_island + 1)) if is_chain else "0:00"
	_time_label = _hud_text(init_t, 26 if is_chain else 30, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	th.add_child(_time_label)

	# Campaign: a small stage chip under the clock so the player always knows which
	# stage of the ladder they're on (the campaign was otherwise invisible in-match).
	if _mode == "campaign":
		var stage_chip := _hud_panel(Vector2.ZERO, Vector2(300, 44), 12)
		ui.add_child(stage_chip)
		stage_chip.set_anchor(SIDE_LEFT, 0.5)
		stage_chip.set_anchor(SIDE_RIGHT, 0.5)
		stage_chip.set_offset(SIDE_LEFT, -150)
		stage_chip.set_offset(SIDE_RIGHT, 150)
		stage_chip.set_offset(SIDE_TOP, 70)
		stage_chip.set_offset(SIDE_BOTTOM, 114)
		var sr := _pill_row(stage_chip); sr.alignment = BoxContainer.ALIGNMENT_CENTER
		sr.add_child(_hud_text("STAGE %d/%d  ·  %s" % [_stage + 1, Campaign.count(), Campaign.title(_stage)],
			16, HUD_GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	# Endless/timed: a lives row (dots) under the island pill so the player always knows
	# how many free respawns remain before a run-ending offer.
	if _is_single_life():
		var lives_chip := _hud_panel(Vector2.ZERO, Vector2(150, 40), 12)
		ui.add_child(lives_chip)
		lives_chip.set_anchor(SIDE_LEFT, 0.5)
		lives_chip.set_anchor(SIDE_RIGHT, 0.5)
		lives_chip.set_offset(SIDE_LEFT, -75)
		lives_chip.set_offset(SIDE_RIGHT, 75)
		lives_chip.set_offset(SIDE_TOP, 70)
		lives_chip.set_offset(SIDE_BOTTOM, 110)
		var lr := _pill_row(lives_chip); lr.alignment = BoxContainer.ALIGNMENT_CENTER
		lr.add_theme_constant_override("separation", 8)
		_life_dots.clear()
		for i in LIVES_PER_ISLAND:
			var heart := _Heart.new()
			heart.custom_minimum_size = Vector2(24, 22)
			heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lr.add_child(heart)
			_life_dots.append(heart)
		_update_lives_hud()

	# ── top-right: coins + population pills, then settings ──
	var coins := _hud_panel(Vector2.ZERO, Vector2(158, 48), 14)
	ui.add_child(coins)
	_coins_chip = coins
	coins.set_anchor(SIDE_LEFT, 1.0)
	coins.set_anchor(SIDE_RIGHT, 1.0)
	coins.set_offset(SIDE_LEFT, -374)
	coins.set_offset(SIDE_RIGHT, -216)
	coins.set_offset(SIDE_TOP, 16)
	coins.set_offset(SIDE_BOTTOM, 64)
	coins.pivot_offset = Vector2(79, 24)   # centre pivot so the earn-pop scales nicely
	var ch := _pill_row(coins); ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(_icon("coin", HUD_GOLD, 30))
	_coins_label = _hud_text("0", 22, HUD_GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	ch.add_child(_coins_label)

	var pop := _hud_panel(Vector2.ZERO, Vector2(132, 48), 14)
	ui.add_child(pop)
	pop.set_anchor(SIDE_LEFT, 1.0)
	pop.set_anchor(SIDE_RIGHT, 1.0)
	pop.set_offset(SIDE_LEFT, -204)
	pop.set_offset(SIDE_RIGHT, -72)
	pop.set_offset(SIDE_TOP, 16)
	pop.set_offset(SIDE_BOTTOM, 64)
	var ph := _pill_row(pop); ph.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_child(_icon("people", HUD_BLUE, 30))
	_pop_pill_label = _hud_text("0", 22, HUD_BLUE, HORIZONTAL_ALIGNMENT_LEFT, true)
	ph.add_child(_pop_pill_label)

	var gear := Button.new()
	gear.custom_minimum_size = Vector2(44, 48)
	gear.set_anchor(SIDE_LEFT, 1.0)
	gear.set_anchor(SIDE_RIGHT, 1.0)
	gear.set_offset(SIDE_LEFT, -60)
	gear.set_offset(SIDE_RIGHT, -16)
	gear.set_offset(SIDE_TOP, 16)
	gear.set_offset(SIDE_BOTTOM, 64)
	gear.mouse_filter = Control.MOUSE_FILTER_STOP
	var _empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		gear.add_theme_stylebox_override(state, _empty)
	var gear_icon := _icon("gear", Color.WHITE, 34)
	gear_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gear_icon.offset_left = 4; gear_icon.offset_right = -4
	gear_icon.offset_top = 6; gear_icon.offset_bottom = -6
	gear.add_child(gear_icon)
	gear.pressed.connect(_show_pause_panel)
	_hover_lift(gear)
	ui.add_child(gear)

	# ── right: live leaderboard (9-slice signboard) ──
	# The frame is a NinePatchRect: the banner + gold borders stay fixed while only the
	# navy middle stretches, so the sign sizes to the kingdom count (4 or 8) without ever
	# distorting the art or leaving a big empty panel.
	const LB_W := 240.0
	const LB_BANNER := 82.0      # fixed banner+top-border zone (matches the 9-slice top margin)
	const LB_BOTTOM := 20.0      # fixed bottom-border zone
	const LB_ROW := 30.0         # vertical pitch per standings row
	var lb_h: float = LB_BANNER + LB_BOTTOM + LB_ROW * float(_n_kingdoms) + 6.0
	var lb := NinePatchRect.new()
	lb.texture = LEADERBOARD_NS
	lb.patch_margin_left = 13
	lb.patch_margin_right = 13
	lb.patch_margin_top = 80
	lb.patch_margin_bottom = 16
	lb.set_anchor(SIDE_LEFT, 1.0)
	lb.set_anchor(SIDE_RIGHT, 1.0)
	lb.set_offset(SIDE_LEFT, -(LB_W + 40))
	lb.set_offset(SIDE_RIGHT, -40)
	lb.set_offset(SIDE_TOP, 70)
	lb.set_offset(SIDE_BOTTOM, 70 + lb_h)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(lb)
	# Title rides the banner ribbon at the top of the frame.
	var lb_title := _hud_text("LEADERBOARD", 15, Color(1, 1, 1, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
	lb_title.add_theme_constant_override("outline_size", 5)
	lb_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lb_title.offset_left = 12
	lb_title.offset_right = -12
	lb_title.offset_top = 16
	lb.add_child(lb_title)
	# Rows sit in the navy interior, clear of the banner + gold border.
	var lb_m := MarginContainer.new()
	lb_m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb_m.add_theme_constant_override("margin_left", 18)
	lb_m.add_theme_constant_override("margin_right", 16)
	lb_m.add_theme_constant_override("margin_top", int(LB_BANNER + 2))
	lb_m.add_theme_constant_override("margin_bottom", int(LB_BOTTOM + 2))
	lb_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_child(lb_m)
	var lb_v := VBoxContainer.new()
	lb_v.add_theme_constant_override("separation", 6)
	lb_v.alignment = BoxContainer.ALIGNMENT_CENTER
	lb_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb_m.add_child(lb_v)
	for i in _n_kingdoms:
		var rr := _make_lb_row()
		lb_v.add_child(rr["row"])
		_lb_rows.append(rr)

	# Join/leave notification strip — sits flush below the leaderboard frame.
	var notif := VBoxContainer.new()
	notif.set_anchor(SIDE_LEFT, 1.0)
	notif.set_anchor(SIDE_RIGHT, 1.0)
	notif.set_anchor(SIDE_TOP, 0.0)
	notif.set_anchor(SIDE_BOTTOM, 0.0)
	notif.set_offset(SIDE_LEFT, -(LB_W + 40))
	notif.set_offset(SIDE_RIGHT, -40)
	notif.set_offset(SIDE_TOP, 70 + lb_h + 4)
	notif.set_offset(SIDE_BOTTOM, 70 + lb_h + 4 + 96)
	notif.add_theme_constant_override("separation", 2)
	notif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(notif)
	_lb_notif_box = notif

	# First match always shows the coach banner. The action stack is deferred on first
	# campaign match (the economy tutorial lands next); for endless the action stack still
	# shows so the player has boost/shield access in a single-life run.
	if _is_first_match:
		_build_first_match_coach(ui)
	if not _is_first_match or _mode != "campaign":
		_build_action_stack(ui)

	# Minimap paints from grid data (no 3D render) — no environment needed.
	_minimap = Minimap.new()
	_minimap.setup(GW, GH)
	_minimap.set_active_half(_active_w, _active_h)
	if WORLD_CONQUEST and _land_mask.size() > 0:
		_minimap.set_land_mask(_land_mask)
	_minimap.set_frame(MINIMAP_FRAME)
	ui.add_child(_minimap)
	_minimap.set_anchor(SIDE_LEFT, 1.0)
	_minimap.set_anchor(SIDE_RIGHT, 1.0)
	_minimap.set_anchor(SIDE_TOP, 1.0)
	_minimap.set_anchor(SIDE_BOTTOM, 1.0)
	_minimap.set_offset(SIDE_LEFT, -286)
	_minimap.set_offset(SIDE_RIGHT, -56)
	_minimap.set_offset(SIDE_TOP, -202)
	_minimap.set_offset(SIDE_BOTTOM, -30)

# First-match coach: one friendly, pulsing banner just above the controls that teaches
# the core loop in two beats — "draw a loop" then "return home". Dismissed the instant
# the player closes their first loop (see _dismiss_coach in the capture path).
func _build_first_match_coach(ui: CanvasLayer) -> void:
	var panel := _hud_panel(Vector2.ZERO, Vector2(460, 60), 18)
	ui.add_child(panel)
	panel.set_anchor(SIDE_LEFT, 0.5)
	panel.set_anchor(SIDE_RIGHT, 0.5)
	panel.set_anchor(SIDE_TOP, 1.0)
	panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.set_offset(SIDE_LEFT, -230)
	panel.set_offset(SIDE_RIGHT, 230)
	panel.set_offset(SIDE_TOP, -150)
	panel.set_offset(SIDE_BOTTOM, -90)
	panel.pivot_offset = Vector2(230, 30)
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

# Pause the match and show a contextual tip card explaining what just happened.
# Called fire-and-forget (callers don't await). Auto-dismisses after 5 s.
# Pass shot="res://assets/screenshots/foo.png" to show a game screenshot above the text.
func _show_tutorial_tip(title: String, body: String, shot: String = "") -> void:
	if _ui_layer == null or not is_inside_tree():
		return
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.09, 0.80)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.add_child(center)

	var panel := _hud_panel(Vector2.ZERO, Vector2(500, 0), 18)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	if shot != "":
		var shot_img := TextureRect.new()
		var raw := Image.load_from_file(shot)
		if raw:
			shot_img.texture = ImageTexture.create_from_image(raw)
		shot_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shot_img.clip_contents = true
		shot_img.custom_minimum_size = Vector2(500, 220)
		shot_img.process_mode = Node.PROCESS_MODE_ALWAYS
		vb.add_child(shot_img)

	vb.add_child(_hud_text(title, 38, Palette.WARN, HORIZONTAL_ALIGNMENT_CENTER, true))

	var body_l := _hud_text(body, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_l.custom_minimum_size = Vector2(460, 0)
	vb.add_child(body_l)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sp)

	var btn := Button.new()
	btn.text = "GOT IT"
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(Palette.SAFE, 0.9)
	bs.set_corner_radius_all(18)
	bs.content_margin_left = 32; bs.content_margin_right = 32
	bs.content_margin_top = 10; bs.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover", bs)
	btn.add_theme_stylebox_override("pressed", bs)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(btn)

	var dismissed := [false]
	btn.pressed.connect(func() -> void:
		if dismissed[0]:
			return
		dismissed[0] = true
		AudioManager.play("tap")
		get_tree().paused = false
		dim.queue_free())

	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)

	await get_tree().create_timer(5.0).timeout
	if not dismissed[0] and is_inside_tree() and is_instance_valid(dim):
		dismissed[0] = true
		get_tree().paused = false
		dim.queue_free()

# Non-pausing toast that celebrates a milestone without interrupting play.
func _show_tip_toast(title: String, body: String, duration: float = 3.0) -> void:
	if _ui_layer == null or not is_inside_tree():
		return
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(center)
	var panel := _hud_panel(Vector2.ZERO, Vector2(480, 0), 18)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(_hud_text(title, 34, Palette.SAFE, HORIZONTAL_ALIGNMENT_CENTER, true))
	var bl := _hud_text(body, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(440, 0)
	vb.add_child(bl)
	center.modulate.a = 0.0
	var tw := center.create_tween()
	tw.tween_property(center, "modulate:a", 1.0, 0.35)
	tw.tween_interval(duration)
	tw.tween_property(center, "modulate:a", 0.0, 0.6)
	tw.tween_callback(center.queue_free)

# Celebrate the first loop with a paused screenshot tip.
func _first_claim_celebration() -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	_show_tutorial_tip("Territory Claimed!",
		"Keep looping to grow your kingdom.\nSurround a rival's castle completely to capture it!",
		"res://assets/screenshots/capture2.png")

# Bobbing "YOUR CASTLE" Label3D so new players know where home is.
# Auto-fades after 8 s to keep the mid-game view clean.
func _build_castle_indicator(home: Vector2i, color: Color) -> void:
	var ind := Label3D.new()
	ind.text = "▼  YOUR CASTLE"
	ind.modulate = color
	ind.outline_modulate = Color(0, 0, 0, 0.9)
	ind.outline_size = 12
	ind.font_size = 72
	ind.pixel_size = 0.011
	ind.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var base_y := 8.5
	ind.position = _c2w(home.x, home.y, 0.0) + Vector3(0, base_y, 0)
	add_child(ind)
	var bob := ind.create_tween().set_loops()
	bob.tween_property(ind, "position:y", base_y + 0.9, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(ind, "position:y", base_y, 0.7).set_trans(Tween.TRANS_SINE)
	var fade := ind.create_tween()
	fade.tween_interval(8.0)
	fade.tween_property(ind, "modulate:a", 0.0, 2.0)
	fade.tween_callback(ind.queue_free)

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

# An HBox-ready icon: a painted toy sprite when one exists for `name`, otherwise
# the procedural GlyphIcon. `color` is only used by the glyph fallback (the sprites
# carry their own colour). `px` is the box the icon is fit into.
func _icon(name: String, color: Color, px: int) -> Control:
	if HUD_SPRITES.has(name):
		var t := TextureRect.new()
		t.texture = HUD_SPRITES[name]
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # honour px, not the texture's native size
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	return _glyph(GlyphIcon.new().setup(name, color, px))

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
	row.add_child(_icon(glyph, color, 20))
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

func _hud_panel(pos: Vector2, min_size: Vector2, _radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Painted stone pill frame (9-slice): the blue corner caps + stone border stay fixed
	# while only the navy middle stretches, so every pill matches the framed cards.
	var st := StyleBoxTexture.new()
	st.texture = PANEL_FRAME
	st.texture_margin_left = 20
	st.texture_margin_right = 20
	st.texture_margin_top = 20
	st.texture_margin_bottom = 20
	st.set_content_margin(SIDE_LEFT, 18)
	st.set_content_margin(SIDE_RIGHT, 18)
	st.set_content_margin(SIDE_TOP, 7)
	st.set_content_margin(SIDE_BOTTOM, 7)
	p.add_theme_stylebox_override("panel", st)
	return p

# One leaderboard row: rank · emoji avatar · name · right-aligned %.
# Returns the parts so _hud_tick can repaint them each refresh.
func _make_lb_row() -> Dictionary:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(164, 28)
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
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(row)
	var rank := _hud_text("", 14, Color(1, 1, 1, 0.55))
	rank.custom_minimum_size = Vector2(14, 0)

	# Avatar: small rounded square in the kingdom's color, emoji inside.
	var av_panel := Panel.new()
	av_panel.custom_minimum_size = Vector2(22, 22)
	av_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av_style := StyleBoxFlat.new()
	av_style.bg_color = Color.GRAY
	av_style.set_corner_radius_all(5)
	av_style.border_color = Color(0, 0, 0, 0.4)
	av_style.set_border_width_all(1)
	av_panel.add_theme_stylebox_override("panel", av_style)
	var av_emoji := Label.new()
	av_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av_emoji.add_theme_font_size_override("font_size", 13)
	av_emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_emoji.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	av_panel.add_child(av_emoji)

	var nm := _hud_text("", 14, Color.WHITE)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	var pct := _hud_text("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(36, 0)
	row.add_child(rank)
	row.add_child(av_panel)
	row.add_child(nm)
	row.add_child(pct)
	return {"row": wrap, "bg": bg, "rank": rank, "chip": av_style, "avatar": av_emoji, "name": nm, "pct": pct}

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

# A live value laid right-aligned onto one colour row of the painted stat card.
# yfrac is the row's vertical centre as a fraction of the card height.
func _statcard_value(card: Control, card_w: float, card_h: float, yfrac: float) -> Label:
	var l := _hud_text("0", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.clip_text = true
	# Start past the row icon (~50% of card width) and run to 6px inside the right border.
	var x_start := card_w * 0.50
	l.position = Vector2(x_start, card_h * yfrac - 13.0)
	l.size = Vector2(card_w - x_start - 10.0, 26.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(l)
	return l

func _thin_rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.15)
	r.custom_minimum_size = Vector2(1, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _build_action_stack(ui: CanvasLayer) -> void:
	# y values are from top in the 720-tall design space; convert to bottom-anchored
	# offsets so the stack hugs the lower-left on any screen height.
	var actions := [
		{"text": "BOOST", "glyph": "boost", "cost": 80, "y": 400, "color": Color("123c70")},
		{"text": "SHIELD", "glyph": "shield", "cost": 120, "y": 480, "color": Color("174d7a")},
		{"text": "MAP", "glyph": "map", "cost": 0, "y": 560, "color": Color("17191f")},
	]
	# 80px wide gives "SHIELD" enough room; 68px tall with 5px margins = 58px content,
	# fitting icon(26) + label(~15px) + cost(~13px) = ~54px comfortably.
	const BTN_W := 80
	const BTN_H := 68
	for a in actions:
		var b := Button.new()
		b.custom_minimum_size = Vector2(BTN_W, BTN_H)
		b.set_anchor(SIDE_LEFT, 0.0)
		b.set_anchor(SIDE_RIGHT, 0.0)
		b.set_anchor(SIDE_TOP, 1.0)
		b.set_anchor(SIDE_BOTTOM, 1.0)
		b.set_offset(SIDE_LEFT, 16)
		b.set_offset(SIDE_RIGHT, 16 + BTN_W)
		var from_bottom := 720 - int(a["y"])
		b.set_offset(SIDE_TOP, -from_bottom)
		b.set_offset(SIDE_BOTTOM, -from_bottom + BTN_H)
		_style_button(b, a["color"], 14, 5)
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 1)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon: Control = _icon(a["glyph"], Color.WHITE, 26)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(icon)
		vb.add_child(_hud_text(a["text"], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		if int(a["cost"]) > 0:
			vb.add_child(_hud_text(str(a["cost"]), 10, HUD_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(vb)
		if a["text"] == "MAP":
			_map_btn = b
			b.pressed.connect(_toggle_map_view)
		_hover_lift(b)
		ui.add_child(b)

func _toggle_map_view() -> void:
	if camera == null or camera.intro_active():
		return
	_map_active = not _map_active
	AudioManager.play("tap")
	var tw: Tween = camera.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if _map_active:
		# Center of the 128×96 board in world space (board is centred at origin).
		camera.start_overview(Vector3.ZERO)
		tw.tween_property(camera, "fov", 55.0, 0.6)
	else:
		camera.end_overview()
		# Return to the saved hero/map preference and restore follow offset.
		var hero_off := Vector3(0.0, 12.6, 15.2)
		camera.offset = hero_off
		tw.tween_property(camera, "fov", 46.0, 0.5)
	if _map_btn and is_instance_valid(_map_btn):
		var active_col := Color("2a6b46")   # green tint = map view on
		var idle_col   := Color("17191f")   # dark = normal
		_style_button(_map_btn, active_col if _map_active else idle_col, 14, 5)

func _style_button(b: Button, color: Color, radius: int, margin: int = 8) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(color, 0.92)
	st.border_color = Color(1, 1, 1, 0.16)
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(margin)
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

func _display_kingdom_name(kid: int) -> String:
	return _kid_label.get(kid, FAKE_PLAYER_NAMES[(kid - 1) % FAKE_PLAYER_NAMES.size()])

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
	_minimap.set_active_half(_active_w, _active_h)
	if WORLD_CONQUEST and _land_mask.size() > 0:
		_minimap.set_land_mask(_land_mask)
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
		var agent = _kid_to_agent.get(e["kid"])
		var is_elim: bool = agent != null and agent.eliminated
		var dim: float = 0.38 if is_elim else 1.0
		rr["rank"].text = "" if is_elim else "%d" % (r + 1)
		rr["chip"].bg_color = Color(kc, dim)
		rr["avatar"].text = _kid_avatar.get(e["kid"], "🐱")
		rr["avatar"].modulate = Color(1, 1, 1, dim)
		rr["name"].text = _display_kingdom_name(e["kid"])
		var name_col: Color
		if is_elim:
			name_col = Color(0.55, 0.58, 0.62)
		elif lead or mine:
			name_col = Color.WHITE
		else:
			name_col = Color(0.84, 0.87, 0.91)
		rr["name"].add_theme_color_override("font_color", name_col)
		rr["name"].add_theme_font_override("font",
			ArcadeTheme.font_heavy if (lead or mine) and not is_elim else ArcadeTheme.font)
		rr["bg"].bg_color = (Color(kc, 0.22) if mine and not is_elim else (Color(HUD_GOLD, 0.08) if lead and not is_elim else Color(0, 0, 0, 0)))
		rr["pct"].text = "left" if is_elim else "%.1f%%" % (100.0 * e["n"] / total)
		var pct_col: Color = Color(0.5, 0.52, 0.55) if is_elim else (kc.lightened(0.3) if (lead or mine) else Color(0.84, 0.87, 0.91))
		rr["pct"].add_theme_color_override("font_color", pct_col)

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
	layer.add_child(l)
	l.set_anchor(SIDE_LEFT, 0.0)
	l.set_anchor(SIDE_RIGHT, 1.0)
	l.set_anchor(SIDE_TOP, 1.0)
	l.set_anchor(SIDE_BOTTOM, 1.0)
	l.set_offset(SIDE_LEFT, 18)
	l.set_offset(SIDE_RIGHT, 0)
	l.set_offset(SIDE_TOP, -32)
	l.set_offset(SIDE_BOTTOM, 0)
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

# ── power-up system ───────────────────────────────────────────────────────────

func _pu_is_land(cx: int, cy: int) -> bool:
	if WORLD_CONQUEST and _land_mask.size() > 0:
		return _land_mask[cy * GW + cx] == 1
	return cx >= 0 and cx < GW and cy >= 0 and cy < GH

func _spawn_powerup_wave() -> void:
	var types := [PU_SPEED, PU_GHOST, PU_BOMB, PU_CLEAR, PU_FREEZE, PU_MAGNET]
	var placed := 0
	var attempts := 0
	while placed < PU_PER_WAVE and attempts < 400:
		attempts += 1
		var cx := randi_range(4, GW - 5)
		var cy := randi_range(4, GH - 5)
		var cell := Vector2i(cx, cy)
		if _powerup_cells.has(cell):
			continue
		if not _pu_is_land(cx, cy):
			continue
		var t: String = types[placed % types.size()]
		_powerup_cells[cell] = t
		var node := _make_pu_node(t, cx, cy)
		add_child(node)
		_powerup_nodes[cell] = node
		placed += 1

func _pu_color(type: String) -> Color:
	match type:
		PU_SPEED:  return Color(0.01, 0.40, 0.04)
		PU_GHOST:  return Color(1.0,  0.85, 0.0)
		PU_BOMB:   return Color(1.0,  0.08, 0.05)
		PU_CLEAR:  return Color(0.85, 0.95, 1.0)
		PU_FREEZE: return Color(0.0,  0.75, 1.0)
		PU_MAGNET: return Color(0.85, 0.15, 1.0)
	return Color.WHITE

func _pu_disc_mat(type: String) -> StandardMaterial3D:
	if _pu_disc_mats.has(type):
		return _pu_disc_mats[type]
	var col := _pu_color(type)
	var mat := StandardMaterial3D.new()
	mat.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color             = col
	mat.emission_enabled         = true
	mat.emission                 = col
	mat.emission_energy_multiplier = 1.6
	mat.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode               = BaseMaterial3D.BLEND_MODE_ADD   # additive — no depth sort
	_pu_disc_mats[type] = mat
	return mat

func _make_pu_node(type: String, cx: int, cy: int) -> Node3D:
	var root := Node3D.new()
	root.position = _c2w(cx, cy, CLAIMED_LIFT + 0.45)
	var col := _pu_color(type)

	# ── ground glow disc (shared mesh + cached material per type) ────────────
	if _pu_disc_mesh == null:
		_pu_disc_mesh = CylinderMesh.new()
		_pu_disc_mesh.top_radius      = 0.50
		_pu_disc_mesh.bottom_radius   = 0.50
		_pu_disc_mesh.height          = 0.02
		_pu_disc_mesh.radial_segments = 16
	var disc := MeshInstance3D.new()
	disc.mesh = _pu_disc_mesh
	disc.set_surface_override_material(0, _pu_disc_mat(type))
	disc.position.y = -(CLAIMED_LIFT + 0.44)
	root.add_child(disc)

	var pulse := disc.create_tween()
	pulse.set_loops()
	pulse.tween_property(disc, "scale", Vector3(1.25, 1.0, 1.25), 0.55).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(disc, "scale", Vector3(0.85, 1.0, 0.85), 0.55).set_trans(Tween.TRANS_SINE)

	# ── 3D model ─────────────────────────────────────────────────────────────
	var scene: PackedScene = PU_SCENES.get(type)
	var model: Node3D
	if scene:
		model = scene.instantiate()
	else:
		var fallback := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.36; sph.height = 0.72
		fallback.mesh = sph
		model = fallback
	model.scale = Vector3.ONE * 3.0
	root.add_child(model)

	# ── beacon light ─────────────────────────────────────────────────────────
	# Dynamic OmniLights are the priciest scene element on the mobile renderer.
	# Up to PU_PER_WAVE are active at once — skip on low_gfx. The emissive glow
	# disc above already makes each pickup readable from above without a real light.
	if not DeviceMode.low_gfx:
		var light := OmniLight3D.new()
		light.light_color  = col
		light.omni_range   = 4.0
		light.light_energy = 1.8
		root.add_child(light)

	# ── bob + spin ───────────────────────────────────────────────────────────
	var bob := root.create_tween()
	bob.set_loops()
	bob.tween_property(root, "position:y", root.position.y + 0.18, 0.65).set_trans(Tween.TRANS_SINE)
	bob.tween_property(root, "position:y", root.position.y,         0.65).set_trans(Tween.TRANS_SINE)

	var spin := model.create_tween()
	spin.set_loops()
	spin.tween_property(model, "rotation:y", TAU, 2.8).set_trans(Tween.TRANS_LINEAR)

	return root

const PU_PICKUP_RADIUS := 2   # cells — grab a powerup within this Chebyshev distance

func _check_powerup_pickup(a, cell: Vector2i) -> void:
	for pc in _powerup_cells.keys():
		if absi(cell.x - pc.x) <= PU_PICKUP_RADIUS and absi(cell.y - pc.y) <= PU_PICKUP_RADIUS:
			var type: String = _powerup_cells[pc]
			_powerup_cells.erase(pc)
			var node: Node3D = _powerup_nodes.get(pc)
			_powerup_nodes.erase(pc)
			if node and is_instance_valid(node):
				node.queue_free()
			_apply_powerup(a, type)
			return   # one pickup per step

func _apply_powerup(a, type: String) -> void:
	match type:
		PU_SPEED:
			if a.base_speed == 0.0:
				a.base_speed = a.avatar.speed
			a.avatar.speed = a.base_speed + PU_SPEED_BOOST
			a.powerup_type = PU_SPEED
			a.powerup_t    = PU_SPEED_DUR
		PU_GHOST:
			a.powerup_type = PU_GHOST
			a.powerup_t    = PU_GHOST_DUR
			grid.ghost_kids[a.kid] = true
		PU_BOMB:
			_apply_bomb(a)
			return
		PU_CLEAR:
			_apply_clear(a)
			return
		PU_FREEZE:
			_freeze_t  = PU_FREEZE_DUR
			_freeze_by = a.kid
			a.powerup_type = PU_FREEZE
			a.powerup_t    = PU_FREEZE_DUR
		PU_MAGNET:
			_apply_magnet(a)
			return
	if not a.is_ai:
		var label := ""
		match type:
			PU_SPEED:  label = "Speed Burst!  +%.0fs" % PU_SPEED_DUR
			PU_GHOST:  label = "Ghost Trail!  +%.0fs" % PU_GHOST_DUR
			PU_FREEZE: label = "Enemies Frozen!  +%.0fs" % PU_FREEZE_DUR
		_toast(label, Color(1.0, 0.95, 0.3))

func _apply_bomb(a) -> void:
	var cx: int = a.last_cell.x
	var cy: int = a.last_cell.y
	var cap: int = grid.bomb_capture(a.kid, cx, cy, PU_BOMB_RADIUS)
	if cap > 0:
		var r := PU_BOMB_RADIUS
		renderer.flash_cells(
			Vector2i(cx - r, cy - r),
			Vector2i(cx + r, cy + r),
			_kid_color[a.kid])
		if not a.is_ai:
			_toast("Land Bomb!  +%d cells" % cap, Color(1.0, 0.5, 0.1))
			camera.shake(0.18)
		if _fx and _fx_cooldown <= 0.0:
			_fx_cooldown = 0.18
			_fx.burst(_c2w(cx, cy, 0.0), _kid_color[a.kid])

func _apply_clear(a) -> void:
	grid.clear_trail(a.kid)
	if not a.is_ai:
		_toast("Trail Erased!", Color(0.9, 0.95, 1.0))

func _apply_magnet(a) -> void:
	var cx: int = a.last_cell.x
	var cy: int = a.last_cell.y
	var cap: int = grid.magnet_capture(a.kid, cx, cy, PU_MAGNET_RADIUS)
	if cap > 0:
		var r := PU_MAGNET_RADIUS
		renderer.flash_cells(
			Vector2i(cx - r, cy - r),
			Vector2i(cx + r, cy + r),
			_kid_color[a.kid])
		if not a.is_ai:
			_toast("Magnet!  +%d cells" % cap, Color(0.8, 0.3, 1.0))
		if _fx and _fx_cooldown <= 0.0:
			_fx_cooldown = 0.18
			_fx.burst(_c2w(cx, cy, 0.0), _kid_color[a.kid])

func _tick_powerups(delta: float) -> void:
	for a in _rulers:
		if a.powerup_t <= 0.0:
			continue
		a.powerup_t -= delta
		if a.powerup_t <= 0.0:
			a.powerup_t = 0.0
			_expire_powerup(a)

func _expire_powerup(a) -> void:
	match a.powerup_type:
		PU_SPEED:
			a.avatar.speed = a.base_speed if a.base_speed > 0.0 else (HUMAN_SPEED if not a.is_ai else AI_SPEED)
			a.base_speed = 0.0
		PU_GHOST:
			grid.ghost_kids.erase(a.kid)
		PU_FREEZE:
			_freeze_t  = 0.0
			_freeze_by = 0
	a.powerup_type = ""

func _dbg_tick(delta: float) -> void:
	_dbg_t -= delta
	if _dbg_t > 0.0:
		return
	_dbg_t = 1.5
	var parts: Array = []
	for kid in _kids:
		parts.append("k%d=%d" % [kid, grid.territory_count(kid)])
	print("[dbg] ", " ".join(parts))
