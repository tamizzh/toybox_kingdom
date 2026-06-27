class_name Cosmetics
extends RefCounted

# Catalog of purchasable player-colour packs (the cosmetic IAP layer). Each pack is
# four vivid, distinct colours applied to P1..P4 via Palette.active_palette.
# "default" is free and always owned; the rest are unlocked through the Shop.

# Each pack can be unlocked two ways: real-money IAP (`price`/`product`) OR coins
# earned by playing (`coin_cost`) — the free-earn path that gives the shop a reason
# to exist for non-payers and lifts overall conversion. "default" is free.
# `king` is the single colour applied to the player's kingdom in the conquest game —
# their Toy King, ground ring, and claimed territory. (`colors` is the legacy 4-player
# palette used by the older mini-game modes.) "default" keeps the original blue king.
const PACKS := {
	"default": {
		"name": "Classic", "price": "Free", "product": "", "coin_cost": 0,
		"king": Color("4d9ef5"),
		"colors": [Color("f02828"), Color("1878f0"), Color("10b83c"), Color("f5c018")],
	},
	"neon": {
		"name": "Neon", "price": "$0.99", "product": "pack_neon", "coin_cost": 600,
		"king": Color("ff2d95"),
		"colors": [Color("ff2d95"), Color("00e5ff"), Color("c6ff00"), Color("ffd000")],
	},
	"pastel": {
		"name": "Pastel", "price": "$0.99", "product": "pack_pastel", "coin_cost": 600,
		"king": Color("a0c4ff"),
		"colors": [Color("ff9aa2"), Color("a0c4ff"), Color("b5ead7"), Color("ffdac1")],
	},
	"candy": {
		"name": "Candy", "price": "$1.99", "product": "pack_candy", "coin_cost": 1200,
		"king": Color("7b5cff"),
		"colors": [Color("ff5d8f"), Color("7b5cff"), Color("36d1b7"), Color("ffb03a")],
	},
}

static func ids() -> Array:
	return PACKS.keys()

static func colors(id: String) -> Array:
	return PACKS.get(id, PACKS["default"]).colors

# The player's kingdom colour in the conquest game (king + territory).
static func king_color(id: String) -> Color:
	var p: Dictionary = PACKS.get(id, PACKS["default"])
	return p.get("king", p["colors"][1])

static func name_of(id: String) -> String:
	return PACKS.get(id, PACKS["default"]).name

static func price_of(id: String) -> String:
	return PACKS.get(id, PACKS["default"]).price

static func product_of(id: String) -> String:
	return PACKS.get(id, PACKS["default"]).product

static func coin_cost_of(id: String) -> int:
	return int(PACKS.get(id, PACKS["default"]).get("coin_cost", 0))
