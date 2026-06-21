extends Node3D

# ── The "comes alive" layer: claimed land becomes a populated town ────────────
# Every owned cell is hashed (stable, position-based) into one of: house, citizen,
# or empty. So buildings appear exactly where you claim, never move, and recolour
# to the conqueror when land is taken. Three MultiMesh batches (house body, roof,
# citizen) keep it to a few draw calls; citizens bob via a vertex shader = zero CPU.

var grid
var cell: float = 0.6
var colors := {}
var _homes := {}             # kid -> Vector2i home cell (villages cluster here)

const PROP_Y := 0.07         # sit on the flat land slab
# Density buckets (out of 1000) by Manhattan distance from the kingdom's castle:
# dense village core near home, thinning to sparse outskirts near the border.
const CORE_R := 9
const MID_R := 20
const HOUSE_CAP := 700       # mobile instance caps (one draw call each, but keep tris sane)
const CIT_CAP := 1400

const CIT_SHADER := """
shader_type spatial;
render_mode cull_back;
void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 2.7 + wp.z * 1.9;
	VERTEX.y += sin(TIME * 3.5 + ph) * 0.05;
}
void fragment() { ALBEDO = COLOR.rgb; }
"""

var _body: MultiMeshInstance3D
var _roof: MultiMeshInstance3D
var _cit: MultiMeshInstance3D

func setup(p_grid, p_cell: float, p_colors: Dictionary, p_homes: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	colors = p_colors
	_homes = p_homes
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(cell * 0.62, 0.5, cell * 0.62)
	_body = _batch(body_mesh, false)
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = cell * 0.58
	roof_mesh.height = 0.45
	roof_mesh.radial_segments = 4
	_roof = _batch(roof_mesh, false)
	var cit_mesh := SphereMesh.new()    # cute low-poly blob citizen (mobile-cheap)
	cit_mesh.radius = 0.17
	cit_mesh.height = 0.30
	cit_mesh.radial_segments = 7
	cit_mesh.rings = 4
	_cit = _batch(cit_mesh, true)
	add_child(_body)
	add_child(_roof)
	add_child(_cit)

func _batch(mesh: Mesh, bob: bool) -> MultiMeshInstance3D:
	var mat: Material
	if bob:
		var sh := Shader.new()
		sh.code = CIT_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = sh
		mat = sm
	else:
		var st := StandardMaterial3D.new()
		st.vertex_color_use_as_albedo = true
		st.roughness = 0.7
		mat = st
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

func rebuild() -> void:
	var w: int = grid.w
	var n: int = w * grid.h
	var house_pos: Array = []
	var house_col: Array = []
	var cit_pos: Array = []
	var cit_col: Array = []
	for i in n:
		var oid: int = grid.owner[i]
		if oid == 0:
			continue
		var bucket: int = ((i * 1103515245 + 12345) & 0x7fffffff) % 1000
		var cx: int = i % w
		var cy: int = i / w
		# Cluster density by distance from this kingdom's castle.
		var home: Vector2i = _homes.get(oid, Vector2i(cx, cy))
		var d: int = absi(cx - home.x) + absi(cy - home.y)
		var house_thr: int
		var cit_thr: int
		if d <= CORE_R:
			house_thr = 95; cit_thr = 300        # dense village core
		elif d <= MID_R:
			house_thr = 45; cit_thr = 150
		else:
			house_thr = 12; cit_thr = 45         # sparse outskirts
		if bucket >= cit_thr:
			continue
		var base: Vector3 = _c2w(cx, cy)
		var col: Color = colors.get(oid, Color.WHITE)
		if bucket < house_thr:
			if house_pos.size() < HOUSE_CAP:
				house_pos.append(base)
				house_col.append(col)
		elif cit_pos.size() < CIT_CAP:
			cit_pos.append(base)
			cit_col.append(col)

	# House body = constant cream; roof = kingdom colour; citizens = kingdom colour.
	_fill(_body, house_pos, house_col, Vector3(0, PROP_Y + 0.25, 0), Color("caa46a"), true)  # warm wood, not stark white
	_fill(_roof, house_pos, house_col, Vector3(0, PROP_Y + 0.5 + 0.22, 0), Color.WHITE, false)
	_fill(_cit, cit_pos, cit_col, Vector3(0, PROP_Y + 0.18, 0), Color.WHITE, false)

func _fill(mmi: MultiMeshInstance3D, positions: Array, cols: Array, y_off: Vector3,
		const_col: Color, use_const: bool) -> void:
	var mm := mmi.multimesh
	mm.instance_count = positions.size()
	for k in positions.size():
		mm.set_instance_transform(k, Transform3D(Basis(), positions[k] + y_off))
		mm.set_instance_color(k, const_col if use_const else cols[k])

func _c2w(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5 - grid.w * 0.5) * cell, 0.0, (cy + 0.5 - grid.h * 0.5) * cell)
