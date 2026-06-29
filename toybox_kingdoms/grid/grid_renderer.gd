extends Node3D

# ── DAY 4-7 SPIKE: grid -> 3D diorama renderer ───────────────────────────────
# Turns the pure-data TerritoryGrid into the "raised toybox kingdom" look using
# two MultiMeshInstance3D batches (territory + live trails). One draw call each,
# per-instance colour, never one node per cell. Territory is rebuilt only when the
# grid reports a dirty rect; trails are short so they rebuild every frame cheaply.

var grid                          # TerritoryGrid
var cell: float = 0.6
var colors := {}                  # kingdom id -> Color

# Trail instances share one constant footprint — cache the scale Basis so update_trails()
# (every physics frame) doesn't rebuild it per instance.
var _trail_basis := Basis()

const NEUTRAL_H := 0.06          # wilderness tiles — a low patchwork of green shades
const LAND_H := 0.15             # claimed land rises as a plateau above the wilderness
const BORDER_H := 0.44           # border cells rise into a wall above the plateau
const TRAIL_H := 0.30            # pending trail stands proud + glows so it reads as risk (slimmer)

# Wilderness green shades (different per tile -> the tiled terrain look)
const G_DARK := Color("335f22")
const G_MID := Color("47802c")
const G_LITE := Color("5c9a3c")

# Per-instance emissive shader so each kingdom's trail glows in its own colour
# (MultiMesh instance colour arrives as COLOR in the fragment stage).
const TRAIL_SHADER := """
shader_type spatial;
render_mode cull_back;
vec3 to_lin(vec3 c){
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}
void fragment() {
	vec3 lin = to_lin(COLOR.rgb);   // sRGB->linear: matches wall + roof tone exactly
	ALBEDO = lin;
	ROUGHNESS = 0.8;
	SPECULAR = 0.5;
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 1.8);
	EMISSION = lin * (0.55 + rim * 2.8);
}
"""

var _neutral: MultiMeshInstance3D
var _terr: MultiMeshInstance3D
var _trail: MultiMeshInstance3D
var _border: MultiMeshInstance3D
var _border_cells := {}           # cell index -> wall Color, only for owned border cells

func setup(p_grid, p_cell: float, p_colors: Dictionary) -> void:
	grid = p_grid
	cell = p_cell
	colors = p_colors
	_trail_basis = Basis().scaled(Vector3(cell * 0.62, TRAIL_H, cell * 0.62))
	# wilderness tile layer (built once)
	_neutral = _make_batch(Vector3(cell, 1.0, cell), false)
	add_child(_neutral)
	# Unit-height box, full cell width (no gaps) — height is scaled per-instance so
	# interior land is flat and only border cells rise into a wall.
	_terr = _make_batch(Vector3(cell, 1.0, cell), false)
	add_child(_terr)
	_trail = _make_trail_batch()
	add_child(_trail)
	_border = _make_wall_batch()
	add_child(_border)

# Trail = the beveled toy block (trail.glb), per-instance kingdom colour, glowing.
# Scale is baked per-instance in update_trails (slim footprint, short height).
func _make_trail_batch() -> MultiMeshInstance3D:
	var inst := (load("res://assets/models/trail.glb") as PackedScene).instantiate()
	var mesh := _extract_mesh(inst)
	inst.free()
	var sh := Shader.new()
	sh.code = TRAIL_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

func _make_wall_batch() -> MultiMeshInstance3D:
	var inst := (load("res://assets/models/wall.glb") as PackedScene).instantiate()
	var mesh := _extract_mesh(inst)
	inst.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true   # tint the grey wall per kingdom
	mat.roughness = 0.85
	mmi.material_override = mat
	return mmi

func _extract_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and n.mesh != null:
		return n.mesh
	for c in n.get_children():
		var r := _extract_mesh(c)
		if r != null:
			return r
	return null

