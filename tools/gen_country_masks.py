#!/usr/bin/env python3
"""
tools/gen_country_masks.py
--------------------------
Downloads Natural Earth 1:110m country polygons and rasterizes 20 countries
onto a 128x96 grid (one byte per cell: 1=land, 0=ocean).

Outputs:
  toybox_kingdoms/data/country_masks.gd   — GDScript const with all masks + metadata

Usage:
  python tools/gen_country_masks.py

Requires only Python stdlib (urllib, json). No pip packages needed.
"""

import json
import math
import os
import struct
import urllib.request

# ── Config ──────────────────────────────────────────────────────────────────
GRID_W = 384
GRID_H = 288
PADDING = 0.03   # fraction of grid to leave as border around the country shape

# ── Toy-paper stylization ────────────────────────────────────────────────────
# Real Natural Earth outlines are survey-accurate, which reads as an atlas, not a
# toy. We chunk them up: Douglas-Peucker drops fine coastline detail, then Chaikin
# corner-cutting rounds the angular result into smooth paper-cut curves. The net
# look is a recognizable-but-abstract "Risk territory" blob. As a bonus this
# dissolves disputed-border slivers — so we deliberately SKIP it for India, whose
# official point-of-view outline must stay exact.
SIMPLIFY = True
SKIP_SIMPLIFY = set()  # all countries get toy-paper rounding; India still uses POV:ind data
SIMPLIFY_FRAC = 0.008   # Douglas-Peucker tolerance as a fraction of bbox diagonal
CHAIKIN_PASSES = 2      # corner-cutting rounds (each pass ~2x points, smoother)

# Natural Earth 1:110m countries — small (~400 KB), good enough for 128×96 cells.
GEOJSON_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    "master/geojson/ne_110m_admin_0_countries.geojson"
)

# ── Per-country point-of-view (POV) overrides ────────────────────────────────
# Natural Earth ships sovereign "point-of-view" datasets that draw disputed
# borders the way a given government depicts them. We use these so India and
# the USA show their OFFICIAL outlines instead of the neutral de-facto lines.
#   • India  ("ind"): full Jammu & Kashmir (incl. Gilgit-Baltistan / PoK),
#                     Aksai Chin and Arunachal Pradesh as Indian territory.
#   • USA    ("usa"): the United States' own depiction.
# POV files only exist at 1:10m, so they're larger (~25 MB each, cached locally).
POV_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    "master/geojson/ne_10m_admin_0_countries_{code}.geojson"
)
# natural_earth_name -> POV file code
POV_SOURCE = {
    "India": "ind",
    "United States of America": "usa",
}
# Countries whose overseas/detached landmasses we KEEP (skip the mainland-only
# distance filter). The USA keeps Alaska + Hawaii here per the user's choice.
KEEP_ALL_RINGS = set()  # USA: contiguous 48 only (Alaska/Hawaii stretch the bbox too much)

# The 20 countries in conquest order (easy → hard by shape complexity + size).
# Each entry: (natural_earth_name, display_name, hue_hex, rival_count)
# rival_count maps to endless difficulty: 3 easy → 7 hard
COUNTRIES = [
    ("France",                        "France",       "0055A4", 3),
    ("Italy",                         "Italy",        "009246", 3),
    ("Germany",                       "Germany",      "FFCE00", 3),
    ("Spain",                         "Spain",        "AA151B", 4),
    ("United Kingdom",                "UK",           "012169", 4),
    ("Egypt",                         "Egypt",        "CE1126", 4),
    ("Turkey",                        "Turkey",       "E30A17", 4),
    ("Nigeria",                       "Nigeria",      "008751", 5),
    ("Mexico",                        "Mexico",       "006847", 5),
    ("Argentina",                     "Argentina",    "74ACDF", 5),
    ("South Korea",                   "South Korea",  "CD2E3A", 5),
    ("Japan",                         "Japan",        "BC002D", 5),
    ("United States of America",      "USA",          "B22234", 6),
    ("China",                         "China",        "DE2910", 6),
    ("India",                         "India",        "FF9933", 6),
    ("Brazil",                        "Brazil",       "009C3B", 6),
    ("Canada",                        "Canada",       "FF0000", 7),
    ("Australia",                     "Australia",    "00008B", 7),
    ("Russia",                        "Russia",       "D52B1E", 7),
    ("South Africa",                  "South Africa", "007A4D", 7),
]
# NOTE: the emitted order is RE-SORTED by land-cell count (ascending) in main(),
# so in-game islands grow in size as you progress. The `rivals` value above is a
# placeholder — it's overwritten per final rank to match the index-derived
# difficulty curve in kingdom_match._endless_rivals_for (3 + island/2).

