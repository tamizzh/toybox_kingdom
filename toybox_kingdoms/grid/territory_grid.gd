class_name TerritoryGrid
extends RefCounted

# ── DAY 1-3 SPIKE ────────────────────────────────────────────────────────────
# Pure-data core of Toybox Kingdoms. NO nodes, NO art: just the ownership grid,
# per-kingdom trails, and the flood-fill enclosure capture that is the make-or-
# break mechanic. Runs headless so we can prove correctness + measure cost before
# committing to a renderer.
#
# Design decisions being validated here:
#   * Ownership is a flat PackedByteArray (1 byte / cell). 0 = neutral, 1..254 =
#     kingdom id, 255 reserved. A 200x150 world is 30 KB — never one node per cell.
#   * Trails are a thin overlay (trail_owner byte grid + an ordered cell list per
#     kingdom) so cut-detection is O(1) and revert-on-death is trivial.
#   * Capture floods the OUTSIDE of the trail's bounding box (the Paper.io trick):
#     anything the outside flood can't reach is enclosed -> captured. Crucially the
#     flood is bounded to bbox(trail)+1, so capture cost scales with the LOOP you
#     drew, NOT with how big your kingdom already is.
# ─────────────────────────────────────────────────────────────────────────────

const NEUTRAL := 0

var w: int = 0
var h: int = 0
var owner: PackedByteArray = PackedByteArray()        # w*h, settled ownership
var trail_owner: PackedByteArray = PackedByteArray()  # w*h, pending-trail overlay

# Per-kingdom bookkeeping (kept incrementally so the HUD never scans the grid).
var _count := {}     # id -> int   territory cell count
var _trail := {}     # id -> Array[int]   ordered trail cell indices

# Dirty rectangle so a future renderer only re-uploads what changed this frame.
var dirty_min := Vector2i(0, 0)
var dirty_max := Vector2i(-1, -1)   # empty when max < min

# Bounding box of the most recent capture (for the claim-flash VFX).
var _last_cap_min := Vector2i(0, 0)
var _last_cap_max := Vector2i(-1, -1)

func setup(width: int, height: int) -> void:
	w = width
	h = height
	owner = PackedByteArray()
	owner.resize(w * h)            # zero-filled = all neutral
	trail_owner = PackedByteArray()
	trail_owner.resize(w * h)
	_count.clear()
	_trail.clear()
	reset_dirty()

# ── basic accessors ──────────────────────────────────────────────────────────
func index(x: int, y: int) -> int:
	return y * w + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h

func get_owner(x: int, y: int) -> int:
	return owner[y * w + x]

func territory_count(id: int) -> int:
	return int(_count.get(id, 0))

func trail_length(id: int) -> int:
	var t: Array = _trail.get(id, [])
	return t.size()

# Read-only view of a kingdom's live trail cells (for the renderer). Do not mutate.
func trail_cells(id: int) -> Array:
	return _trail.get(id, [])

# Drop a kingdom's pending trail (e.g. when it is eliminated).
func clear_trail(id: int) -> void:
	_kill_trail(id)

# Hand every cell owned by `from_id` over to `to_id` (castle captured -> whole
# kingdom falls). Returns the number of cells transferred.
func transfer_all(from_id: int, to_id: int) -> int:
	var n := w * h
	var count := 0
	for i in n:
		if int(owner[i]) == from_id:
			_set_owner(i % w, i / w, to_id)
			count += 1
	return count

func has_dirty() -> bool:
	return dirty_max.x >= dirty_min.x

# ── seeding ──────────────────────────────────────────────────────────────────
# Stamp a starting blob of home territory (the kingdom's tiny starting castle land).
func seed_kingdom(id: int, cx: int, cy: int, radius: int) -> void:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= r2:
				var x := cx + dx
				var y := cy + dy
				if in_bounds(x, y):
					_set_owner(x, y, id)

# ── the movement seam ────────────────────────────────────────────────────────
# Call once whenever a ruler's avatar crosses into a NEW cell. Returns what
# happened so the match controller can fire VFX / deaths / score.
#   { captured:int, closed:bool, died:bool, killed:int }
func enter_cell(id: int, x: int, y: int) -> Dictionary:
	var res := {"captured": 0, "closed": false, "died": false, "killed": 0}
	if not in_bounds(x, y):
		return res
	var idx := y * w + x

	# 1. Trail interactions take priority — this cell may hold a pending trail.
	var t := int(trail_owner[idx])
	if t == id:
		# Crossed our own live trail -> we cut ourselves off and die.
		res["died"] = true
		_kill_trail(id)
		return res
	elif t != NEUTRAL:
		# Cut a rival's trail before they could close it -> they die, we live.
		_kill_trail(t)
		res["killed"] = t

	# 2. Territory logic.
	var o := int(owner[idx])
	if o == id:
		# Stepped back onto home soil. If we had a trail out, close + capture.
		if not (_trail.get(id, []) as Array).is_empty():
			res["captured"] = _capture(id)
			res["closed"] = true
			res["cmin"] = _last_cap_min
			res["cmax"] = _last_cap_max
	else:
		# Outside our borders (neutral or enemy soil) -> extend the trail.
		trail_owner[idx] = id
		var tr: Array = _trail.get(id, [])
		tr.append(idx)
		_trail[id] = tr
	return res

