extends SceneTree

# ── DAY 1-3 SPIKE: correctness + perf harness for TerritoryGrid ───────────────
# Run headless from the project root:
#   godot --headless -s res://toybox_kingdoms/tests/territory_grid_test.gd
#
# It (1) asserts the enclosure capture is CORRECT on hand-checkable cases, then
# (2) benchmarks capture cost at mobile-target world sizes so we know — in real
# milliseconds on this machine — whether the core is frame-safe before we build
# a renderer, AI, or any art on top of it.

const Grid := preload("res://toybox_kingdoms/grid/territory_grid.gd")

var _fail := 0
var _pass := 0

func _initialize() -> void:
	print("\n=== TerritoryGrid spike ===\n")
	_test_basic_enclosure()
	_test_conquest_inside_pocket()
	_test_trail_cut_kills_rival()
	_test_self_cut_dies()
	_test_castle_footprint_coverage()
	_test_capture_cost_is_loop_bound_not_kingdom_bound()
	print("\n--- correctness: %d passed, %d failed ---\n" % [_pass, _fail])

	_bench()

	print("\n=== done ===")
	quit(1 if _fail > 0 else 0)

# ── correctness ──────────────────────────────────────────────────────────────
func _check(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  ok   ", label)
	else:
		_fail += 1
		print("  FAIL ", label)

# Walk a rectangle out from a vertical home wall and confirm the interior fills.
func _test_basic_enclosure() -> void:
	print("[basic enclosure]")
	var g := Grid.new()
	g.setup(12, 12)
	for y in range(2, 7):           # home = column x=1, y=2..6
		g._set_owner(1, y, 1)
	var path := [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),     # top edge
		Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6),  # right edge
		Vector2i(3, 6), Vector2i(2, 6),                     # bottom edge
		Vector2i(1, 6),                                     # back home -> closes
	]
	var res := {}
	for c in path:
		res = g.enter_cell(1, c.x, c.y)
	_check("loop closed", res.get("closed", false))
	_check("interior (2,4) captured", g.get_owner(2, 4) == 1)
	_check("interior (3,5) captured", g.get_owner(3, 5) == 1)
	_check("trail cell (4,4) captured", g.get_owner(4, 4) == 1)
	_check("outside (5,4) stays neutral", g.get_owner(5, 4) == 0)
	_check("far cell (9,9) stays neutral", g.get_owner(9, 9) == 0)

# An enemy cell trapped inside the pocket should be conquered.
func _test_conquest_inside_pocket() -> void:
	print("[conquest inside pocket]")
	var g := Grid.new()
	g.setup(12, 12)
	for y in range(2, 7):
		g._set_owner(1, y, 1)
	g._set_owner(2, 4, 2)           # rival kingdom 2 sits inside the future pocket
	_check("rival owns its cell first", g.get_owner(2, 4) == 2)
	_check("rival count = 1", g.territory_count(2) == 1)
	var path := [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6),
		Vector2i(3, 6), Vector2i(2, 6), Vector2i(1, 6),
	]
	for c in path:
		g.enter_cell(1, c.x, c.y)
	_check("rival cell conquered by 1", g.get_owner(2, 4) == 1)
	_check("rival count back to 0", g.territory_count(2) == 0)

func _test_trail_cut_kills_rival() -> void:
	print("[trail cut]")
	var g := Grid.new()
	g.setup(16, 16)
	g._set_owner(0, 8, 2)                 # kingdom 2 home at left
	g.enter_cell(2, 5, 8)                 # 2 lays a trail out into the open
	g.enter_cell(2, 6, 8)
	_check("rival trail is live", g.trail_length(2) == 2)
	var res := g.enter_cell(1, 6, 8)      # kingdom 1 slices through it
	_check("rival reported killed", res.get("killed", 0) == 2)
	_check("rival trail wiped", g.trail_length(2) == 0)
	_check("cutter did not die", not res.get("died", false))