# Place a 3D wall block on every border cell, tinted to the kingdom colour.
# Pass a dirty rect (x0,y0)..(x1,y1) to rescan only that region; the default (no
# rect) rescans the whole board. The persistent _border_cells set carries border
# state between calls, so a small capture only re-tests its own neighbourhood
# instead of all 12k cells. The rect is expanded by 1 because changing one cell can
# flip the border status of its 4 neighbours.
func rebuild_borders(x0: int = 0, y0: int = 0, x1: int = -1, y1: int = -1) -> void:
	var w: int = grid.w
	var h: int = grid.h
	if x1 < x0:
		x0 = 0; y0 = 0; x1 = w - 1; y1 = h - 1
	x0 = maxi(0, x0 - 1); y0 = maxi(0, y0 - 1)
	x1 = mini(w - 1, x1 + 1); y1 = mini(h - 1, y1 + 1)
	for cy in range(y0, y1 + 1):
		var row := cy * w
		for cx in range(x0, x1 + 1):
			var i := row + cx
			var kid: int = grid.owner[i]
			if kid != 0 and _is_border(i, cx, cy, w, h, kid):
				_border_cells[i] = (colors.get(kid, Color.WHITE) as Color).darkened(0.08)
			else:
				_border_cells.erase(i)
	# Rebuild the compact instance buffer from the border-cell set (a few hundred
	# entries — far cheaper than the 12k full-grid scan it replaces).
	var mm := _border.multimesh
	mm.instance_count = _border_cells.size()
	var k := 0
	for i in _border_cells:
		var cx: int = int(i) % w
		var cy: int = int(i) / w
		mm.set_instance_transform(k, Transform3D(Basis(), _c2w(cx, cy, 0.0)))
		mm.set_instance_color(k, _border_cells[i])
		k += 1

# Build the wilderness as a tiled patchwork of green shades (once at startup).
# Claimed land is a separate, taller batch drawn on top, so we never rebuild this.
func build_neutral() -> void:
	var w: int = grid.w
	var h: int = grid.h
	var n: int = w * h
	# coarse smooth noise -> soft green patches across the map
	var gn := 18
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var noise := PackedFloat32Array()
	noise.resize(gn * gn)
	for i in gn * gn:
		noise[i] = rng.randf()
	var mm := _neutral.multimesh
	mm.instance_count = n
	for i in n:
		var cx := i % w
		var cy := i / w
		var patch := _bilerp(noise, gn, float(cx) / w, float(cy) / h)
		# per-tile jitter so neighbouring tiles differ in shade + a touch of height
		var jit := float((((cx * 73856093) ^ (cy * 19349663)) & 0x3ff)) / 1023.0
		var t := clampf(patch * 0.6 + jit * 0.4, 0.0, 1.0)   # stronger per-tile shade contrast
		var col := G_DARK.lerp(G_MID, smoothstep(0.18, 0.5, t)).lerp(G_LITE, smoothstep(0.5, 0.95, t))
		var hh := NEUTRAL_H + (jit - 0.5) * 0.07
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1.0, hh, 1.0)), _c2w(cx, cy, hh * 0.5)))
		mm.set_instance_color(i, col)

func _bilerp(g: PackedFloat32Array, gn: int, u: float, v: float) -> float:
	var fx := u * gn
	var fy := v * gn
	var x0 := int(floor(fx)) % gn
	var y0 := int(floor(fy)) % gn
	var x1 := (x0 + 1) % gn
	var y1 := (y0 + 1) % gn
	var tx := smoothstep(0.0, 1.0, fx - floor(fx))
	var ty := smoothstep(0.0, 1.0, fy - floor(fy))
	var top := lerpf(g[y0 * gn + x0], g[y0 * gn + x1], tx)
	var bot := lerpf(g[y1 * gn + x0], g[y1 * gn + x1], tx)
	return lerpf(top, bot, ty)

func _make_batch(box_size: Vector3, emissive: bool) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = box_size
	var mat: Material
	if emissive:
		var sh := Shader.new()
		sh.code = TRAIL_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = sh
		mat = sm
	else:
		var st := StandardMaterial3D.new()
		st.vertex_color_use_as_albedo = true   # per-instance colour drives albedo
		st.roughness = 0.9                      # matte toy plastic
		mat = st
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

