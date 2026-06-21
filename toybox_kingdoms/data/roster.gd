extends RefCounted

# Data-driven roster of toy rulers. Index 0 is the human ("You"); the rest are AI
# rivals whose `diff` (0 timid / 1 balanced / 2 bold) drives their KingdomAI, so
# personality and behaviour line up — "Sir Cuddles" really does play recklessly.

const RULERS := [
	{"name": "You",             "diff": 1},
	{"name": "King Wobble",     "diff": 2},
	{"name": "Baron Plush",     "diff": 0},
	{"name": "Lady Mint",       "diff": 1},
	{"name": "Sir Cuddles",     "diff": 2},
	{"name": "Duke Sprinkle",   "diff": 1},
	{"name": "Queen Tinsel",    "diff": 0},
	{"name": "Captain Bumble",  "diff": 1},
]

static func info(i: int) -> Dictionary:
	return RULERS[i % RULERS.size()]