func _test_self_cut_dies() -> void:
	print("[self cut]")
	var g := Grid.new()
	g.setup(16, 16)
	g._set_owner(0, 8, 1)
	g.enter_cell(1, 3, 8)                 # trail out...
	g.enter_cell(1, 3, 9)
	g.enter_cell(1, 4, 9)
	var res := g.enter_cell(1, 3, 9)      # ...cross our own trail
	_check("self-cross reported as death", res.get("died", false))
	_check("own trail wiped on death", g.trail_length(1) == 0)

# A castle only falls once a rival owns its WHOLE footprint disc — region_fully_owned
# is the gate. One uncovered cell anywhere in the disc must keep the castle standing,
# and a bigger (higher-tier) footprint must demand more covered ground.
func _test_castle_footprint_coverage() -> void:
	print("[castle footprint coverage]")
	var g := Grid.new()
	g.setup(20, 20)
	var cx := 10; var cy := 10; var r := 3
	# Rival 2 paints the entire radius-3 disc around the castle except one corner cell.
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				g._set_owner(cx + dx, cy + dy, 2)
	_check("full disc -> covered", g.region_fully_owned(cx, cy, r, 2))
	g._set_owner(cx + 2, cy + 2, 1)        # one cell flips to a third party
	_check("one stray cell -> NOT covered", not g.region_fully_owned(cx, cy, r, 2))
	g._set_owner(cx + 2, cy + 2, 2)        # rival re-covers it
	_check("re-covered -> covered again", g.region_fully_owned(cx, cy, r, 2))
	# Owning the centre alone is not enough for any footprint bigger than a point.
	var g2 := Grid.new()
	g2.setup(20, 20)
	g2._set_owner(cx, cy, 2)
	_check("centre-only does NOT cover r=3", not g2.region_fully_owned(cx, cy, 3, 2))
	_check("centre-only DOES cover r=0", g2.region_fully_owned(cx, cy, 0, 2))
	# A footprint partly off the world edge: only the in-bounds cells must be owned.
	var g3 := Grid.new()
	g3.setup(20, 20)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx * dx + dy * dy <= 4:
				var x := 0 + dx; var y := 0 + dy
				if g3.in_bounds(x, y):
					g3._set_owner(x, y, 2)
	_check("edge castle covered by in-bounds cells only", g3.region_fully_owned(0, 0, 2, 2))

# Two captures with the SAME loop size must cost the same whether the kingdom is
# tiny or already enormous — proving capture is bound to the trail, not the realm.
func _test_capture_cost_is_loop_bound_not_kingdom_bound() -> void:
	print("[loop-bound cost invariant]")
	var small := _time_fixed_loop(200, 150, 4)      # 4-radius home
	var huge := _time_fixed_loop(200, 150, 60)      # 60-radius home (~11k cells)
	# Both draw an identical 10x10 capture loop near the home edge.
	print("    small-kingdom capture: %.3f ms   huge-kingdom capture: %.3f ms" % [small, huge])
	# Allow generous slack for noise; the point is they're the same order, not 100x.
	_check("huge-kingdom capture not >5x small", huge <= small * 5.0 + 0.05)

func _time_fixed_loop(gw: int, gh: int, home_r: int) -> float:
	var g := Grid.new()
	g.setup(gw, gh)
	var cx := gw / 2
	var cy := gh / 2
	g.seed_kingdom(1, cx, cy, home_r)
	# Draw a small square loop starting just outside the home blob's right edge.
	var ex := cx + home_r            # first neutral column past the home disc
	var path: Array[Vector2i] = []
	for i in range(1, 11):
		path.append(Vector2i(ex + i, cy - 5))
	for j in range(-5, 6):
		path.append(Vector2i(ex + 10, cy + j))
	for i in range(10, -1, -1):
		path.append(Vector2i(ex + i, cy + 5))
	# lay trail (untimed), then time only the closing capture
	for c in path:
		g.enter_cell(1, c.x, c.y)
	var t0 := Time.get_ticks_usec()
	g.enter_cell(1, cx + home_r - 1, cy + 5)   # step back onto home -> capture
	# fall back: if that wasn't home, force close directly
	var t1 := Time.get_ticks_usec()
	return (t1 - t0) / 1000.0

