class_name Palette
extends RefCounted

# Central color definitions — "Toy-Box Party" style matching the reference art.

const PLAYER_COLORS := [
	Color("f02828"), # P1 vivid red
	Color("1878f0"), # P2 vivid blue
	Color("10b83c"), # P3 vivid green
	Color("f5c018"), # P4 vivid yellow
]
const PLAYER_NAMES := ["P1", "P2", "P3", "P4"]

# Active player palette — defaults to PLAYER_COLORS but can be swapped to a
# purchased cosmetic pack (see SaveManager / Cosmetics). player_color() reads this.
static var active_palette: Array = PLAYER_COLORS

const DESIGN_W := 1560.0
const DESIGN_H := 720.0
const CENTER_X := 780.0

# Background seen outside the arena — lush garden green (matches reference art)
const ARENA_BG    := Color("4a8030")
# Dark stone floor tiles (like the reference screenshots)
const ARENA_FLOOR := Color("3f4a5c")
# Wall reference colour (used by games that override directly; WallArena uses its own brick palette)
const WALL        := Color("f5a020")
const ACCENT      := Color("ffffff")
const DANGER      := Color("f02828")
const SAFE        := Color("10b83c")
const WARN        := Color("f5c018")
const NEUTRAL     := Color("a0aab8")

const CATEGORY_COLORS := {
	"Racing":   Color("f5a623"),
	"Combat":   Color("e6394a"),
	"Growth":   Color("37b34a"),
	"Sports":   Color("2f7fe6"),
	"Reaction": Color("bd10e0"),
	"Platform": Color("f2c12e"),
	"Board":    Color("e07b39"),
}

# Slightly lighter/warmer variants of the floor for category tinting
const CATEGORY_ARENA := {
	"Racing":   Color("4a8030"),   # garden green (matches reference)
	"Combat":   Color("3a6820"),   # darker garden green
	"Growth":   Color("3d7828"),   # medium garden green
	"Sports":   Color("427230"),   # slightly cooler green
	"Reaction": Color("4a7028"),   # muted garden green
	"Platform": Color("3e7830"),   # standard garden green
	"Board":    Color("4a8030"),   # garden green tabletop
}

static func category_color(cat: String) -> Color:
	return CATEGORY_COLORS.get(cat, ACCENT)

static func category_arena(cat: String) -> Color:
	return CATEGORY_ARENA.get(cat, ARENA_FLOOR)

static func player_color(id: int) -> Color:
	var pal: Array = active_palette if active_palette.size() > 0 else PLAYER_COLORS
	return pal[id % pal.size()]

static func player_name(id: int) -> String:
	return PLAYER_NAMES[id % PLAYER_NAMES.size()]
