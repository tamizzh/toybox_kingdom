class_name Upgrades
extends RefCounted

# Catalog of purchasable permanent upgrades. Each upgrade is bought once and
# applies every match. Two unlock paths: real-money IAP or coins (free-earn).

const ITEMS := {
	"speed_boost": {
		"name": "Swift Conqueror",
		"desc": "Carve territory 15% faster every match",
		"icon": "boost",        # maps to assets/hud/boost.png
		"speed_bonus": 1.0,     # added to HUMAN_SPEED (≈ 2 barracks worth)
		"coin_cost": 800,
		"price": "$1.99",
		"product": "upg_speed",
	},
	"coin_boost": {
		"name": "Royal Mint",
		"desc": "Earn 40% more coins after every match",
		"icon": "coin",         # maps to assets/hud/coin.png
		"coin_cost": 600,
		"price": "$1.49",
		"product": "upg_coins",
	},
}

static func ids() -> Array:
	return ITEMS.keys()

static func name_of(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)

static func desc_of(id: String) -> String:
	return ITEMS.get(id, {}).get("desc", "")

static func icon_of(id: String) -> String:
	return ITEMS.get(id, {}).get("icon", "coin")

static func coin_cost_of(id: String) -> int:
	return int(ITEMS.get(id, {}).get("coin_cost", 0))

static func price_of(id: String) -> String:
	return ITEMS.get(id, {}).get("price", "")

static func product_of(id: String) -> String:
	return ITEMS.get(id, {}).get("product", "")

static func speed_bonus_of(id: String) -> float:
	return float(ITEMS.get(id, {}).get("speed_bonus", 0.0))
