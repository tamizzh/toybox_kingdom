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
var _kingdom_t := 0.0
var _terr_rebuild_t := 0.0

var _ended := false
var _match_t := MATCH_DURATION
var _ui_layer: CanvasLayer

var _terr_label: Label
var _time_label: Label
var _lb_rows: Array = []        # Array[Label]
var _hud_t := 0.0

var _dbg := false
var _dbg_t := 0.0

func _ready() -> void:
	_dbg = OS.get_environment("TBK_DEBUG") == "1"
	var fast := OS.get_environment("TBK_FASTMATCH")
	if fast != "":
		_match_t = float(fast)
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
	# Borders are now part of the clay (raised plateau + seam AO in the ground
	# shader) — no more crenellated wall cubes ringing every region.

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
	camera.offset = Vector3(0.0, 13.0, 11.0)   # closer ~50° follow
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
	av.global_position = _c2w(home.x, home.y, 0.0)
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
	if n < 160:
		return 1
	elif n < 380:
		return 2
	elif n < 720:
		return 3
	return 4

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
		if a.castle == null or a.eliminated:
			continue
		var new_tier := _castle_tier(grid.territory_count(a.kid))
		if new_tier != a.castle.tier:
			a.castle.update_tier(new_tier)
			if not a.is_ai:
				AudioManager.play("round_win")   # your kingdom leveled up

	_check_conquests()
	_check_eliminations()
	_check_match_end()

# If a kingdom's castle cell has been claimed by a rival, the whole kingdom falls
# to that rival — BUT only if the attacker's castle is at least as high a level as
# the defender's. A weaker attacker can't take the castle: it defends + reclaims
# its core.
func _check_conquests() -> void:
	for a in _rulers:
		if a.eliminated:
			continue
		var ho: int = grid.get_owner(a.home.x, a.home.y)
		if ho == a.kid or ho == 0:
			continue
		var conq = _kid_to_agent.get(ho)
		var def_tier: int = a.castle.tier if a.castle != null else 1
		var conq_tier: int = conq.castle.tier if (conq != null and conq.castle != null) else 1
		if conq_tier >= def_tier:
			grid.transfer_all(a.kid, ho)
			_toast("%s conquered %s!" % [_kid_name.get(ho, "?"), _kid_name[a.kid]],
				_kid_color.get(ho, Color.WHITE))
		else:
			# castle out-levels the attacker -> it holds and reclaims its core
			grid.seed_kingdom(a.kid, a.home.x, a.home.y, HOME_R)
			if a == _rulers[0] or conq == _rulers[0]:
				_toast("%s's castle held!" % _kid_name[a.kid], _kid_color[a.kid])

# A kingdom whose territory hits zero is conquered for good.
func _check_eliminations() -> void:
	for a in _rulers:
		if a.eliminated:
			continue
		if grid.territory_count(a.kid) == 0:
			a.eliminated = true
			a.alive = false
			grid.clear_trail(a.kid)
			if a.avatar:
				a.avatar.visible = false
			if a.castle:
				a.castle.visible = false
			if a.name_tag:
				a.name_tag.visible = false
			if a != _rulers[0]:
				_toast("%s's kingdom has fallen!" % _kid_name[a.kid], _kid_color[a.kid])

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
				elif victim == _rulers[0]:
					_toast("%s popped you!" % _kid_name[a.kid], Palette.DANGER)
		if res.get("died", false):
			_kill(a)
			return
		if int(res.get("captured", 0)) > 0:
			renderer.flash_cells(res.get("cmin", Vector2i(0, 0)), res.get("cmax", Vector2i(-1, 0)),
				_kid_color[a.kid])
			if not a.is_ai:
				AudioManager.play("go")

func _kill(a) -> void:
	a.alive = false
	a.respawn_t = RESPAWN_TIME
	if a.avatar:
		a.avatar.set_dead()

func _respawn(a) -> void:
	# No land left to respawn onto -> elimination is handled in _kingdom_tick.
	if grid.territory_count(a.kid) == 0:
		return
	a.avatar.revive(_c2w(a.home.x, a.home.y, 0.0))
	a.avatar.collision_layer = 0
	a.avatar.collision_mask = 0
	a.last_cell = a.home
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
const KINGDOM_COLORS := [
	Color("1365d3"), Color("d33921"), Color("679d11"), Color("e8ab0a"),
	Color("803dba"), Color("2ba5ac"), Color("e7740b"), Color("e85379"),
]

