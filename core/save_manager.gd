extends Node

# Autoload. Persistent player state in user://save.cfg: audio volumes, ad-consent
# flag, IAP purchases (remove-ads + cosmetic packs) and the selected palette.
# On boot it applies the saved audio volumes and cosmetic palette so the rest of
# the game just reads Palette / AudioManager as usual.

const PATH := "user://save.cfg"

signal coins_changed(total)

var _cfg := ConfigFile.new()

func _ready() -> void:
	_cfg.load(PATH)   # ignore error if the file doesn't exist yet
	AudioManager.set_music_volume(music_volume())
	AudioManager.set_sfx_volume(sfx_volume())
	apply_palette()

func _save() -> void:
	_cfg.save(PATH)

# ── audio ────────────────────────────────────────────────────────────────────
func music_volume() -> float:
	return float(_cfg.get_value("settings", "music", 0.8))

func sfx_volume() -> float:
	return float(_cfg.get_value("settings", "sfx", 0.9))

func set_music_volume(v: float) -> void:
	_cfg.set_value("settings", "music", v)
	AudioManager.set_music_volume(v)
	_save()

func set_sfx_volume(v: float) -> void:
	_cfg.set_value("settings", "sfx", v)
	AudioManager.set_sfx_volume(v)
	_save()

# ── consent (GDPR / ATT) ─────────────────────────────────────────────────────
func consent_done() -> bool:
	return bool(_cfg.get_value("settings", "consent_done", false))

func set_consent_done(v: bool) -> void:
	_cfg.set_value("settings", "consent_done", v)
	_save()

# ── purchases ────────────────────────────────────────────────────────────────
func has_remove_ads() -> bool:
	return bool(_cfg.get_value("purchases", "remove_ads", false))

func set_remove_ads(v: bool) -> void:
	_cfg.set_value("purchases", "remove_ads", v)
	_save()

# ── cosmetics ────────────────────────────────────────────────────────────────
func owned_packs() -> Array:
	var owned: Array = _cfg.get_value("cosmetics", "owned", [])
	if not owned.has("default"):
		owned = owned.duplicate()
		owned.append("default")
	return owned

func owns_pack(id: String) -> bool:
	return id == "default" or owned_packs().has(id)

func add_owned_pack(id: String) -> void:
	var owned: Array = _cfg.get_value("cosmetics", "owned", [])
	if not owned.has(id):
		owned.append(id)
		_cfg.set_value("cosmetics", "owned", owned)
		_save()

func next_unlock_pack_id() -> String:
	var best_id := ""
	var best_cost := 0
	for id in Cosmetics.ids():
		if owns_pack(id):
			continue
		var cost := Cosmetics.coin_cost_of(id)
		if cost <= 0:
			continue
		if best_id == "" or cost < best_cost:
			best_id = id
			best_cost = cost
	return best_id

func next_unlock_pack_remaining() -> int:
	var id := next_unlock_pack_id()
	if id == "":
		return 0
	return maxi(0, Cosmetics.coin_cost_of(id) - coins())

func selected_pack() -> String:
	return str(_cfg.get_value("cosmetics", "selected", "default"))

func set_selected_pack(id: String) -> void:
	_cfg.set_value("cosmetics", "selected", id)
	_save()
	apply_palette()

func apply_palette() -> void:
	Palette.active_palette = Cosmetics.colors(selected_pack())

# ── progression: coins ─────────────────────────────────────────────────────────
func coins() -> int:
	return int(_cfg.get_value("progress", "coins", 0))

func add_coins(n: int) -> void:
	if n == 0:
		return
	_cfg.set_value("progress", "coins", maxi(0, coins() + n))
	_save()
	coins_changed.emit(coins())

func spend_coins(n: int) -> bool:
	if coins() < n:
		return false
	_cfg.set_value("progress", "coins", coins() - n)
	_save()
	coins_changed.emit(coins())
	return true

# ── progression: XP / level ──────────────────────────────────────────────────────
func xp() -> int:
	return int(_cfg.get_value("progress", "xp", 0))

func add_xp(n: int) -> void:
	if n == 0:
		return
	_cfg.set_value("progress", "xp", xp() + n)
	_save()

# Gentle curve: level L needs 50*(L-1)^2 total XP.
func level() -> int:
	return int(floor(sqrt(float(xp()) / 50.0))) + 1

func _xp_for_level(l: int) -> int:
	return 50 * (l - 1) * (l - 1)

# 0..1 progress through the current level (for an XP bar).
func level_progress() -> float:
	var l := level()
	var base := _xp_for_level(l)
	var span := _xp_for_level(l + 1) - base
	if span <= 0:
		return 0.0
	return clampf(float(xp() - base) / float(span), 0.0, 1.0)

# ── progression: stats ─────────────────────────────────────────────────────────
func stat(key: String) -> int:
	return int(_cfg.get_value("stats", key, 0))

func bump_stat(key: String, n: int = 1) -> void:
	_cfg.set_value("stats", key, stat(key) + n)
	_save()

# ── onboarding ───────────────────────────────────────────────────────────────────
func onboarding_done() -> bool:
	return bool(_cfg.get_value("onboarding", "done", false))

func set_onboarding_done(v: bool) -> void:
	_cfg.set_value("onboarding", "done", v)
	_save()

# Per-game rule card is shown only the first time each game is played.
func game_seen(slug: String) -> bool:
	if slug == "":
		return true
	var seen: Array = _cfg.get_value("onboarding", "seen_games", [])
	return seen.has(slug)

func mark_game_seen(slug: String) -> void:
	if slug == "":
		return
	var seen: Array = _cfg.get_value("onboarding", "seen_games", [])
	if not seen.has(slug):
		seen.append(slug)
		_cfg.set_value("onboarding", "seen_games", seen)
		_save()

# ── progression: daily reward ────────────────────────────────────────────────────
# Returns the bonus granted (0 if already claimed today).
func claim_daily_if_due(bonus: int = 50) -> int:
	var today := Time.get_date_string_from_system()
	if str(_cfg.get_value("progress", "last_daily", "")) == today:
		return 0
	_cfg.set_value("progress", "last_daily", today)
	add_coins(bonus)   # add_coins saves + emits coins_changed
	return bonus
