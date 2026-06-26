extends Node3D

# ── Procedural road network ───────────────────────────────────────────────
# Generates dirt-road geometry connecting each kingdom's buildings to its
# castle. Called once per kingdom when territory or tier changes; zero cost
# per frame. Roads are decoration — they never block gameplay.
#
# Hierarchy (inside each kingdom's RoadNode):
#   castle plaza → primary roads → secondary roads
#
# Road types:
#   Primary   (W_PRIMARY)   castle → windmill / tower / first house
#   Secondary (W_SECONDARY) house ↔ house, farm clusters
#
# Progression (0..1 fraction derived from territory count + tier):
#   <0.05  no roads
#   0.05+  castle → nearest house
#   0.10+  castle → each windmill
#   0.20+  castle → towers; house MST (4 edges)
#   0.30+  castle → nearest farm; house MST (7 edges)
#   0.50+  farm-cluster MST (5 edges)
#   0.70+  denser house network (12 edges)
#
# Material progression:
#   dirt (T1-2, <30%)  →  cobble (T3, 30-60%)  →  stone (T4, >60%)

const GW := 128
const GH := 96
const CELL := 0.6

# Local Y offset (the roads node itself sits at CLAIMED_LIFT in kingdom_match)
const ROAD_Y := 0.006

# Tile scale as fraction of CELL — the thin gap between tiles reads as grout
const ROAD_TILE  := 0.84   # path cells
const PLAZA_TILE := 0.92   # castle plaza cells

# Square radius of cells around the castle that form the plaza
const PLAZA_R := 2

# Connection half-widths (used by _plan to type connections; not used in tile mesh)
const W_PRIMARY   := 0.22
const W_SECONDARY := 0.14

# A* hard iteration cap per path (prevents stalls on fragmented territory)
const ASTAR_CAP   := 700

# ── External refs (assigned by kingdom_match._ready) ─────────────────────
var grid                  # TerritoryGrid  (has .owner: PackedByteArray)
var populace              # Populace node
var windmills_ref         # Windmills node
var decor_ref             # Decor node

# ── State ─────────────────────────────────────────────────────────────────
var _homes:  Dictionary = {}   # kid → Vector2i
var _meshes: Dictionary = {}   # kid → MeshInstance3D
var _mats:   Array      = []   # [dirt_mat, sand_mat] StandardMaterial3D
var _last_tier:  Dictionary = {}
var _last_count: Dictionary = {}

# ── Inner types ───────────────────────────────────────────────────────────

class RoadNode:
	var cell: Vector2i
	var kind: String   # "castle" | "house" | "tower" | "windmill" | "farm"
	func _init(c: Vector2i, k: String) -> void:
		cell = c; kind = k

class Conn:
	var from_cell: Vector2i
	var to_cell:   Vector2i
	var half_w:    float

# ── Setup ─────────────────────────────────────────────────────────────────

func setup(p_grid, p_homes: Dictionary) -> void:
	grid  = p_grid
	_homes = p_homes
	_build_materials()

# ── Public API ────────────────────────────────────────────────────────────