# ── enclosure capture (the core algorithm) ───────────────────────────────────
func _capture(id: int) -> int:
	var trail: Array = _trail.get(id, [])
	if trail.is_empty():
		return 0

	# bbox(trail) padded by 1 and clamped. The enclosed pocket is always inside
	# this box because the trail wraps it, so we never flood the whole world.
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for cell in trail:
		var cx: int = cell % w
		var cy: int = cell / w
		x0 = mini(x0, cx); y0 = mini(y0, cy)
		x1 = maxi(x1, cx); y1 = maxi(y1, cy)
	x0 = maxi(0, x0 - 1); y0 = maxi(0, y0 - 1)
	x1 = mini(w - 1, x1 + 1); y1 = mini(h - 1, y1 + 1)
	_last_cap_min = Vector2i(x0, y0)
	_last_cap_max = Vector2i(x1, y1)
	var bw := x1 - x0 + 1
	var bh := y1 - y0 + 1
	var n := bw * bh

	# blocked = our own soil OR our trail (the flood may not pass through either).
	var blocked := PackedByteArray()
	blocked.resize(n)
	for ly in bh:
		var gy := y0 + ly
		var grow := gy * w
		var brow := ly * bw
		for lx in bw:
			var gidx := grow + x0 + lx
			if int(owner[gidx]) == id or int(trail_owner[gidx]) == id:
				blocked[brow + lx] = 1

	# Flood the OUTSIDE: start from every non-blocked border cell of the bbox.
	var visited := PackedByteArray()
	visited.resize(n)
	var stack: Array[int] = []
	for lx in bw:
		_try_seed(stack, visited, blocked, lx)                 # top edge
		_try_seed(stack, visited, blocked, (bh - 1) * bw + lx) # bottom edge
	for ly in bh:
		_try_seed(stack, visited, blocked, ly * bw)            # left edge
		_try_seed(stack, visited, blocked, ly * bw + bw - 1)   # right edge

	while not stack.is_empty():
		var li: int = stack.pop_back()
		var lx2: int = li % bw
		var ly2: int = li / bw
		if lx2 > 0:
			var a := li - 1
			if blocked[a] == 0 and visited[a] == 0:
				visited[a] = 1; stack.append(a)
		if lx2 < bw - 1:
			var b := li + 1
			if blocked[b] == 0 and visited[b] == 0:
				visited[b] = 1; stack.append(b)
		if ly2 > 0:
			var c := li - bw
			if blocked[c] == 0 and visited[c] == 0:
				visited[c] = 1; stack.append(c)
		if ly2 < bh - 1:
			var d := li + bw
			if blocked[d] == 0 and visited[d] == 0:
				visited[d] = 1; stack.append(d)

	# Capture: any bbox cell the outside flood never reached, that we don't
	# already own, is enclosed (or is our trail) -> claim it.
	var captured := 0
	for ly3 in bh:
		var gy3 := y0 + ly3
		var grow3 := gy3 * w
		var brow3 := ly3 * bw
		for lx3 in bw:
			var gidx3 := grow3 + x0 + lx3
			if int(owner[gidx3]) == id:
				continue
			if visited[brow3 + lx3] == 0:
				_set_owner(x0 + lx3, gy3, id)
				captured += 1

	# Trail is now baked into territory.
	for cell in trail:
		trail_owner[cell] = 0
	_trail[id] = []
	return captured

func _try_seed(stack: Array, visited: PackedByteArray, blocked: PackedByteArray, lidx: int) -> void:
	if blocked[lidx] == 0 and visited[lidx] == 0:
		visited[lidx] = 1
		stack.append(lidx)

# ── trail revert (death) ─────────────────────────────────────────────────────
func _kill_trail(id: int) -> void:
	for cell in _trail.get(id, []):
		trail_owner[cell] = 0
	_trail[id] = []

# ── ownership mutation (single choke point for counts + dirty rect) ───────────
func _set_owner(x: int, y: int, new_id: int) -> void:
	var idx := y * w + x
	var old := int(owner[idx])
	if old == new_id:
		return
	if old != NEUTRAL:
		_count[old] = int(_count.get(old, 0)) - 1
	owner[idx] = new_id
	if new_id != NEUTRAL:
		_count[new_id] = int(_count.get(new_id, 0)) + 1
	_mark_dirty(x, y)

func _mark_dirty(x: int, y: int) -> void:
	if dirty_max.x < dirty_min.x:   # currently empty
		dirty_min = Vector2i(x, y)
		dirty_max = Vector2i(x, y)
		return
	dirty_min.x = mini(dirty_min.x, x); dirty_min.y = mini(dirty_min.y, y)
	dirty_max.x = maxi(dirty_max.x, x); dirty_max.y = maxi(dirty_max.y, y)

func reset_dirty() -> void:
	dirty_min = Vector2i(0, 0)
	dirty_max = Vector2i(-1, -1)