OUT_PATH = os.path.join(
    os.path.dirname(__file__), "..", "toybox_kingdoms", "data", "country_masks.gd"
)


# ── Geometry helpers ─────────────────────────────────────────────────────────

def _ring_centroid(ring):
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    return sum(xs) / len(xs), sum(ys) / len(ys)


def _ring_area(ring):
    """Shoelace formula — returns absolute area in deg^2."""
    n = len(ring)
    a = 0.0
    for i in range(n):
        x0, y0 = ring[i][0], ring[i][1]
        x1, y1 = ring[(i + 1) % n][0], ring[(i + 1) % n][1]
        a += x0 * y1 - x1 * y0
    return abs(a) * 0.5


def _perp_dist(p, a, b):
    """Perpendicular distance from point p to the segment a→b (deg)."""
    ax, ay = a[0], a[1]
    bx, by = b[0], b[1]
    px, py = p[0], p[1]
    dx, dy = bx - ax, by - ay
    if dx == 0.0 and dy == 0.0:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def _douglas_peucker(points, tol):
    """Ramer-Douglas-Peucker polyline simplification. `points` is a list of
    [lon, lat]; returns a reduced list keeping the overall silhouette."""
    if len(points) < 3:
        return points
    dmax, idx = 0.0, 0
    a, b = points[0], points[-1]
    for i in range(1, len(points) - 1):
        d = _perp_dist(points[i], a, b)
        if d > dmax:
            dmax, idx = d, i
    if dmax > tol:
        left = _douglas_peucker(points[:idx + 1], tol)
        right = _douglas_peucker(points[idx:], tol)
        return left[:-1] + right
    return [a, b]


def _chaikin(points, passes):
    """Chaikin corner-cutting on a CLOSED ring → smooth rounded curve.
    Input/output rings are closed (first point repeated at the end)."""
    pts = points[:-1] if points and points[0] == points[-1] else list(points)
    if len(pts) < 3:
        return points
    for _ in range(passes):
        out = []
        n = len(pts)
        for i in range(n):
            p0 = pts[i]
            p1 = pts[(i + 1) % n]
            out.append([0.75 * p0[0] + 0.25 * p1[0], 0.75 * p0[1] + 0.25 * p1[1]])
            out.append([0.25 * p0[0] + 0.75 * p1[0], 0.25 * p0[1] + 0.75 * p1[1]])
        pts = out
    pts.append(pts[0])   # re-close the ring
    return pts


def _stylize_rings(rings):
    """Chunk-and-round every ring into a toy-paper silhouette: Douglas-Peucker to
    shed fine detail, then Chaikin to round the corners. Tolerance scales with the
    shape's bounding-box diagonal so big and small countries chunk proportionally.
    Rings that would collapse below a triangle are left untouched."""
    lon_min, lat_min, lon_max, lat_max = _bbox(rings)
    diag = math.hypot(lon_max - lon_min, lat_max - lat_min)
    tol = SIMPLIFY_FRAC * diag
    out = []
    for ring in rings:
        simplified = _douglas_peucker(ring, tol)
        if len(simplified) < 4:
            out.append(ring)          # too small to chunk — keep as-is
            continue
        out.append(_chaikin(simplified, CHAIKIN_PASSES))
    return out


