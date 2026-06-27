extends Node3D

# ── The "comes alive" layer: claimed land becomes a populated town ────────────
# Every owned cell is hashed (stable, position-based) into one of: house, citizen,
# or empty. So buildings appear exactly where you claim, never move, and recolour
# to the conqueror when land is taken. Three MultiMesh batches (house body, roof,
# citizen) keep it to a few draw calls; citizens bob via a vertex shader = zero CPU.
#
# POP-IN: each instance carries its spawn-time in MultiMesh custom-data .r; a vertex
# shader scales it 0→1 with an ease-out-back overshoot over POP_DUR seconds. So a
# building that first appears on a capture tick visibly *pops up* out of the ground,
# while the town that already exists stays put — the whole settlement keeps growing
# as you claim land, with no per-instance CPU work (the GPU reads TIME each frame).

const HOUSE_GLB := "res://assets/models/house.glb"

var grid
var cell: float = 0.6
var colors := {}
var _homes := {}             # kid -> Vector2i home cell (villages cluster here)
var _seen := {}              # cell index -> spawn time (sec); stable so it pops once
var _first := true           # first rebuild = no pop (match-start town appears instantly)

const PROP_Y := 0.07         # sit on the flat land slab
const POP_DUR := 0.30        # seconds for a freshly-claimed building to pop up
# Density buckets (out of 1000) by Manhattan distance from the kingdom's castle:
# dense village core near home, thinning to sparse outskirts near the border.
const CORE_R := 9
const MID_R := 20
const HOUSE_CAP := 1000      # instance caps (one draw call each, but keep tris sane)
const CIT_CAP := 600
const TOWER_CAP := 360       # sparse kingdom towers give the target's studded skyline