func _kingdom_color(i: int, n: int) -> Color:
	return KINGDOM_COLORS[i % KINGDOM_COLORS.size()]

# ── world dressing ────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c2733")   # deep teal sea framing the clay continent
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d4e2ec")  # soft sky fill
	env.ambient_light_energy = 0.32           # lower = richer, less washed colours
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.0
	env.ssao_enabled = true                  # deepen clay crevices + cell seams
	env.ssao_intensity = 2.8
	env.ssao_radius = 0.6
	env.ssao_power = 2.2
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.99
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.30         # punchy toy colours
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# warm key for a sunny tabletop; soft long shadows sell the clay relief
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -42, 0)
	key.light_color = Color("fff0d2")
	key.light_energy = 1.1
	key.shadow_enabled = true
	key.shadow_opacity = 0.55
	key.shadow_blur = 2.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-36, 138, 0)
	fill.light_color = Color("bfd6ff")
	fill.light_energy = 0.22
	add_child(fill)

const WATER_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 col_a : source_color = vec3(0.10, 0.32, 0.40);
uniform vec3 col_b : source_color = vec3(0.05, 0.18, 0.26);
void vertex() {
	float w = sin(VERTEX.x * 0.4 + TIME * 1.4) + cos(VERTEX.z * 0.4 + TIME * 1.1);
	VERTEX.y += w * 0.04;
}
void fragment() {
	float t = 0.5 + 0.5 * sin(UV.x * 26.0 + TIME) * cos(UV.y * 26.0 - TIME * 0.7);
	ALBEDO = mix(col_b, col_a, t * 0.6);   // gentler ripple contrast
	ROUGHNESS = 0.5;
	SPECULAR = 0.25;
}
"""

func _build_ground() -> void:
	var wx := GW * CELL
	var wz := GH * CELL

	# water all around — gentle animated shader; the kingdoms sit on an island.
	var water := MeshInstance3D.new()
	var wpm := PlaneMesh.new()
	wpm.size = Vector2(wx + 140.0, wz + 140.0)
	water.mesh = wpm
	var wmat := ShaderMaterial.new()
	var wsh := Shader.new()
	wsh.code = WATER_SHADER
	wmat.shader = wsh
	water.material_override = wmat
	water.position = Vector3(0, -0.55, 0)
	add_child(water)

	# Continent BASE: a rounded-rectangle sandy island the clay plateau sits on,
	# giving it thickness + a beach/cliff down to the water (Blender bevelled mesh
	# so the corners are round, not a sharp box).
	var island_scene := load("res://assets/models/island.glb")
	if island_scene:
		var island = island_scene.instantiate()
		add_child(island)
		var sxz := (wx + 4.0) / 16.0          # island model is 16 x 12 wide
		island.scale = Vector3(sxz, 0.7, sxz)
		island.position = Vector3(0, 0.04 - 0.35, 0)   # top ~y=0.04 under the clay plane
		var sandy := StandardMaterial3D.new()
		sandy.albedo_color = Color("c0ad7a")   # sandy shoreline
		sandy.roughness = 1.0
		for mi in island.find_children("", "MeshInstance3D", true, false):
			mi.material_override = sandy

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
	# camera pulls back as your realm grows
	var owned: int = grid.territory_count(_rulers[0].kid)
	camera.zoom = clampf(1.0 + sqrt(float(owned)) / 22.0, 1.0, 2.0)

	_hud_t -= delta
	if _hud_t > 0.0:
		return
	_hud_t = 0.2

	var total := float(GW * GH)
	_terr_label.text = "Your territory  %.1f%%   ·   %d tiles" % [100.0 * owned / total, owned]

	var secs := int(ceil(_match_t))
	_time_label.text = "%d:%02d" % [secs / 60, secs % 60]

	var standings: Array = []
	for kid in _kids:
		standings.append({"kid": kid, "n": grid.territory_count(kid)})
	standings.sort_custom(func(x, y): return x["n"] > y["n"])
	for r in _lb_rows.size():
		var e: Dictionary = standings[r]
		var row: Label = _lb_rows[r]
		row.text = "%d. %s  %.1f%%" % [r + 1, _kid_name[e["kid"]], 100.0 * e["n"] / total]
		row.add_theme_color_override("font_color", _kid_color[e["kid"]])

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
