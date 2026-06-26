extends Node3D

# ── Countryside decoration on claimed land ────────────────────────────────────
# Populace fills the dense town CORE (houses/citizens/towers); this layer dresses
# the sparser MID/OUTER bands so a big realm reads as a living countryside, not a
# bare coloured plate: tilled FARM fields + bright FLOWER patches. Same engine as
# populace — every owned cell hashed (stable, position-based) into a prop, two
# MultiMesh batches, and a per-instance pop-in (custom-data .r = spawn time) so a
# field/flower-bed visibly springs up on the tick its cell is claimed. Natural
# colours (not kingdom-tinted) so they read as countryside and need no recolour on
# conquest. Zero per-frame CPU; rebuilt on the throttled dirty tick.

var grid
var cell: float = 0.6
var _homes := {}
var _seen := {}              # cell index -> spawn time (sec), stable: pops once
var _first := true

const PROP_Y := 0.075
const POP_DUR := 0.30
const CORE_R := 9            # inside this = town core (populace owns it), skip here
const FARM_MAX := 46         # farms ring the town, not the deep outskirts
const FARM_CAP := 520
const FLOWER_CAP := 1000
const FLOWER_COLORS := [
	Color("ff6f91"), Color("ffd23f"), Color("ffffff"), Color("ff5d5d"),
	Color("c9a6ff"), Color("6fd0ff"),
]

const FARM_SHADER := """
shader_type spatial;
render_mode cull_back;
void vertex() {
	float spawn = INSTANCE_CUSTOM.r;
	float s = 1.0;
	if (spawn > 0.0) {
		float t = clamp((TIME - spawn) / 0.30, 0.0, 1.0);
		float p = t - 1.0;
		s = 1.0 + 2.70158 * p * p * p + 1.70158 * p * p;
	}
	VERTEX *= s;
}
void fragment() {
	// alternating tilled rows: earth / crop
	float rows = step(0.5, fract(UV.x * 5.0));
	vec3 earth = vec3(0.44, 0.31, 0.18);
	vec3 crop  = vec3(0.40, 0.60, 0.23);
	ALBEDO = mix(earth, crop, rows);
	ROUGHNESS = 0.95;
}
"""

const FLOWER_SHADER := """
shader_type spatial;
render_mode cull_back;
void vertex() {
	float spawn = INSTANCE_CUSTOM.r;
	float s = 1.0;
	if (spawn > 0.0) {
		float t = clamp((TIME - spawn) / 0.30, 0.0, 1.0);
		float p = t - 1.0;
		s = 1.0 + 2.70158 * p * p * p + 1.70158 * p * p;
	}
	VERTEX *= s;
	// gentle sway so the beds shimmer
	vec3 wp = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * 2.2 + wp.x * 1.5 + wp.z) * 0.02 * (VERTEX.y + 0.1);
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.7;
}
"""

var _farm: MultiMeshInstance3D
var _flower: MultiMeshInstance3D

func setup(p_grid, p_cell: float, p_homes: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	_homes = p_homes
	var farm_mesh := PlaneMesh.new()      # lies flat, normal +Y, UV 0..1 → row stripes
	farm_mesh.size = Vector2(cell * 0.92, cell * 0.92)
	_farm = _batch(farm_mesh, FARM_SHADER)
	var flower_mesh := SphereMesh.new()   # a squashed bloom-cluster blob
	flower_mesh.radius = 0.14
	flower_mesh.height = 0.22
	flower_mesh.radial_segments = 6
	flower_mesh.rings = 3
	_flower = _batch(flower_mesh, FLOWER_SHADER)
	add_child(_farm)
	add_child(_flower)

func _batch(mesh: Mesh, code: String) -> MultiMeshInstance3D:
	var sh := Shader.new()
	sh.code = code
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

func _spawn_for(i: int, now: float) -> float:
	if _seen.has(i):
		return _seen[i]
	_seen[i] = now
	return now

# Countryside is a Village-and-up luxury: a bare Outpost (T1) has no farms/flowers;
# they bloom in once the kingdom reaches T2, reinforcing the level-up.
const MIN_TIER := 2

func rebuild(tiers: Dictionary = {}) -> void:
	var w: int = grid.w
	var n: int = w * grid.h
	var now: float = 0.0 if _first else float(Time.get_ticks_msec()) * 0.001
	var cap_mul: float = 0.5 if DeviceMode.is_mobile else 1.0
	var farm_cap := int(FARM_CAP * cap_mul)
	var flower_cap := int(FLOWER_CAP * cap_mul)
	var farm_xf := []
	var farm_spawn := PackedFloat32Array()
	var fl_pos := PackedVector3Array()
	var fl_col := PackedColorArray()
	var fl_spawn := PackedFloat32Array()
	for i in n:
		var oid: int = grid.owner[i]
		if oid == 0:
			continue
		if int(tiers.get(oid, 1)) < MIN_TIER:
			continue                         # Outpost: no countryside yet
		var cx: int = i % w
		var cy: int = i / w
		var home: Vector2i = _homes.get(oid, Vector2i(cx, cy))
		var d: int = absi(cx - home.x) + absi(cy - home.y)
		if d <= 3:
			continue                         # leave the immediate keep clear
		var base: Vector3 = _c2w(cx, cy)
		# Farms ring the town (mid band); a separate hash keeps them off house cells.
		if d > CORE_R and d <= FARM_MAX and farm_xf.size() < farm_cap:
			var fb: int = ((i * 2654435761) & 0x7fffffff) % 1000
			if fb < 48:
				var ang := 0.0 if ((i * 40503) & 1) == 0 else PI * 0.5
				var b := Basis(Vector3.UP, ang)
				farm_xf.append(Transform3D(b, base + Vector3(0, PROP_Y, 0)))
				farm_spawn.append(_spawn_for(i, now))
				continue
		# Flowers anywhere owned (skip core houses by hash); bright, varied.
		if fl_pos.size() < flower_cap:
			var pb: int = ((i * 1103515245 + 12345) & 0x7fffffff) % 1000
			if pb < 34:
				fl_pos.append(base + Vector3(0, PROP_Y + 0.1, 0))
				fl_col.append(FLOWER_COLORS[((i * 2246822519) & 0x7fffffff) % FLOWER_COLORS.size()])
				fl_spawn.append(_spawn_for(i, now))
	_fill_xf(_farm, farm_xf, farm_spawn)
	_fill(_flower, fl_pos, fl_col, fl_spawn)
	_first = false

func _fill_xf(mmi: MultiMeshInstance3D, xforms: Array, spawns: PackedFloat32Array) -> void:
	var mm := mmi.multimesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		mm.set_instance_color(k, Color.WHITE)
		mm.set_instance_custom_data(k, Color(spawns[k], 0.0, 0.0, 0.0))

func _fill(mmi: MultiMeshInstance3D, positions: PackedVector3Array, cols: PackedColorArray,
		spawns: PackedFloat32Array) -> void:
	var mm := mmi.multimesh
	mm.instance_count = positions.size()
	for k in positions.size():
		mm.set_instance_transform(k, Transform3D(Basis(), positions[k]))
		mm.set_instance_color(k, cols[k])
		mm.set_instance_custom_data(k, Color(spawns[k], 0.0, 0.0, 0.0))

func _c2w(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5 - grid.w * 0.5) * cell, 0.0, (cy + 0.5 - grid.h * 0.5) * cell)