# Rebuild one kingdom's road mesh. Call from _kingdom_tick (throttled).
func rebuild(kid: int, tier: int, territory_count: int) -> void:
	# Skip if nothing meaningful changed — avoids full rebuild on tiny fluctuations
	if tier == _last_tier.get(kid, -1) and absi(territory_count - _last_count.get(kid, -1)) < 15:
		return
	_last_tier[kid]  = tier
	_last_count[kid] = territory_count

	# Remove stale mesh
	if _meshes.has(kid):
		_meshes[kid].queue_free()
		_meshes.erase(kid)

	var pct := _progress(territory_count, tier)
	if pct < 0.05:
		return   # Outpost: not yet a real settlement, no roads

	var nodes := _collect_nodes(kid, tier)
	if nodes.is_empty():
		return

	var conns := _plan(nodes, pct, tier)
	if conns.is_empty():
		return

	var home: Vector2i = _homes.get(kid, Vector2i(GW / 2, GH / 2))

	# Collect all road cells from A* paths (deduplicated by cell key)
	var road_cells: Dictionary = {}   # Vector2i → int (1=path, 2=plaza)
	for c: Conn in conns:
		var raw := _astar(kid, c.from_cell, c.to_cell)
		for v: Vector2 in raw:
			var cell := Vector2i(int(v.x), int(v.y))
			if not road_cells.has(cell):
				road_cells[cell] = 1

	if road_cells.is_empty():
		return

	# Castle plaza: square of cells around home (overrides path type → larger tile)
	for dx in range(-PLAZA_R, PLAZA_R + 1):
		for dz in range(-PLAZA_R, PLAZA_R + 1):
			var pc := home + Vector2i(dx, dz)
			if _inb(pc):
				road_cells[pc] = 2

	var mesh := _build_tile_mesh(road_cells)
	if mesh == null:
		return

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _pick_mat(tier, pct)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_meshes[kid] = mi

# Remove a kingdom's roads (call when it is eliminated)
func clear_kingdom(kid: int) -> void:
	if _meshes.has(kid):
		_meshes[kid].queue_free()
		_meshes.erase(kid)
	_last_tier.erase(kid)
	_last_count.erase(kid)

# ── Building collection ───────────────────────────────────────────────────

func _collect_nodes(kid: int, tier: int) -> Array:
	var out: Array = []
	var home: Vector2i = _homes.get(kid, Vector2i(GW / 2, GH / 2))

	out.append(RoadNode.new(home, "castle"))   # always index 0

	if populace and populace.has_method("get_road_nodes"):
		var d: Dictionary = populace.get_road_nodes(kid, tier)
		for p: Vector3 in d.get("houses", []):
			out.append(RoadNode.new(_w2c(p), "house"))
		for p: Vector3 in d.get("towers", []):
			out.append(RoadNode.new(_w2c(p), "tower"))

	if windmills_ref and windmills_ref.has_method("get_road_nodes"):
		for p: Vector3 in windmills_ref.get_road_nodes(kid):
			out.append(RoadNode.new(_w2c(p), "windmill"))

	if decor_ref and decor_ref.has_method("get_road_nodes"):
		for p: Vector3 in decor_ref.get_road_nodes(kid, tier):
			out.append(RoadNode.new(_w2c(p), "farm"))

	return out

# ── Connection planning ───────────────────────────────────────────────────

func _plan(nodes: Array, pct: float, tier: int) -> Array:
	var castle: RoadNode = nodes[0]
	var houses   := nodes.filter(func(n: RoadNode) -> bool: return n.kind == "house")
	var towers   := nodes.filter(func(n: RoadNode) -> bool: return n.kind == "tower")
	var mills    := nodes.filter(func(n: RoadNode) -> bool: return n.kind == "windmill")
	var farms    := nodes.filter(func(n: RoadNode) -> bool: return n.kind == "farm")
	var out: Array = []

	# 5%+: Castle → nearest house (first real road)
	if pct >= 0.05 and houses.size() > 0:
		out.append(_mk(castle.cell, _nearest(castle.cell, houses).cell, W_PRIMARY))

	# 10%+: Castle → each windmill
	if pct >= 0.10:
		for wm: RoadNode in mills:
			out.append(_mk(castle.cell, wm.cell, W_PRIMARY))

	# 20%+: Castle → towers; begin house web (up to 4 edges)
	if pct >= 0.20:
		for t: RoadNode in towers:
			out.append(_mk(castle.cell, t.cell, W_PRIMARY))
		out.append_array(_mst(houses, W_SECONDARY, 4))

	# 30%+: Castle → nearest farm; more houses (7 edges)
	if pct >= 0.30 and farms.size() > 0:
		out.append(_mk(castle.cell, _nearest(castle.cell, farms).cell, W_PRIMARY))
		out.append_array(_mst(houses, W_SECONDARY, 7))

	# 50%+: Farm-cluster connections
	if pct >= 0.50:
		out.append_array(_mst(farms, W_SECONDARY, 5))

	# 70%+: Dense house network
	if pct >= 0.70:
		out.append_array(_mst(houses, W_SECONDARY, 12))

	return _dedup(out)

