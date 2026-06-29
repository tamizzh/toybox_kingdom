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
#     kingdom id, 255 reserved. The 384x288 world is ~110 KB — never one node per cell.
#   * Trails are a thin overlay (trail_owner byte grid + an ordered cell list per
#     kingdom) so cut-detection is O(1) and revert-on-death is trivial.
#   * Capture floods the OUTSIDE from the WORLD perimeter (the Paper.io trick):
#     anything the outside flood can't reach is enclosed -> captured. The flood spans
#     the board so concave notches can't leak, but the O(n) build + finalize scans are
#     clamped to bbox(this kingdom's land ∪ trail), and the flood scratch buffers are
#     reused across captures — so a small loop costs little even on a big board.
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

# Monotonic ownership version: bumped on every actual cell-owner change. Decoration
# layers (populace/flags/borders) compare against their last-built value so they can
# skip a full rebuild entirely when no land changed since they last ran.
var version: int = 0

# Monotonic trail version: bumped whenever any kingdom's trail cell set changes (extend,
# capture-bake, or death/clear). The renderer rebuilds the trail MultiMesh only when this
# moves — trail cubes sit at fixed cell centres, so between changes the mesh is identical.
var trail_version: int = 0

# Bounding box of the most recent capture (for the claim-flash VFX).
var _last_cap_min := Vector2i(0, 0)
var _last_cap_max := Vector2i(-1, -1)

# Bounding box of ALL owned cells (any kingdom). Grows whenever land is claimed; it
# is deliberately NOT shrunk on loss (a loose box is still correct and rarely matters
# — territory spreads outward over a match anyway). Full-board scans (populace/decor/
# slabs/flags/capture) clamp their loops to this box so early/mid-game work scales with
# the played area, not the whole 110k-cell board. Empty when owned_max < owned_min.
var owned_min := Vector2i(0, 0)
var owned_max := Vector2i(-1, -1)

# Reusable scratch buffers for _capture()'s flood — sized once in setup() so a capture
# (every few seconds in play) does a cheap memset instead of allocating two w*h byte
# arrays + churning the GC each time.
var _blocked := PackedByteArray()
var _visited := PackedByteArray()

func setup(width: int, height: int) -> void:
	w = width
	h = height
	owner = PackedByteArray()
	owner.resize(w * h)            # zero-filled = all neutral
	trail_owner = PackedByteArray()
	trail_owner.resize(w * h)
	_blocked = PackedByteArray()
	_blocked.resize(w * h)
	_visited = PackedByteArray()
	_visited.resize(w * h)
	_count.clear()
	_trail.clear()
	reset_dirty()
	owned_min = Vector2i(0, 0)
	owned_max = Vector2i(-1, -1)

func has_owned() -> bool:
	return owned_max.x >= owned_min.x

func _grow_owned(x: int, y: int) -> void:
	if owned_max.x < owned_min.x:   # currently empty
		owned_min = Vector2i(x, y)
		owned_max = Vector2i(x, y)
		return
	owned_min.x = mini(owned_min.x, x); owned_min.y = mini(owned_min.y, y)
	owned_max.x = maxi(owned_max.x, x); owned_max.y = maxi(owned_max.y, y)

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

# Transfer only the cells owned by `from_id` that are NEAREST to `target` (vs the
# kingdom's `others` castles) — the captured castle's slice of the realm. If
# `others` is empty (the last castle), this takes everything.
func transfer_nearest(from_id: int, to_id: int, target: Vector2i, others: Array) -> int:
	var n := w * h
	var count := 0
	for i in n:
		if int(owner[i]) != from_id:
			continue
		var cx := i % w
		var cy := i / w
		var dt := (cx - target.x) * (cx - target.x) + (cy - target.y) * (cy - target.y)
		var nearest := true
		for o in others:
			var ox: int = o.x
			var oy: int = o.y
			if (cx - ox) * (cx - ox) + (cy - oy) * (cy - oy) < dt:
				nearest = false
				break
		if nearest:
			_set_owner(cx, cy, to_id)
			count += 1
	return count

# True only when EVERY in-bounds cell of the disc of `radius` around (cx,cy) is owned
# by `id`. A castle is taken only once a conqueror covers its WHOLE footprint, so the
# match controller passes a radius that grows with the castle's tier — a bigger castle
# demands more ground be engulfed before it falls. Out-of-bounds cells (castle near a
# world edge) are skipped: you can't own cells that don't exist.
func region_fully_owned(cx: int, cy: int, radius: int, id: int) -> bool:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var x := cx + dx
			var y := cy + dy
			if not in_bounds(x, y):
				continue
			if int(owner[y * w + x]) != id:
				return false
	return true

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
		pass  # Self-crossing is harmless; just continue normally.
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
		trail_version += 1
	return res

