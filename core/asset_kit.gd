class_name AssetKit
extends RefCounted

# Drop-in art loader. Returns a Texture2D if a matching PNG has been added (and
# imported by Godot), otherwise null so callers fall back to procedural art.
#
# Folder convention:
#   res://assets/thumbs/<slug>.png    – 30 game grid thumbnails (square)
#   res://assets/sprites/<slug>.png   – per-game character body (white + black outline)
#   res://assets/arenas/<category>.png – per-category arena background
#   res://assets/logo/logo.png        – title logo
#
# Nothing here ever crashes when a file is missing; the game stays fully playable
# with zero assets present and lights up art automatically as PNGs are dropped in.

const THUMBS  := "res://assets/thumbs/"
const SPRITES := "res://assets/sprites/"
const ARENAS  := "res://assets/arenas/"
const CONTROLS := "res://assets/controls/"
const LOGO    := "res://assets/logo/"
const UI      := "res://assets/ui/"

const EXTS := [".png", ".jpg", ".jpeg", ".webp"]

static var _cache: Dictionary = {}

# Given a path with no extension, return the first existing texture across the
# supported image formats (so PNG/JPG/WEBP all just work).
static func tex(path_no_ext: String) -> Texture2D:
	if _cache.has(path_no_ext):
		return _cache[path_no_ext]
	var t: Texture2D = null
	for e in EXTS:
		var p: String = path_no_ext + e
		if ResourceLoader.exists(p, "Texture2D"):
			t = load(p) as Texture2D
			break
	_cache[path_no_ext] = t
	return t

static func thumb(slug: String) -> Texture2D:
	return tex(THUMBS + slug)

static func sprite(slug: String) -> Texture2D:
	return tex(SPRITES + slug)

static func arena(category: String) -> Texture2D:
	return tex(ARENAS + category.to_lower())

static func control(name: String) -> Texture2D:
	return tex(CONTROLS + name)

static func logo() -> Texture2D:
	return tex(LOGO + "logo")

static func menu_hero() -> Texture2D:
	return tex(UI + "menu_hero")

static func menu_logo() -> Texture2D:
	return tex(UI + "menu_logo")