func _mk(f: Vector2i, t: Vector2i, hw: float) -> Conn:
	var c := Conn.new(); c.from_cell = f; c.to_cell = t; c.half_w = hw; return c

func _nearest(origin: Vector2i, pool: Array) -> RoadNode:
	var best: RoadNode = pool[0]
	var best_d := _mdist(origin, pool[0].cell)
	for n: RoadNode in pool:
		var d := _mdist(origin, n.cell)
		if d < best_d: best_d = d; best = n
	return best

# Prim's MST: connects all nodes greedily, capped at max_edges
func _mst(nodes: Array, hw: float, max_edges: int) -> Array:
	if nodes.size() < 2: return []
	var out: Array = []
	var in_tree: Array = [nodes[0]]
	var limit := mini(max_edges, nodes.size() - 1)
	for _k in limit:
		var best_d := 99999; var bf: RoadNode = null; var bt: RoadNode = null
		for a: RoadNode in in_tree:
			for b: RoadNode in nodes:
				if b in in_tree: continue
				var d := _mdist(a.cell, b.cell)
				if d < best_d: best_d = d; bf = a; bt = b
		if bf == null: break
		in_tree.append(bt)
		out.append(_mk(bf.cell, bt.cell, hw))
	return out

func _dedup(conns: Array) -> Array:
	var seen := {}; var out: Array = []
	for c: Conn in conns:
		var k := str(c.from_cell) + "|" + str(c.to_cell)
		var kr := str(c.to_cell)  + "|" + str(c.from_cell)
		if not seen.has(k) and not seen.has(kr):
			seen[k] = true; out.append(c)
	return out

# ── A* pathfinding on the territory grid ─────────────────────────────────