func _c2w(cx: int, cy: int, y: float) -> Vector3:
	var wx: float = (cx + 0.5 - grid.w * 0.5) * cell
	var wz: float = (cy + 0.5 - grid.h * 0.5) * cell
	return Vector3(wx, y, wz)

# Rebuild the whole territory batch from the grid. Called on dirty (occasional).
# Interior cells = flat land; border cells (touching neutral / another kingdom /
# the world edge) = a raised, deeper-shade wall. Three values per kingdom: dark
# border wall, mid land, bright buildings (drawn by the populace/castle).
func rebuild_territory() -> void:
	var w: int = grid.w
	var h: int = grid.h
	var n: int = w * h
	var cells: Array[int] = []
	for i in n:
		if grid.owner[i] != 0:
			cells.append(i)
	var mm := _terr.multimesh
	mm.instance_count = cells.size()
	for k in cells.size():
		var i := cells[k]
		var cx: int = i % w
		var cy: int = i / w
		var kid: int = grid.owner[i]
		var oc: Color = colors.get(kid, Color.WHITE)
		var border := _is_border(i, cx, cy, w, h, kid)
		var hgt: float = BORDER_H if border else LAND_H
		# 3 clean values: dark border wall < saturated land < bright buildings.
		var col: Color = oc.darkened(0.25) if border else oc.lightened(0.10)
		var t := Transform3D(Basis().scaled(Vector3(1.0, hgt, 1.0)), _c2w(cx, cy, hgt * 0.5))
		mm.set_instance_transform(k, t)
		mm.set_instance_color(k, col)

# A cell is a border if it touches the world edge or a cell this kingdom doesn't own.
func _is_border(i: int, cx: int, cy: int, w: int, h: int, kid: int) -> bool:
	if cx == 0 or cy == 0 or cx == w - 1 or cy == h - 1:
		return true
	return int(grid.owner[i - 1]) != kid or int(grid.owner[i + 1]) != kid \
		or int(grid.owner[i - w]) != kid or int(grid.owner[i + w]) != kid

# Bright sheet that pops over a just-claimed region and fades — sells the capture.
func flash_cells(min_c: Vector2i, max_c: Vector2i, color: Color) -> void:
	if max_c.x < min_c.x:
		return
	var w: float = grid.w
	var h: float = grid.h
	var x0 := (min_c.x + 0.5 - w * 0.5) * cell
	var z0 := (min_c.y + 0.5 - h * 0.5) * cell
	var x1 := (max_c.x + 0.5 - w * 0.5) * cell
	var z1 := (max_c.y + 0.5 - h * 0.5) * cell
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(absf(x1 - x0) + cell, absf(z1 - z0) + cell)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.lightened(0.5), 0.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3((x0 + x1) * 0.5, 0.5, (z0 + z1) * 0.5)
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.parallel().tween_property(mi, "position:y", 1.1, 0.45)
	tw.tween_callback(mi.queue_free)

# Rebuild the live-trail batch (every frame — trails are tens of cells at most).
func update_trails(ids: Array) -> void:
	# Runs every physics frame — no per-frame array allocs and no per-instance Basis
	# rebuild (the footprint is constant, cached as _trail_basis in setup()).
	var mm := _trail.multimesh
	var total := 0
	for id in ids:
		total += grid.trail_cells(id).size()
	mm.instance_count = total
	var k := 0
	for id in ids:
		var col: Color = colors.get(id, Color.WHITE)   # raw kingdom colour; shader sRGB->linear
		for c in grid.trail_cells(id):
			var cx: int = c % grid.w
			var cy: int = c / grid.w
			# beveled unit cube scaled to the slim trail footprint + short height
			mm.set_instance_transform(k, Transform3D(_trail_basis, _c2w(cx, cy, TRAIL_H * 0.5)))
			mm.set_instance_color(k, col)
			k += 1