def _flatten_rings(geometry, max_dist_deg=45.0, keep_all=False):
    """
    Return rings that form the main landmass only.
    For countries with overseas territories (France, UK, Russia, USA…) the
    bounding box of ALL polygons is huge — mainland France shrinks to a few
    pixels.  Fix: find the largest-area polygon, compute its centroid, and
    keep only polygons whose centroid is within max_dist_deg of that centroid.
    This keeps Japan's main islands and Indonesia's archipelago while dropping
    French Guiana, Hawaii, Alaska (for the main USA), etc.

    keep_all=True bypasses the distance filter and keeps every outer ring —
    used for the USA so Alaska + Hawaii are included (antimeridian wrap is
    handled later in rasterize_country).
    """
    gtype = geometry["type"]
    coords = geometry["coordinates"]
    if gtype == "Polygon":
        return [coords[0]]
    # MultiPolygon: collect all outer rings with their area
    candidates = [(poly[0], _ring_area(poly[0])) for poly in coords]
    if not candidates:
        return []
    if keep_all:
        return [ring for ring, _area in candidates]
    # Anchor = centroid of the largest ring
    largest = max(candidates, key=lambda x: x[1])[0]
    cx, cy = _ring_centroid(largest)
    kept = []
    for ring, area in candidates:
        rcx, rcy = _ring_centroid(ring)
        dist = math.hypot(rcx - cx, rcy - cy)
        if dist <= max_dist_deg:
            kept.append(ring)
    return kept if kept else [largest]


def _bbox(rings):
    """Bounding box (lon_min, lat_min, lon_max, lat_max) across all rings."""
    all_pts = [pt for ring in rings for pt in ring]
    xs = [p[0] for p in all_pts]
    ys = [p[1] for p in all_pts]
    return min(xs), min(ys), max(xs), max(ys)


def _normalize_antimeridian(rings):
    """
    Unwrap longitudes for landmasses that straddle the ±180° antimeridian
    (e.g. Alaska's Aleutian Islands, which Natural Earth stores at both ~+179
    and ~-179). Without this the bounding box spans ~358° and the whole
    country collapses to a sliver after aspect-fit. If the naive lon span
    exceeds 180°, shift every positive-lon point by -360° so the shape becomes
    contiguous (e.g. +172…+180 → -188…-180, west of mainland Alaska).
    No-op for shapes that don't wrap (India, France, …).
    """
    xs = [p[0] for ring in rings for p in ring]
    if not xs or (max(xs) - min(xs)) <= 180.0:
        return rings
    return [[[p[0] - 360.0 if p[0] > 0 else p[0], p[1]] for p in ring]
            for ring in rings]


def _project(lon, lat, lon_min, lat_min, lon_max, lat_max):
    """Map lon/lat → grid cell (cx, cy) with PADDING border."""
    pad_x = PADDING
    pad_y = PADDING
    # Aspect-fit the country shape into the grid preserving its ratio.
    lon_range = lon_max - lon_min
    lat_range = lat_max - lat_min
    if lon_range == 0 or lat_range == 0:
        return 0, 0
    # Available cell area after padding
    avail_w = GRID_W * (1.0 - 2 * pad_x)
    avail_h = GRID_H * (1.0 - 2 * pad_y)
    scale = min(avail_w / lon_range, avail_h / lat_range)
    # Centre the shape in the available area
    cx_start = (GRID_W - lon_range * scale) / 2.0
    cy_start = (GRID_H - lat_range * scale) / 2.0
    cx = cx_start + (lon - lon_min) * scale
    # lat increases upward, grid Y increases downward
    cy = cy_start + (lat_max - lat) * scale
    return int(cx), int(cy)


def _rasterize_ring(ring, lon_min, lat_min, lon_max, lat_max, cells):
    """
    Scanline fill of one polygon ring directly into the GRID_H x GRID_W master
    array using OR. Even-odd intersection pairs within a scanline are disjoint,
    so OR-ing each ring's fill is additive across separate island polygons
    (Alaska, Hawaii, the Andamans…) without one ring cancelling another.
    """
    # Project all vertices to grid space
    pts = [_project(p[0], p[1], lon_min, lat_min, lon_max, lat_max) for p in ring]
    n = len(pts)
    if n < 3:
        return

    for y in range(GRID_H):
        # Find x-intersections of the scanline at y+0.5 with all edges
        intersections = []
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            if y0 == y1:
                continue
            if not (min(y0, y1) <= y < max(y0, y1)):
                continue
            # x coordinate of intersection
            t = (y + 0.5 - y0) / (y1 - y0)
            x_int = x0 + t * (x1 - x0)
            intersections.append(x_int)
        intersections.sort()
        # XOR fill pairs of intersections
        for k in range(0, len(intersections) - 1, 2):
            x_start = max(0, int(math.ceil(intersections[k])))
            x_end   = min(GRID_W - 1, int(intersections[k + 1]))
            row = cells[y]
            for x in range(x_start, x_end + 1):
                row[x] = 1


