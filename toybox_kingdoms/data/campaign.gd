extends RefCounted

# ── Campaign ladder ──────────────────────────────────────────────────────────
# The retention spine: ~10 escalating conquest stages. Each stage defines its
# rival line-up via `diffs` — one entry per AI rival (0 timid / 1 balanced /
# 2 bold), so total kingdoms = 1 human + diffs.size(). The ladder ramps from
# 3 timid rivals to a 7-warlord finale: more rivals, bolder AI, harder matches.
#
# kingdom_match reads the ACTIVE stage from SaveManager (revert-safe: if anything
# here is missing it falls back to its own N_KINGDOMS default). Beating the
# current frontier stage advances SaveManager.campaign_cleared().

# `secs` = match length for that stage. The early stages are deliberately SHORT so a
# brand-new player reaches the win screen fast (the #1 D1 lever); length ramps to the
# full 5-minute war as rivals multiply. Stages without `secs` fall back to DEFAULT_SECS.
const DEFAULT_SECS := 300.0
const STAGES := [
	{"title": "First Steps",     "diffs": [0, 0, 0],          "secs": 90.0},
	{"title": "Border Skirmish", "diffs": [0, 0, 1, 0],       "secs": 120.0},
	{"title": "The Rivals",      "diffs": [0, 1, 1, 0, 1],    "secs": 150.0},
	{"title": "Growing Pains",   "diffs": [1, 1, 1, 0, 1],    "secs": 180.0},
	{"title": "Bold Neighbors",  "diffs": [1, 1, 2, 1, 0, 1], "secs": 210.0},
	{"title": "The Pretenders",  "diffs": [1, 2, 1, 2, 1, 1], "secs": 240.0},
	{"title": "Siege",           "diffs": [1, 1, 2, 1, 2, 1, 0],    "secs": 270.0},
	{"title": "Warlords",        "diffs": [2, 1, 2, 1, 2, 1, 1],    "secs": 300.0},
	{"title": "The Gauntlet",    "diffs": [2, 2, 2, 1, 2, 1, 2],    "secs": 300.0},
	{"title": "Toybox Throne",   "diffs": [2, 2, 2, 2, 2, 2, 2],    "secs": 300.0},
]

static func count() -> int:
	return STAGES.size()

static func stage(idx: int) -> Dictionary:
	return STAGES[clampi(idx, 0, STAGES.size() - 1)]

static func title(idx: int) -> String:
	return String(stage(idx)["title"])

# Match length (seconds) for this stage — short early, ramping to the full match.
static func duration(idx: int) -> float:
	return float(stage(idx).get("secs", DEFAULT_SECS))

# Difficulties for the AI rivals in this stage (length = number of rivals).
static func rival_diffs(idx: int) -> Array:
	return (stage(idx)["diffs"] as Array).duplicate()

# Total kingdoms in this stage = 1 human + the rivals.
static func kingdoms(idx: int) -> int:
	return 1 + rival_diffs(idx).size()
