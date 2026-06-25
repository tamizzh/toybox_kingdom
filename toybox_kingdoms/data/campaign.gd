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

const STAGES := [
	{"title": "First Steps",     "diffs": [0, 0, 0]},
	{"title": "Border Skirmish", "diffs": [0, 0, 1, 0]},
	{"title": "The Rivals",      "diffs": [0, 1, 1, 0, 1]},
	{"title": "Growing Pains",   "diffs": [1, 1, 1, 0, 1]},
	{"title": "Bold Neighbors",  "diffs": [1, 1, 2, 1, 0, 1]},
	{"title": "The Pretenders",  "diffs": [1, 2, 1, 2, 1, 1]},
	{"title": "Siege",           "diffs": [1, 1, 2, 1, 2, 1, 0]},
	{"title": "Warlords",        "diffs": [2, 1, 2, 1, 2, 1, 1]},
	{"title": "The Gauntlet",    "diffs": [2, 2, 2, 1, 2, 1, 2]},
	{"title": "Toybox Throne",   "diffs": [2, 2, 2, 2, 2, 2, 2]},
]

static func count() -> int:
	return STAGES.size()

static func stage(idx: int) -> Dictionary:
	return STAGES[clampi(idx, 0, STAGES.size() - 1)]

static func title(idx: int) -> String:
	return String(stage(idx)["title"])

# Difficulties for the AI rivals in this stage (length = number of rivals).
static func rival_diffs(idx: int) -> Array:
	return (stage(idx)["diffs"] as Array).duplicate()

# Total kingdoms in this stage = 1 human + the rivals.
static func kingdoms(idx: int) -> int:
	return 1 + rival_diffs(idx).size()
