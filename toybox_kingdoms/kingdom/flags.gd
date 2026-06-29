extends Node3D

# ── Border flags: a defended-frontier feel (target_art look) ──────────────────
# Kingdom-coloured banners dotting territory edges. Two MultiMesh batches (pole +
# waving banner) = 2 draw calls. Placed on a hash-stable ~1/6 subset of border
# cells so flags ring each kingdom without crowding. Banner ripples via a vertex
# shader (zero CPU), mirroring the citizen-bob trick in populace.gd.

var grid
var cell: float = 0.6
var colors := {}

const PROP_Y := 0.07
const FLAG_CAP := 700
const POLE_COL := Color("3a2c1a")

const BANNER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
void vertex(){
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 2.3 + wp.z * 1.7;
	// ripple grows toward the free (outer) edge of the banner
	float edge = clamp((VERTEX.x + 0.16) / 0.32, 0.0, 1.0);
	VERTEX.z += sin(TIME * 4.0 + ph + VERTEX.x * 11.0) * 0.05 * edge;
}
void fragment(){ ALBEDO = COLOR.rgb; }
"""

var _pole: MultiMeshInstance3D
var _banner: MultiMeshInstance3D

func setup(p_grid, p_cell: float, p_colors: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	colors = p_colors
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.022
	pole_mesh.bottom_radius = 0.03
	pole_mesh.height = 0.9
	pole_mesh.radial_segments = 5
	_pole = _batch(pole_mesh, false)
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(0.32, 0.20, 0.02)   # waves on local z via the shader
	_banner = _batch(banner_mesh, true)
	add_child(_pole)
	add_child(_banner)

func _batch(mesh: Mesh, wave: bool) -> MultiMeshInstance3D:
	var mat: Material
	if wave:
		var sh := Shader.new()
		sh.code = BANNER_SHADER
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
	var h: int = grid.h
	# Packed arrays keep this scan allocation-light (no Variant boxing). Bounded to the
	# owned-land box (see TerritoryGrid.owned_min/max); `i` stays the flat index so the
	# hash-thinning lands on the same cells as a full-board scan.
	var pole_pos := PackedVector3Array()
	var ban_pos := PackedVector3Array()
	var ban_col := PackedColorArray()
	var x0 := 0; var y0 := 0; var x1 := -1; var y1 := -1
	if grid.has_owned():
		x0 = grid.owned_min.x; y0 = grid.owned_min.y
		x1 = grid.owned_max.x; y1 = grid.owned_max.y
	for cy in range(y0, y1 + 1):
		if pole_pos.size() >= FLAG_CAP:
			break
		var _row := cy * w
		for cx in range(x0, x1 + 1):
			var i := _row + cx
			var kid: int = grid.owner[i]
			if kid == 0:
				continue
			if not _is_border(i, cx, cy, w, h, kid):
				continue
			# hash-stable thinning → ~1 flag per 6 border cells (spaced, never crowded)
			if ((i * 40503) & 0x7fffffff) % 6 != 0:
				continue
			if pole_pos.size() >= FLAG_CAP:
				break
			var base := _c2w(cx, cy)
			pole_pos.append(base)
			ban_pos.append(base)
			ban_col.append(colors.get(kid, Color.WHITE))
	_fill(_pole, pole_pos, PackedColorArray(), Vector3(0, PROP_Y + 0.45, 0), POLE_COL, true)
	# banner perched near the pole top, offset to one side so its inner edge meets the pole
	_fill(_banner, ban_pos, ban_col, Vector3(0.16, PROP_Y + 0.72, 0), Color.WHITE, false)

func _fill(mmi: MultiMeshInstance3D, positions: PackedVector3Array, cols: PackedColorArray,
		off: Vector3, const_col: Color, use_const: bool) -> void:
	var mm := mmi.multimesh
	mm.instance_count = positions.size()
	for k in positions.size():
		mm.set_instance_transform(k, Transform3D(Basis(), positions[k] + off))
		mm.set_instance_color(k, const_col if use_const else cols[k])

func _is_border(i: int, cx: int, cy: int, w: int, h: int, kid: int) -> bool:
	if cx == 0 or cy == 0 or cx == w - 1 or cy == h - 1:
		return true
	return int(grid.owner[i - 1]) != kid or int(grid.owner[i + 1]) != kid \
		or int(grid.owner[i - w]) != kid or int(grid.owner[i + w]) != kid

func _c2w(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5 - grid.w * 0.5) * cell, 0.0, (cy + 0.5 - grid.h * 0.5) * cell)
