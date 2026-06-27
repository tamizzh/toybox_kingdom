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

# Camera framing: "hero" = cinematic 3/4 (default), "map" = steep near-top-down
# flat-paper view. Read by KingdomMatch when it builds the follow camera.
func camera_mode() -> String:
	return str(_cfg.get_value("settings", "camera_mode", "hero"))

func set_camera_mode(mode: String) -> void:
	_cfg.set_value("settings", "camera_mode", mode)
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

# ── match mode (transient — which mode the NEXT match runs) ───────────────────────
# Not persisted: the menu sets it before launching kingdom_match; "Play Again" reloads
# the same scene so it persists in memory across reloads, and a cold launch defaults to
# campaign. Values: "campaign" | "endless" | "timed".
var _pending_mode := "campaign"

func set_mode(m: String) -> void:
	_pending_mode = m

func mode() -> String:
	return _pending_mode

# ── transient endless-run state (a RUN = a chain of islands) ──────────────────────
# Not persisted: lives in memory across the scene reloads that carry the player from
# one island to the next. Reset when a fresh run starts (menu ENDLESS / Play Again).
var _er_island := 0       # 0-based index of the island currently being played
var _er_score := 0        # score banked from islands already CLEARED this run

func endless_island() -> int:
	return _er_island

func endless_run_score() -> int:
	return _er_score

func endless_run_reset() -> void:
	_er_island = 0
	_er_score = 0

# Bank one island's result. On a clear we add its score AND advance to the next island;
# on a failed island we only add the partial score (the run is ending).
func endless_run_bank(island_score: int, cleared: bool) -> void:
	_er_score += island_score
	if cleared:
		_er_island += 1

# ── progression: endless best (persistent across runs) ─────────────────────────────
func endless_best() -> int:
	return int(_cfg.get_value("progress", "endless_best", 0))

func endless_runs() -> int:
	return int(_cfg.get_value("progress", "endless_runs", 0))

# Record a finished endless run; returns true if it set a new personal best.
func record_endless(score: int) -> bool:
	_cfg.set_value("progress", "endless_runs", endless_runs() + 1)
	var is_best := score > endless_best()
	if is_best:
		_cfg.set_value("progress", "endless_best", score)
	_save()
	return is_best

# ── daily challenge ───────────────────────────────────────────────────────────
# One shared, date-seeded run per day (everyone gets the same board). First completion
# each day pays a streak-scaling coin reward; replays are allowed but only update the
# day's best score. Keeping consecutive days alive grows the streak.
func daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)

func _today_str() -> String:
	return Time.get_date_string_from_system()

func daily_done_today() -> bool:
	return str(_cfg.get_value("daily", "last_date", "")) == _today_str()

# Best score on TODAY's challenge (0 until today is played; resets each day).
func daily_best() -> int:
	if not daily_done_today():
		return 0
	return int(_cfg.get_value("daily", "today_best", 0))

func daily_streak() -> int:
	return int(_cfg.get_value("daily", "streak", 0))

# Record a finished daily run. Returns {first, streak, reward, is_best}. The reward is
# only granted on the FIRST completion of the day; replays just update the day's best.
func complete_daily(score: int) -> Dictionary:
	var today := _today_str()
	var last := str(_cfg.get_value("daily", "last_date", ""))
	var first := last != today
	var streak := daily_streak()
	var reward := 0
	var is_best := false
	if first:
		var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
		streak = (streak + 1) if last == yesterday else 1
		reward = 100 + (streak - 1) * 20
		_cfg.set_value("daily", "last_date", today)
		_cfg.set_value("daily", "streak", streak)
		_cfg.set_value("daily", "today_best", score)
		_cfg.set_value("daily", "runs", int(_cfg.get_value("daily", "runs", 0)) + 1)
		is_best = true
		add_coins(reward)   # add_coins saves + emits
	elif score > int(_cfg.get_value("daily", "today_best", 0)):
		_cfg.set_value("daily", "today_best", score)
		is_best = true
	_save()
	return {"first": first, "streak": streak, "reward": reward, "is_best": is_best}

# ── progression: campaign ladder ─────────────────────────────────────────────────
const Campaign := preload("res://toybox_kingdoms/data/campaign.gd")

# Number of campaign stages the player has beaten (0 = none yet).
func campaign_cleared() -> int:
	return int(_cfg.get_value("progress", "campaign_cleared", 0))

# The stage the player should play next: their frontier, clamped to the last stage
# so a finished campaign keeps replaying the finale.
func active_stage() -> int:
	return mini(campaign_cleared(), Campaign.count() - 1)

func campaign_complete() -> bool:
	return campaign_cleared() >= Campaign.count()

# Beating the current frontier stage advances the ladder. Returns true only when
# this win actually unlocked new ground (replaying a cleared stage doesn't).
func clear_stage(idx: int) -> bool:
	if idx >= campaign_cleared() and not campaign_complete():
		_cfg.set_value("progress", "campaign_cleared", campaign_cleared() + 1)
		_save()
		return true
	return false

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