# One shader for every town prop: a pop-in scale from custom-data .r (spawn time),
# plus an optional idle bob (citizens). Matte plastic-clay finish to match the board.
const BUILD_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float bob_amt = 0.0;
uniform float pop_dur = 0.30;
uniform float rough = 0.9;
uniform float spec = 0.1;
uniform float to_linear = 0.0;   // 1.0 = convert COLOR sRGB->linear (matches StandardMaterial3D albedo)
void vertex() {
	// pop-in: custom-data .r holds the spawn time (sec). 0 = pre-existing, no pop.
	float spawn = INSTANCE_CUSTOM.r;
	float s = 1.0;
	if (spawn > 0.0) {
		float t = clamp((TIME - spawn) / pop_dur, 0.0, 1.0);
		float p = t - 1.0;
		s = 1.0 + 2.70158 * p * p * p + 1.70158 * p * p;   // ease-out-back overshoot
	}
	VERTEX *= s;
	if (bob_amt > 0.0) {
		vec3 wp = MODEL_MATRIX[3].xyz;
		float ph = wp.x * 2.7 + wp.z * 1.9;
		VERTEX.y += sin(TIME * 3.5 + ph) * bob_amt;
	}
}
void fragment() {
	vec3 c = COLOR.rgb;
	// StandardMaterial3D converts albedo sRGB->linear; the windmill cap does too. The roof
	// opts in (to_linear=1) so its kingdom colour lands on the exact same tone as the cap.
	vec3 lin = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
	ALBEDO = mix(c, lin, to_linear);
	ROUGHNESS = rough;      // matte clay by default; roof overrides to the windmill-cap finish
	SPECULAR = spec;
}
"""

var _body: MultiMeshInstance3D
var _roof: MultiMeshInstance3D
var _fence: MultiMeshInstance3D       # picket fence surrounding each house (warm wood brown)
var _cit: MultiMeshInstance3D
var _tower: MultiMeshInstance3D       # tall kingdom-coloured keep tower
var _tower_roof: MultiMeshInstance3D  # its pointed roof

func setup(p_grid, p_cell: float, p_colors: Dictionary, p_homes: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	colors = p_colors
	_homes = p_homes
	var body_mesh: Mesh
	var roof_mesh: Mesh
	var fence_mesh: Mesh
	# Load house GLB (body + roof + fence submeshes). Falls back to primitives.
	var glb = load(HOUSE_GLB) as PackedScene
	if glb != null:
		var s := glb.instantiate()
		var bmi := s.find_child("body",  true, false) as MeshInstance3D
		var rmi := s.find_child("roof",  true, false) as MeshInstance3D
		var fmi := s.find_child("fence", true, false) as MeshInstance3D
		if bmi: body_mesh  = bmi.mesh
		if rmi: roof_mesh  = rmi.mesh
		if fmi: fence_mesh = fmi.mesh
		s.free()
	if body_mesh == null:
		var bm := BoxMesh.new()
		bm.size = Vector3(cell * 0.76, 0.66, cell * 0.76)
		body_mesh = bm
	if roof_mesh == null:
		var pm := PrismMesh.new()
		pm.size = Vector3(cell * 1.06, 0.46, cell * 1.07)
		roof_mesh = pm
	if fence_mesh == null:
		var fm := BoxMesh.new()
		fm.size = Vector3(cell * 0.96, 0.25, cell * 0.96)
		fence_mesh = fm
	_body  = _batch(body_mesh,  0.0, true)
	_roof  = _batch(roof_mesh,  0.0, false, 0.8, 0.5, 1.0)
	_fence = _batch(fence_mesh, 0.0, false)
	var cit_mesh := SphereMesh.new()    # cute low-poly blob citizen (mobile-cheap)
	cit_mesh.radius = 0.15
	cit_mesh.height = 0.26
	cit_mesh.radial_segments = 7
	cit_mesh.rings = 4
	_cit = _batch(cit_mesh, 0.05)       # citizens bob
	# Towers: a tall thin keep (cream stone) topped by a kingdom-coloured spire.
	var tower_mesh := BoxMesh.new()
	tower_mesh.size = Vector3(cell * 0.5, 1.3, cell * 0.5)
	_tower = _batch(tower_mesh, 0.0, true)   # tall keeps cast a long grounding shadow
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.0
	spire_mesh.bottom_radius = cell * 0.42
	spire_mesh.height = 0.62
	spire_mesh.radial_segments = 6
	_tower_roof = _batch(spire_mesh, 0.0)
	add_child(_body)
	add_child(_roof)
	add_child(_fence)
	add_child(_cit)
	add_child(_tower)
	add_child(_tower_roof)

func _batch(mesh: Mesh, bob: float, cast: bool = false, rough: float = 0.9, spec: float = 0.1, to_linear: float = 0.0) -> MultiMeshInstance3D:
	var sh := Shader.new()
	sh.code = BUILD_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("bob_amt", bob)
	sm.set_shader_parameter("pop_dur", POP_DUR)
	sm.set_shader_parameter("rough", rough)
	sm.set_shader_parameter("spec", spec)
	sm.set_shader_parameter("to_linear", to_linear)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true      # .r = spawn time, drives the pop-in scale
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = sm
	# Only the major structures cast (houses/towers), and only off-mobile — thousands
	# of casters × cascades is too heavy for phones, where the contact look comes from
	# the strong key shadow on the castle + the clay seam AO instead.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		if (cast and not DeviceMode.is_mobile) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

# Spawn time for a cell: recorded the first time it becomes a building, then stable
# (so it pops once and never re-pops on later ticks / conquests). now==0 → no pop.
func _spawn_for(i: int, now: float) -> float:
	if _seen.has(i):
		return _seen[i]
	_seen[i] = now
	return now

# Town thickens with the castle tier: an Outpost is a sparse cluster, a Capital is
# crowded. Towers (the studded keep skyline) only appear once a kingdom is a Town (T3).
const TIER_DENSITY := {1: 0.62, 2: 0.85, 3: 1.0, 4: 1.18, 5: 1.38, 6: 1.55}
const TOWER_MIN_TIER := 3

func rebuild(tiers: Dictionary = {}) -> void:
	var w: int = grid.w
	var n: int = w * grid.h
	# First rebuild seeds the starting town instantly (now=0 → no pop); after that,
	# freshly-claimed buildings carry the real wall-clock so they pop up on capture.
	var now: float = 0.0 if _first else float(Time.get_ticks_msec()) * 0.001
	# Phones thin the densest town layers (houses/citizens/towers) to keep vertex +
	# overdraw cost down — the village still reads, just less crowded.
	var cap_mul: float = 0.55 if DeviceMode.is_mobile else 1.0
	var house_cap := int(HOUSE_CAP * cap_mul)
	var cit_cap := int(CIT_CAP * cap_mul)
	var tower_cap := int(TOWER_CAP * cap_mul)
	# Packed arrays (not Variant Array) so this hot full-board rebuild stays
	# allocation-light — no per-element Variant boxing or GC churn.
	var house_pos := PackedVector3Array()
	var house_col := PackedColorArray()
	var house_spawn := PackedFloat32Array()
	var cit_pos := PackedVector3Array()
	var cit_col := PackedColorArray()
	var cit_spawn := PackedFloat32Array()
	var tower_pos := PackedVector3Array()
	var tower_col := PackedColorArray()
	var tower_spawn := PackedFloat32Array()
	for i in n:
		var oid: int = grid.owner[i]
		if oid == 0:
			continue
		var cx: int = i % w
		var cy: int = i / w
		# Cluster density by distance from this kingdom's castle.
		var home: Vector2i = _homes.get(oid, Vector2i(cx, cy))
		var d: int = absi(cx - home.x) + absi(cy - home.y)
		var base: Vector3 = _c2w(cx, cy)
		var col: Color = colors.get(oid, Color.WHITE)
		var tier: int = tiers.get(oid, 1)
		var dens: float = TIER_DENSITY.get(tier, 1.0)
		# Sparse towers (separate hash) in the core/mid ring → studded skyline. Only a
		# Town (T3+) sprouts keep towers; lower tiers stay low-rise.
		var tbucket: int = ((i * 2246822519) & 0x7fffffff) % 1000
		var tower_thr: int = 0
		if tier >= TOWER_MIN_TIER:
			tower_thr = 14 if d <= CORE_R else (6 if d <= MID_R else 0)
		if tower_thr > 0 and tbucket < tower_thr and tower_pos.size() < tower_cap:
			tower_pos.append(base)
			tower_col.append(col)
			tower_spawn.append(_spawn_for(i, now))
			continue
		var bucket: int = ((i * 1103515245 + 12345) & 0x7fffffff) % 1000
		var house_thr: int
		var cit_thr: int
		if d <= CORE_R:
			house_thr = 55; cit_thr = 120        # dense village core
		elif d <= MID_R:
			house_thr = 25; cit_thr = 65
		else:
			house_thr = 7; cit_thr = 22          # sparse outskirts
		# Town crowds up as the kingdom levels (Outpost sparse → Capital busy).
		house_thr = int(house_thr * dens)
		cit_thr = int(cit_thr * dens)
		if bucket >= cit_thr:
			continue
		if bucket < house_thr:
			if house_pos.size() < house_cap:
				house_pos.append(base)
				house_col.append(col)
				house_spawn.append(_spawn_for(i, now))
		elif cit_pos.size() < cit_cap:
			# Stagger: offset X/Z within the cell using stable per-cell hashes so
			# citizens don't land on a uniform grid. Max ±35% of a cell in each axis.
			var jx: float = (((i * 374761393 + 6271) & 0x7fffffff) % 1000) / 1000.0 - 0.5
			var jz: float = (((i * 1664525 + 1013904223) & 0x7fffffff) % 1000) / 1000.0 - 0.5
			var jpos := base + Vector3(jx * cell * 0.7, 0.0, jz * cell * 0.7)
			cit_pos.append(jpos)
			cit_col.append(col)
			cit_spawn.append(_spawn_for(i, now))

	# body BH=0.330 → centre +0.330; roof RHH=0.230 → centre 0.660+0.230=0.890; fence FHALF=0.125
	_fill(_body,  house_pos, house_col, house_spawn, Vector3(0, PROP_Y + 0.330, 0), Color("f1d8a0"),   true)
	_fill(_roof,  house_pos, house_col, house_spawn, Vector3(0, PROP_Y + 0.890, 0), Color.WHITE,       false)
	_fill(_fence, house_pos, house_col, house_spawn, Vector3(0, PROP_Y + 0.125, 0), Color("6E3F14"),   true)
	_fill(_cit, cit_pos, cit_col, cit_spawn, Vector3(0, PROP_Y + 0.25, 0), Color.WHITE, false)
	# Tower keep = cream stone; spire = kingdom colour, perched on top.
	_fill(_tower, tower_pos, tower_col, tower_spawn, Vector3(0, PROP_Y + 0.65, 0), Color("e9d6ad"), true)
	_fill(_tower_roof, tower_pos, tower_col, tower_spawn, Vector3(0, PROP_Y + 1.61, 0), Color.WHITE, false)
	_first = false

func _fill(mmi: MultiMeshInstance3D, positions: PackedVector3Array, cols: PackedColorArray,
		spawns: PackedFloat32Array, y_off: Vector3, const_col: Color, use_const: bool) -> void:
	var mm := mmi.multimesh
	mm.instance_count = positions.size()
	for k in positions.size():
		mm.set_instance_transform(k, Transform3D(Basis(), positions[k] + y_off))
		mm.set_instance_color(k, const_col if use_const else cols[k])
		mm.set_instance_custom_data(k, Color(spawns[k], 0.0, 0.0, 0.0))

func _c2w(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5 - grid.w * 0.5) * cell, 0.0, (cy + 0.5 - grid.h * 0.5) * cell)

# Returns a representative sample of house/tower world positions for the road generator.
# Mirrors the exact same hash logic as rebuild() so positions are stable and consistent.
func get_road_nodes(kid: int, tier: int) -> Dictionary:
	var w: int = grid.w
	var n: int = w * grid.h
	var dens: float = TIER_DENSITY.get(tier, 1.0)
	var home: Vector2i = _homes.get(kid, Vector2i(w / 2, grid.h / 2))
	var houses := PackedVector3Array()
	var towers  := PackedVector3Array()
	# Roads only need a representative sample, not the full MultiMesh count
	var hlimit := 16 if not DeviceMode.is_mobile else 10
	var tlimit := 6
	for i in n:
		if grid.owner[i] != kid: continue
		var cx: int = i % w; var cy: int = i / w
		var d: int = absi(cx - home.x) + absi(cy - home.y)
		var tbucket: int = ((i * 2246822519) & 0x7fffffff) % 1000
		var tower_thr: int = 0
		if tier >= TOWER_MIN_TIER:
			tower_thr = 14 if d <= CORE_R else (6 if d <= MID_R else 0)
		if tower_thr > 0 and tbucket < tower_thr and towers.size() < tlimit:
			towers.append(_c2w(cx, cy)); continue
		var bucket: int = ((i * 1103515245 + 12345) & 0x7fffffff) % 1000
		var hthr: int = int((66 if d <= CORE_R else (32 if d <= MID_R else 9)) * dens)
		if bucket < hthr and houses.size() < hlimit:
			houses.append(_c2w(cx, cy))
	return {"houses": houses, "towers": towers}
