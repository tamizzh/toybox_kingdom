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
const HOUSE_CAP := 1000      # instance caps (one draw call each, but keep tris sane)
const CIT_CAP := 1800
const TOWER_CAP := 360       # sparse kingdom towers give the target's studded skyline

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
var _tower: MultiMeshInstance3D       # tall kingdom-coloured keep tower
var _tower_roof: MultiMeshInstance3D  # its pointed roof

func setup(p_grid, p_cell: float, p_colors: Dictionary, p_homes: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	colors = p_colors
	_homes = p_homes
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(cell * 0.74, 0.58, cell * 0.74)
	_body = _batch(body_mesh, false)
	# Overhanging gable roof (triangular prism) reads as a real little house far better
	# than the old squat 4-sided cone; it overhangs the body on all sides.
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(cell * 0.90, 0.38, cell * 0.94)
	_roof = _batch(roof_mesh, false)
	var cit_mesh := SphereMesh.new()    # cute low-poly blob citizen (mobile-cheap)
	cit_mesh.radius = 0.24
	cit_mesh.height = 0.40
	cit_mesh.radial_segments = 7
	cit_mesh.rings = 4
	_cit = _batch(cit_mesh, true)
	# Towers: a tall thin keep (cream stone) topped by a kingdom-coloured spire.
	var tower_mesh := BoxMesh.new()
	tower_mesh.size = Vector3(cell * 0.5, 1.3, cell * 0.5)
	_tower = _batch(tower_mesh, false)
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.0
	spire_mesh.bottom_radius = cell * 0.42
	spire_mesh.height = 0.62
	spire_mesh.radial_segments = 6
	_tower_roof = _batch(spire_mesh, false)
	add_child(_body)
	add_child(_roof)
	add_child(_cit)
	add_child(_tower)
	add_child(_tower_roof)

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
		# Matte clay to match the painted ground/plate (was 0.48 = plastic gloss, which
		# made houses + towers read as a different art language sitting ON the board).
		st.roughness = 0.82
		st.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
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
	var cit_pos := PackedVector3Array()
	var cit_col := PackedColorArray()
	var tower_pos := PackedVector3Array()
	var tower_col := PackedColorArray()
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
		# Sparse towers (separate hash) in the core/mid ring → studded skyline.
		var tbucket: int = ((i * 2246822519) & 0x7fffffff) % 1000
		var tower_thr: int = 14 if d <= CORE_R else (6 if d <= MID_R else 0)
		if tbucket < tower_thr and tower_pos.size() < tower_cap:
			tower_pos.append(base)
			tower_col.append(col)
			continue
		var bucket: int = ((i * 1103515245 + 12345) & 0x7fffffff) % 1000
		var house_thr: int
		var cit_thr: int
		if d <= CORE_R:
			house_thr = 110; cit_thr = 340       # dense village core
		elif d <= MID_R:
			house_thr = 52; cit_thr = 180
		else:
			house_thr = 14; cit_thr = 56         # sparse outskirts
		if bucket >= cit_thr:
			continue
		if bucket < house_thr:
			if house_pos.size() < house_cap:
				house_pos.append(base)
				house_col.append(col)
		elif cit_pos.size() < cit_cap:
			cit_pos.append(base)
			cit_col.append(col)

	# House body = constant cream; roof = kingdom colour; citizens = kingdom colour.
	_fill(_body, house_pos, house_col, Vector3(0, PROP_Y + 0.29, 0), Color("f1d8a0"), true)
	_fill(_roof, house_pos, house_col, Vector3(0, PROP_Y + 0.76, 0), Color.WHITE, false)
	_fill(_cit, cit_pos, cit_col, Vector3(0, PROP_Y + 0.25, 0), Color.WHITE, false)
	# Tower keep = cream stone; spire = kingdom colour, perched on top.
	_fill(_tower, tower_pos, tower_col, Vector3(0, PROP_Y + 0.65, 0), Color("e9d6ad"), true)
	_fill(_tower_roof, tower_pos, tower_col, Vector3(0, PROP_Y + 1.61, 0), Color.WHITE, false)

func _fill(mmi: MultiMeshInstance3D, positions: PackedVector3Array, cols: PackedColorArray,
		y_off: Vector3, const_col: Color, use_const: bool) -> void:
	var mm := mmi.multimesh
	mm.instance_count = positions.size()
	for k in positions.size():
		mm.set_instance_transform(k, Transform3D(Basis(), positions[k] + y_off))
		mm.set_instance_color(k, const_col if use_const else cols[k])

func _c2w(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5 - grid.w * 0.5) * cell, 0.0, (cy + 0.5 - grid.h * 0.5) * cell)
