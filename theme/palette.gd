class_name Palette
extends RefCounted

# Central color definitions for the "Minimal Flat Arcade" style.

const PLAYER_COLORS := [
	Color("f24d3d"), # P1 Coral red
	Color("2ea7f2"), # P2 Sky blue
	Color("7ec53f"), # P3 Lime green
	Color("ffbf3a"), # P4 Golden yellow
]
const PLAYER_NAMES := ["P1", "P2", "P3", "P4"]

# Design space. Landscape 19.5:9 to match iPhone 17 Pro Max (2868×1320) held
# sideways for couch multiplayer; scales cleanly to the device via canvas_items.
const DESIGN_W := 1560.0
const DESIGN_H := 720.0
const CENTER_X := 780.0

const ARENA_BG := Color("1d2230")
const ARENA_FLOOR := Color("2a3142")
const WALL := Color("4a5571")
const ACCENT := Color("f5f7fa")
const DANGER := Color("e6394a")
const SAFE := Color("37b34a")
const WARN := Color("f2c12e")
const NEUTRAL := Color("8893a8")

const CATEGORY_COLORS := {
	"Racing":  Color("f5a623"),
	"Combat":  Color("e6394a"),
	"Growth":  Color("37b34a"),
	"Sports":  Color("2f7fe6"),
	"Reaction": Color("bd10e0"),
	"Platform": Color("f2c12e"),
}

# Bright per-category arena backgrounds (mid-tone so both white art and
# dark-outlined mascots read clearly on top), matching the colourful app look.
const CATEGORY_ARENA := {
	"Racing":   Color("bd7e46"),
	"Combat":   Color("7c5572"),
	"Growth":   Color("4fa45a"),
	"Sports":   Color("3a86c7"),
	"Reaction": Color("8a5fb0"),
	"Platform": Color("c07d52"),
}

static func category_color(cat: String) -> Color:
	return CATEGORY_COLORS.get(cat, ACCENT)

static func category_arena(cat: String) -> Color:
	return CATEGORY_ARENA.get(cat, ARENA_FLOOR)

static func player_color(id: int) -> Color:
	return PLAYER_COLORS[id % PLAYER_COLORS.size()]

static func player_name(id: int) -> String:
	return PLAYER_NAMES[id % PLAYER_NAMES.size()]