def rasterize_country(rings):
    """Return a GRID_H x GRID_W list of lists (0/1 per cell).
    Longitudes are unwrapped for antimeridian-straddling shapes first, then
    every outer ring is OR-filled into one shared master grid."""
    rings = _normalize_antimeridian(rings)
    lon_min, lat_min, lon_max, lat_max = _bbox(rings)
    master = [[0] * GRID_W for _ in range(GRID_H)]
    for ring in rings:
        _rasterize_ring(ring, lon_min, lat_min, lon_max, lat_max, master)
    return master


def cells_to_bytes(cells):
    """Flatten 2-D grid row-major into a list of 0/1 ints (one per cell)."""
    return [cells[y][x] for y in range(GRID_H) for x in range(GRID_W)]


# ── GeoJSON fetch ────────────────────────────────────────────────────────────

def _fetch_cached(url, cache_name):
    cache = os.path.join(os.path.dirname(__file__), cache_name)
    if os.path.exists(cache):
        print(f"  [cache] {cache}")
        with open(cache, encoding="utf-8") as f:
            return json.load(f)
    print(f"  Downloading {url} …")
    with urllib.request.urlopen(url, timeout=120) as resp:
        data = resp.read().decode("utf-8")
    with open(cache, "w", encoding="utf-8") as f:
        f.write(data)
    return json.loads(data)


def fetch_geojson(url):
    return _fetch_cached(url, "_ne_countries_cache.geojson")


def fetch_pov(code):
    """Fetch a Natural Earth 1:10m point-of-view dataset by country code."""
    return _fetch_cached(POV_URL.format(code=code),
                         f"_ne_pov_{code}_cache.geojson")


def find_feature(features, ne_name):
    """Find a GeoJSON feature by the Natural Earth NAME or ADMIN field."""
    for f in features:
        props = f.get("properties", {})
        if props.get("ADMIN") == ne_name or props.get("NAME") == ne_name:
            return f
    # Fallback: partial match
    ne_lower = ne_name.lower()
    for f in features:
        props = f.get("properties", {})
        for key in ("ADMIN", "NAME", "NAME_LONG", "FORMAL_EN", "SOVEREIGNT"):
            if ne_lower in str(props.get(key, "")).lower():
                return f
    return None


# ── GDScript emitter ─────────────────────────────────────────────────────────

