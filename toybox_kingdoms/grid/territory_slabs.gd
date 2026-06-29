extends Node3D

# ── TerritorySlabs: claimed land as thick raised colour cutouts + block walls ──
# simple_target.png's regions are chunky foam-board slabs with a flat coloured top
# and a darker coloured vertical side wall, RINGED by a low wall of small light
# blocks (varied heights → a hand-stacked, "random blocks" look). A single subdivided
# plane can't make crisp vertical walls (shared verts only ramp), so each claimed cell
# becomes a CELL-sized box raised to SLAB_H; same-owner neighbours butt together and
# back-face culling hides their shared interior walls, so a region reads as ONE
# flat-topped slab. Every BORDER cell additionally gets a small light cap block on top
# of the slab — the perimeter wall.
#
# Two MultiMesh draw calls (slabs + wall blocks). Rebuilt on the throttled territory
# tick, like the ownership texture. The wilderness ground plane (territory_ground.gd)
# stays flat and is the base these slabs sit on; props on claimed land are lifted by
# SLAB_H so they rest on top (see kingdom_match CLAIMED_LIFT + the prop-node offsets).

const SLAB_H := 0.20         # slab thickness; kingdom_match.CLAIMED_LIFT must match
const BASE_Y := 0.04         # match territory_ground TOP_Y (the flat base under the slabs)
const WALL_BASE_H := 0.16    # nominal wall-block height above the slab top (low parapet)
const WALL_BRICK := 0.40     # small brick footprint (fraction of a cell)
const WALL_SEG := 2          # bricks per exposed border edge → a tight, continuous row
const WALL_INSET := 0.40     # how far out from the cell centre the brick row sits (≈ the slab rim)
# Walls render the EXACT kingdom colour (matching the house roofs / windmill cap); the
# raised slab plates are disabled, so claimed-land colour comes from the ground plane.

# sRGB->linear: StandardMaterial3D (and so the windmill cap) converts albedo this way, but a
# raw-COLOR shader doesn't — so the kingdom colour lands on the same tone here as on the roofs.
const SRGB_FN := """
vec3 to_lin(vec3 c){
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}
"""

const SLAB_SHADER := """
shader_type spatial;
render_mode cull_back;
varying vec3 v_n;
""" + SRGB_FN + """
void vertex(){ v_n = normalize(NORMAL); }
void fragment(){
	// Flat-top, darker-sides → the cardboard-cutout thickness of the target.
	float top = step(0.5, abs(v_n.y));
	ALBEDO = to_lin(COLOR.rgb) * mix(0.62, 1.0, top);
	ROUGHNESS = 0.95;
	SPECULAR = 0.02;
}
"""

# Wall blocks: rendered to EXACTLY match the house roofs / windmill cap — full kingdom
# colour (sRGB->linear) with the same glossy-ish finish (rough 0.8, spec 0.5), no extra
# top/side shading so the colour reads identical to the roofs.
const WALL_SHADER := """
shader_type spatial;
render_mode cull_back;
""" + SRGB_FN + """
void vertex(){}
void fragment(){
	vec3 lin = to_lin(COLOR.rgb);
	ALBEDO = lin;
	// Small self-colour floor: the camera mostly sees the bricks' vertical SIDE faces,
	// which sit in key-light shadow and are lit only by the blue fill. A pure red can't
	// reflect blue, so those faces crater to near-black; this lifts them back toward the
	// true kingdom colour (the up-facing roofs catch the key light, so they don't need it).
	EMISSION = lin * 0.22;
	ROUGHNESS = 0.8;
	SPECULAR = 0.5;
}
"""

var grid
var cell: float = 0.6
var colors := {}
var _slab_mm: MultiMesh
var _wall_mm: MultiMesh