func _astar(kid: int, from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if from == to:
		return PackedVector2Array([Vector2(from.x, from.y)])

	# open[cell] = {g, f, parent}
	var open  := {}
	var closed := {}
	open[from] = {"g": 0.0, "f": float(_mdist(from, to)), "parent": Vector2i(-1, -1)}

	const DIRS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	for _iter in ASTAR_CAP:
		if open.is_empty(): break

		# Find lowest-f node (linear scan; open list stays small for kingdom-scale paths)
		var cur := Vector2i(-1, -1); var cur_f := INF
		for k: Vector2i in open:
			if open[k].f < cur_f: cur_f = open[k].f; cur = k

		if cur == to:
			return _reconstruct(open, closed, to)

		var node: Dictionary = open[cur]
		closed[cur] = node
		open.erase(cur)

		for d: Vector2i in DIRS:
			var nb := cur + d
			if not _inb(nb) or closed.has(nb): continue
			var cost := _cost(kid, nb)
			if cost >= 100.0: continue
			var g: float = node.g + cost
			var f: float = g + float(_mdist(nb, to))
			if open.has(nb) and open[nb].g <= g: continue
			open[nb] = {"g": g, "f": f, "parent": cur}

	return _bresenham(from, to)   # fallback if A* exhausted

func _reconstruct(open: Dictionary, closed: Dictionary, end: Vector2i) -> PackedVector2Array:
	var path: Array[Vector2i] = []
	var cur := end
	while cur != Vector2i(-1, -1):
		path.append(cur)
		var data = open.get(cur, closed.get(cur, null))
		if data == null: break
		cur = data.parent
	path.reverse()
	var r := PackedVector2Array()
	for c: Vector2i in path: r.append(Vector2(float(c.x), float(c.y)))
	return r

func _cost(kid: int, cell: Vector2i) -> float:
	var owner: int = grid.owner[cell.y * GW + cell.x]
	if owner == kid: return 1.0        # own land: cheap → roads stick to the kingdom
	if owner == 0:   return 2.5        # neutral
	return 4.5                          # enemy territory: avoid

func _bresenham(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var r := PackedVector2Array()
	var dx := absi(to.x - from.x); var dy := absi(to.y - from.y)
	var sx := 1 if to.x > from.x else -1
	var sy := 1 if to.y > from.y else -1
	var err := dx - dy; var cur := from
	for _i in dx + dy + 2:
		r.append(Vector2(float(cur.x), float(cur.y)))
		if cur == to: break
		var e2 := 2 * err
		if e2 > -dy: err -= dy; cur.x += sx
		if e2 <  dx: err += dx; cur.y += sy
	return r

# ── Tile mesh generation ──────────────────────────────────────────────────

# One flat quad per road cell, sized to ROAD_TILE or PLAZA_TILE fraction of CELL.
func _build_tile_mesh(road_cells: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in road_cells:
		var cell_type: int = road_cells[cell]
		var scale: float = PLAZA_TILE if cell_type == 2 else ROAD_TILE
		_add_tile(st, cell, CELL * scale * 0.5)
	st.generate_normals()
	return st.commit()

# Single flat quad at the grid cell's world position.
# CCW winding → face normal +Y → visible from the overhead camera.
func _add_tile(st: SurfaceTool, cell: Vector2i, half: float) -> void:
	var c := _c2w(cell)
	var v0 := Vector3(c.x - half, c.y, c.z - half)   # bottom-left
	var v1 := Vector3(c.x + half, c.y, c.z - half)   # bottom-right
	var v2 := Vector3(c.x + half, c.y, c.z + half)   # top-right
	var v3 := Vector3(c.x - half, c.y, c.z + half)   # top-left
	st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
	st.set_uv(Vector2(0, 1)); st.add_vertex(v3)
	st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
	st.set_uv(Vector2(1, 0)); st.add_vertex(v1)

# ── Materials ─────────────────────────────────────────────────────────────

func _build_materials() -> void:
	_mats = []
	# Light sand tile — bright clean path (T1-2, early roads)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_texture = load("res://assets/ground_sand_1.png") as Texture2D
	dirt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dirt.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	dirt.cull_mode      = BaseMaterial3D.CULL_DISABLED
	_mats.append(dirt)
	# Warm sand tile — slightly richer (T3+, late roads / plaza)
	var sand := StandardMaterial3D.new()
	sand.albedo_texture = load("res://assets/ground_sand_0.png") as Texture2D
	sand.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sand.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	sand.cull_mode      = BaseMaterial3D.CULL_DISABLED
	_mats.append(sand)

func _pick_mat(tier: int, pct: float) -> StandardMaterial3D:
	if pct >= 0.50 or tier >= 3: return _mats[1]   # sand roads
	return _mats[0]                                  # dirt roads

# ── Progression ───────────────────────────────────────────────────────────

# Maps territory count + tier to a 0..1 progression fraction.
func _progress(count: int, tier: int) -> float:
	match tier:
		1: return lerpf(0.00, 0.09, clampf(float(count)         / 300.0,  0.0, 1.0))
		2: return lerpf(0.10, 0.34, clampf(float(count - 300)   / 500.0,  0.0, 1.0))
		3: return lerpf(0.35, 0.69, clampf(float(count - 800)   / 1000.0, 0.0, 1.0))
		4: return lerpf(0.70, 1.00, clampf(float(count - 1800)  / 1800.0, 0.0, 1.0))
	return 0.0

# ── Utilities ─────────────────────────────────────────────────────────────

func _c2w(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5 - GW * 0.5) * CELL, ROAD_Y, (cell.y + 0.5 - GH * 0.5) * CELL)

func _w2c(pos: Vector3) -> Vector2i:
	return Vector2i(int(pos.x / CELL + GW * 0.5), int(pos.z / CELL + GH * 0.5))

func _mdist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _inb(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < GW and c.y >= 0 and c.y < GH