def emit_gdscript(country_data):
    lines = [
        "# AUTO-GENERATED by tools/gen_country_masks.py — do not edit by hand.",
        "# Each entry: { name, color_hex, rivals, mask }",
        "# mask = PackedByteArray of GRID_W*GRID_H bytes; 1=land, 0=ocean.",
        "extends Object",
        "",
        f"const GRID_W := {GRID_W}",
        f"const GRID_H := {GRID_H}",
        "",
        "const COUNTRIES: Array = [",
    ]

    for entry in country_data:
        name, display, color_hex, rivals, mask_bytes = entry
        # Encode mask as a hex string for compactness, decoded at runtime.
        hex_str = "".join(f"{b:02x}" for b in mask_bytes)
        land_count = sum(mask_bytes)
        lines.append(f'\t{{')
        lines.append(f'\t\t"name": "{display}",')
        lines.append(f'\t\t"color_hex": "#{color_hex}",')
        lines.append(f'\t\t"rivals": {rivals},')
        lines.append(f'\t\t"land_cells": {land_count},')
        lines.append(f'\t\t"mask_hex": "{hex_str}",')
        lines.append(f'\t}},')

    lines += [
        "]",
        "",
        "# Decode a country's mask_hex string into a PackedByteArray at load time.",
        "static func decode_mask(hex: String) -> PackedByteArray:",
        "\tvar out := PackedByteArray()",
        "\tout.resize(GRID_W * GRID_H)",
        "\tfor i in GRID_W * GRID_H:",
        '\t\tout[i] = hex.substr(i * 2, 2).hex_to_int()',
        "\treturn out",
        "",
        "# Active-zone bounding box for a mask (smallest rect containing all land cells).",
        "# Returns { x0, y0, x1, y1 } in grid-cell coords.",
        "static func mask_bbox(mask: PackedByteArray) -> Dictionary:",
        "\tvar x0 := GRID_W; var y0 := GRID_H; var x1 := 0; var y1 := 0",
        "\tfor iy in GRID_H:",
        "\t\tfor ix in GRID_W:",
        "\t\t\tif mask[iy * GRID_W + ix] == 1:",
        "\t\t\t\tx0 = mini(x0, ix); y0 = mini(y0, iy)",
        "\t\t\t\tx1 = maxi(x1, ix); y1 = maxi(y1, iy)",
        '\treturn {"x0": x0, "y0": y0, "x1": x1, "y1": y1}',
    ]

    return "\n".join(lines) + "\n"


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("gen_country_masks.py")
    print("=" * 60)

    geojson = fetch_geojson(GEOJSON_URL)
    features = geojson["features"]
    print(f"  Loaded {len(features)} features from Natural Earth.")

    # Pre-fetch any point-of-view datasets needed (India, USA…).
    pov_features = {}
    for code in sorted(set(POV_SOURCE.values())):
        pov_features[code] = fetch_pov(code)["features"]

    country_data = []
    for ne_name, display, color_hex, rivals in COUNTRIES:
        pov_code = POV_SOURCE.get(ne_name)
        src_features = pov_features[pov_code] if pov_code else features
        feat = find_feature(src_features, ne_name)
        if feat is None:
            print(f"  WARNING: '{ne_name}' not found — using blank mask")
            mask_bytes = [0] * (GRID_W * GRID_H)
        else:
            rings = _flatten_rings(feat["geometry"],
                                   keep_all=(ne_name in KEEP_ALL_RINGS))
            stylized = SIMPLIFY and ne_name not in SKIP_SIMPLIFY
            if stylized:
                rings = _stylize_rings(rings)
            cells = rasterize_country(rings)
            mask_bytes = cells_to_bytes(cells)
            land = sum(mask_bytes)
            src_tag = f"POV:{pov_code}" if pov_code else "110m"
            style_tag = "toy" if stylized else "exact"
            print(f"  {display:<15} {land:>5} land cells  "
                  f"({len(rings)} rings, {src_tag}, {style_tag})")
        country_data.append((ne_name, display, color_hex, rivals, mask_bytes))

    # ── Sort islands by land area ascending so progression grows in size ──────
    # land cells = how much of the grid the country fills (each shape is aspect-
    # fit), i.e. the in-game island size. Rivals are then re-derived from rank to
    # match kingdom_match._endless_rivals_for: count = clamp(3 + rank//2, 3, 7).
    country_data.sort(key=lambda e: sum(e[4]))
    country_data = [
        (ne_name, display, color_hex, max(3, min(3 + rank // 2, 7)), mask_bytes)
        for rank, (ne_name, display, color_hex, _rivals, mask_bytes)
        in enumerate(country_data)
    ]
    print("\n  Ascending island order (land cells, rivals):")
    for rank, (_ne, display, _hex, rivals, mask_bytes) in enumerate(country_data):
        print(f"    {rank:>2}. {display:<15} {sum(mask_bytes):>6} cells  "
              f"{rivals} rivals")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    gd_src = emit_gdscript(country_data)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(gd_src)
    print(f"\nWritten -> {OUT_PATH}")
    print("Run in Godot to verify: res://toybox_kingdoms/data/country_masks.gd")


if __name__ == "__main__":
    main()