func setup(p_grid, p_cell: float, p_colors: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	colors = p_colors
	# Slab layer
	var box := BoxMesh.new()
	box.size = Vector3(cell, SLAB_H, cell)
	_slab_mm = _make_layer(box, SLAB_SHADER)
	# Wall-block layer (small cube; height is scaled per-instance for the stacked look)
	var wbox := BoxMesh.new()
	wbox.size = Vector3(cell * WALL_BRICK, 1.0, cell * WALL_BRICK)
	_wall_mm = _make_layer(wbox, WALL_SHADER)

func _make_layer(mesh: Mesh, shader_code: String) -> MultiMesh:
	var sh := Shader.new()
	sh.code = shader_code
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = sm
	# Flat paper diorama: the faint key shadow lands on the board; thousands of casters
	# × cascades is the wrong cost.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm

func _hash(i: int) -> float:
	var x := (i * 2654435761) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177
	return float(x & 0xffff) / 65535.0

# A claimed cell is a border cell if it touches the world edge or a cell NOT owned by
# the same kingdom — those get the perimeter wall block.
func _is_border(i: int, cx: int, cy: int, w: int, h: int, kid: int) -> bool:
	if cx == 0 or cy == 0 or cx == w - 1 or cy == h - 1:
		return true
	return int(grid.owner[i - 1]) != kid or int(grid.owner[i + 1]) != kid \
		or int(grid.owner[i - w]) != kid or int(grid.owner[i + w]) != kid

# Full rebuild from the grid. Called on the throttled territory tick (≤10/s).
# Uses a raw PackedFloat32Array buffer write instead of per-instance set_instance_*
# calls — one engine crossing for N bricks instead of 2×N.
#
# Buffer layout per instance (TRANSFORM_3D + use_colors, no custom_data): 16 floats.
# Rotation-about-Y by `a`, scaled to height `bh` on the Y axis:
#   row0: [cos(a),  0,   sin(a),  px]
#   row1: [0,       bh,  0,       py]
#   row2: [-sin(a), 0,   cos(a),  pz]
#   cols 12-15: colour as 4 float32 RGBA (Godot 4.6 stores colour as full floats)
const _BUF_STRIDE := 16

func rebuild() -> void:
	var w: int = grid.w
	var h: int = grid.h
	var hw: float = grid.w * 0.5
	var hh: float = grid.h * 0.5

	# Per-kingdom colour precomputed as float32 RGBA components (avoid Color alloc per brick).
	var col_r := PackedFloat32Array(); col_r.resize(256)
	var col_g := PackedFloat32Array(); col_g.resize(256)
	var col_b := PackedFloat32Array(); col_b.resize(256)
	for oid_key in colors:
		var oi: int = oid_key
		var c: Color = colors[oi]
		col_r[oi] = c.r; col_g[oi] = c.g; col_b[oi] = c.b

	# Collect brick data per kingdom using each kingdom's own tight bbox (grid.kid_bbox).
	# This keeps the scan proportional to owned area per kingdom rather than the global
	# union — 4 kingdoms at ~3k cells each vs one ~87k-cell union box.
	var wall_px  := PackedFloat32Array()
	var wall_pz  := PackedFloat32Array()
	var wall_bh  := PackedFloat32Array()
	var wall_rot := PackedFloat32Array()
	var wall_oid := PackedByteArray()

	for oid_key in colors:
		var oid: int = oid_key
		var bb: PackedInt32Array = grid.kid_bbox(oid)
		if bb.is_empty():
			continue
		var x0: int = bb[0]; var y0: int = bb[1]; var x1: int = bb[2]; var y1: int = bb[3]
		for cy in range(y0, y1 + 1):
			var _row := cy * w
			for cx in range(x0, x1 + 1):
				var i := _row + cx
				if int(grid.owner[i]) != oid:
					continue
				var wx: float = (cx + 0.5 - hw) * cell
				var wz: float = (cy + 0.5 - hh) * cell
				for di in 4:
					var dx: int = [1, -1, 0, 0][di]
					var dy: int = [0, 0, 1, -1][di]
					var nx: int = cx + dx
					var ny: int = cy + dy
					if not ((nx < 0 or ny < 0 or nx >= w or ny >= h) \
							or int(grid.owner[ny * w + nx]) != oid):
						continue
					var ex: float = wx + WALL_INSET * cell * float(dx)
					var ez: float = wz + WALL_INSET * cell * float(dy)
					var ax: float = float(dy)
					var az: float = float(dx)
					for s in WALL_SEG:
						var t := (float(s) - (WALL_SEG - 1) * 0.5) / float(WALL_SEG)
						var r := _hash(i * 4 + di + s * 131)
						wall_px.append(ex + ax * t * cell)
						wall_pz.append(ez + az * t * cell)
						wall_bh.append(WALL_BASE_H * (0.78 + r * 0.5))
						wall_rot.append((r - 0.5) * 0.14)
						wall_oid.append(oid)

	# Build the raw buffer in one indexed-write pass (stride known = _BUF_STRIDE),
	# then hand it to the engine in a single call — no per-instance dispatch overhead.
	var n := wall_px.size()
	_slab_mm.instance_count = 0   # walls-only: no raised slab plates
	_wall_mm.instance_count = n
	if n > 0:
		var buf := PackedFloat32Array(); buf.resize(n * _BUF_STRIDE)
		for k in n:
			var bh: float = wall_bh[k]
			var cos_y := cos(wall_rot[k])
			var sin_y := sin(wall_rot[k])
			var py: float = BASE_Y + bh * 0.5
			var o := k * _BUF_STRIDE
			buf[o]    = cos_y;  buf[o+1]  = 0.0;  buf[o+2]  = sin_y;  buf[o+3]  = wall_px[k]
			buf[o+4]  = 0.0;    buf[o+5]  = bh;   buf[o+6]  = 0.0;    buf[o+7]  = py
			buf[o+8]  = -sin_y; buf[o+9]  = 0.0;  buf[o+10] = cos_y;  buf[o+11] = wall_pz[k]
			var oi := int(wall_oid[k])
			buf[o+12] = col_r[oi]; buf[o+13] = col_g[oi]; buf[o+14] = col_b[oi]; buf[o+15] = 1.0
		_wall_mm.buffer = buf