# ── enclosure capture (the core algorithm) ───────────────────────────────────
func _capture(id: int) -> int:
	var trail: Array = _trail.get(id, [])
	if trail.is_empty():
		return 0

	# Record bbox of the trail for the capture-flash VFX (renderer uses this).
	var fx0 := w; var fy0 := h; var fx1 := -1; var fy1 := -1
	for cell in trail:
		var cx: int = cell % w; var cy: int = cell / w
		fx0 = mini(fx0, cx); fy0 = mini(fy0, cy)
		fx1 = maxi(fx1, cx); fy1 = maxi(fy1, cy)
	_last_cap_min = Vector2i(fx0, fy0)
	_last_cap_max = Vector2i(fx1, fy1)

	# Work box = bbox of (this kingdom's territory ∪ its trail). The enclosure can only
	# touch cells inside this box, so the per-capture build + finalize loops scan it
	# instead of the whole 110k-cell board. (The owned box is the global owned extent —
	# a safe superset of this kingdom's territory.) The flood itself still runs over the
	# whole board so concave notches can't leak; only the O(n) scans are bounded.
	var bx0 := fx0; var by0 := fy0; var bx1 := fx1; var by1 := fy1
	if owned_max.x >= owned_min.x:
		bx0 = mini(bx0, owned_min.x); by0 = mini(by0, owned_min.y)
		bx1 = maxi(bx1, owned_max.x); by1 = maxi(by1, owned_max.y)

	# blocked = our own soil OR our trail (the flood may not pass through either).
	# Reused scratch buffers: memset to 0, then stamp only the work box.
	var blocked := _blocked
	var visited := _visited
	blocked.fill(0)
	visited.fill(0)
	for by in range(by0, by1 + 1):
		var brow := by * w
		for bx in range(bx0, bx1 + 1):
			var bi := brow + bx
			if int(owner[bi]) == id or int(trail_owner[bi]) == id:
				blocked[bi] = 1

	# Flood the OUTSIDE from the world perimeter. Using the world boundary instead
	# of just the trail bbox prevents the flood from leaking through concave gaps in
	# the territory wall — a neutral notch inside the bbox edge would seed the flood
	# inside the enclosure with the old bbox approach.
	var stack: Array[int] = []
	for x in w:
		_try_seed(stack, visited, blocked, x)             # top row
		_try_seed(stack, visited, blocked, (h - 1) * w + x) # bottom row
	for y in h:
		_try_seed(stack, visited, blocked, y * w)         # left col
		_try_seed(stack, visited, blocked, y * w + w - 1) # right col

	while not stack.is_empty():
		var gi: int = stack.pop_back()
		var gx: int = gi % w
		var gy: int = gi / w
		if gx > 0:
			var a := gi - 1
			if blocked[a] == 0 and visited[a] == 0:
				visited[a] = 1; stack.append(a)
		if gx < w - 1:
			var b := gi + 1
			if blocked[b] == 0 and visited[b] == 0:
				visited[b] = 1; stack.append(b)
		if gy > 0:
			var c := gi - w
			if blocked[c] == 0 and visited[c] == 0:
				visited[c] = 1; stack.append(c)
		if gy < h - 1:
			var d := gi + w
			if blocked[d] == 0 and visited[d] == 0:
				visited[d] = 1; stack.append(d)

	# Capture: any cell INSIDE the work box the outside flood never reached that we
	# don't already own. Cells outside the box are all flood-reachable neutral, so they
	# can never be enclosed — no need to scan them.
	var captured := 0
	for cy in range(by0, by1 + 1):
		var crow := cy * w
		for cx in range(bx0, bx1 + 1):
			var i := crow + cx
			if int(owner[i]) == id:
				continue
			if visited[i] == 0:
				_set_owner(cx, cy, id)
				captured += 1

	# Trail is now baked into territory.
	for cell in trail:
		trail_owner[cell] = 0
	_trail[id] = []
	trail_version += 1
	return captured

func _try_seed(stack: Array, visited: PackedByteArray, blocked: PackedByteArray, idx: int) -> void:
	if blocked[idx] == 0 and visited[idx] == 0:
		visited[idx] = 1
		stack.append(idx)

# ── trail revert (death) ─────────────────────────────────────────────────────
func _kill_trail(id: int) -> void:
	for cell in _trail.get(id, []):
		trail_owner[cell] = 0
	_trail[id] = []
	trail_version += 1

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
		_grow_owned(x, y)
	version += 1
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