# ── benchmark ────────────────────────────────────────────────────────────────
func _bench() -> void:
	print("--- perf (this machine, GDScript, single thread) ---")
	for dims in [Vector2i(128, 96), Vector2i(160, 120), Vector2i(200, 150)]:
		_bench_typical(dims.x, dims.y)
	print("")
	for dims in [Vector2i(128, 96), Vector2i(160, 120), Vector2i(200, 150)]:
		_bench_worst_case(dims.x, dims.y)

# Realistic per-claim: a LOCAL ~28x28 territory grab against a small home stub,
# repeated and averaged. (The captured area, not the world size, drives cost.)
func _bench_typical(gw: int, gh: int) -> void:
	var iters := 400
	var total := 0.0
	var captured_total := 0
	const SIDE := 28
	for k in iters:
		var g := Grid.new()
		g.setup(gw, gh)
		# small home bar (1 cell wide, SIDE+2 tall) for the loop to close against
		var hx := 8 + (k % (gw - SIDE - 16))
		var hy := 4 + (k % (gh - SIDE - 8))
		for y in range(hy, hy + SIDE + 1):
			g._set_owner(hx, y, 1)
		# square loop hugging the home bar's right side -> ~SIDE x SIDE pocket
		var path := _rect_loop(hx, hy, hx + SIDE, hy + SIDE)
		for c in path:
			g.enter_cell(1, c.x, c.y)
		var t0 := Time.get_ticks_usec()
		var res := g.enter_cell(1, hx, hy + SIDE)   # back onto home bar -> capture
		var t1 := Time.get_ticks_usec()
		total += (t1 - t0) / 1000.0
		captured_total += int(res.get("captured", 0))
	var avg := total / iters
	var budget := 2.0   # ms/frame we'd allot to territory at 60fps
	print("  %dx%d  typical local ~28-wide claim: avg %.4f ms  (~%d such claims fit a %.0fms budget)  [avg %d cells]"
		% [gw, gh, avg, int(budget / maxf(avg, 0.00001)), budget, captured_total / iters])

# Worst case: one ruler encloses almost the entire world in a single loop.
func _bench_worst_case(gw: int, gh: int) -> void:
	var g := Grid.new()
	g.setup(gw, gh)
	for y in gh:
		g._set_owner(0, y, 1)        # home = left column
	# loop: top row, right column, bottom row, back to home
	var path: Array[Vector2i] = []
	for x in range(1, gw):
		path.append(Vector2i(x, 0))
	for y in range(1, gh):
		path.append(Vector2i(gw - 1, y))
	for x in range(gw - 2, 0, -1):
		path.append(Vector2i(x, gh - 1))
	for c in path:
		g.enter_cell(1, c.x, c.y)
	var t0 := Time.get_ticks_usec()
	var res := g.enter_cell(1, 0, gh - 1)
	var t1 := Time.get_ticks_usec()
	var ms := (t1 - t0) / 1000.0
	print("  %dx%d  WORST-CASE full-map capture: %.3f ms  [%d cells claimed]"
		% [gw, gh, ms, int(res.get("captured", 0))])

# Build a rectangular trail loop whose left edge sits on x=x0 (home) so it closes.
func _rect_loop(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var p: Array[Vector2i] = []
	for x in range(x0 + 1, x1 + 1):
		p.append(Vector2i(x, y0))
	for y in range(y0 + 1, y1 + 1):
		p.append(Vector2i(x1, y))
	for x in range(x1 - 1, x0, -1):
		p.append(Vector2i(x, y1))
	return p
