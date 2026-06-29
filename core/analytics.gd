extends Node

# Autoload. Backend-agnostic analytics facade. Call Analytics.event(...) anywhere;
# this layer stamps each event with player/session identity, routes to the
# GameAnalytics SDK (when the addon is loaded) and always appends a local JSONL
# fallback so the full funnel is inspectable with no network connection.
#
# Privacy: events only leave the device once consent is granted (MonetizationManager
# consent flow → SaveManager.consent_done). Before that they still log locally.

# ── config ────────────────────────────────────────────────────────────────────
const GA_GAME_KEY   := "755c89b648c9a42bc2cca28713bc3c7f"    # replace with your GameAnalytics game key
const GA_SECRET_KEY := "73b88ae3e4553a36099aacd530ba9d47d3db9d42"  # replace with your GameAnalytics secret key
const PATH          := "user://analytics.cfg"
const LOG_PATH      := "user://analytics_log.jsonl"
const MAX_LOG_BYTES := 1 << 20            # rotate local log at ~1 MB

# ── GameAnalytics SDK handle ──────────────────────────────────────────────────
var _ga = null   # Engine singleton; null when addon not loaded

# ── identity / session ────────────────────────────────────────────────────────
var _cfg := ConfigFile.new()
var _player_id := ""
var _session_id := ""
var _session_num := 0
var _seq := 0
var _session_start_ms := 0
var _enabled := true                 # master kill-switch (e.g. dev opt-out)

func _ready() -> void:
	if OS.get_environment("TBK_NO_ANALYTICS") == "1":
		_enabled = false

	_cfg.load(PATH)
	_player_id = str(_cfg.get_value("id", "player", ""))
	if _player_id == "":
		_player_id = _new_id()
		_cfg.set_value("id", "player", _player_id)
	_session_num = int(_cfg.get_value("id", "sessions", 0)) + 1
	_cfg.set_value("id", "sessions", _session_num)
	_cfg.save(PATH)

	_session_id = _new_id()
	_session_start_ms = Time.get_ticks_msec()

	# ── GameAnalytics SDK init ────────────────────────────────────────────────
	if Engine.has_singleton("GameAnalytics"):
		_ga = Engine.get_singleton("GameAnalytics")
		if _ga.has_method("setEnabledInfoLog"):
			_ga.setEnabledInfoLog(OS.is_debug_build())
		if _ga.has_method("configureUserId"):
			_ga.configureUserId(_player_id)
		if _ga.has_method("init"):
			_ga.init(GA_GAME_KEY, GA_SECRET_KEY)
		else:
			push_warning("[analytics] GameAnalytics singleton found but 'init' missing — check addon version")
			_ga = null

	event("session_start", {
		"session_num": _session_num,
		"platform":    OS.get_name(),
		"version":     ProjectSettings.get_setting("application/config/version", "0"),
		"mobile":      DeviceMode.is_mobile,
		"locale":      OS.get_locale_language(),
	})

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_end_session()

# ── public API ────────────────────────────────────────────────────────────────
func event(name: String, params: Dictionary = {}) -> void:
	if not _enabled:
		return
	_seq += 1
	var e := {
		"name":    name,
		"ts":      int(Time.get_unix_time_from_system() * 1000.0),
		"t":       float(Time.get_ticks_msec() - _session_start_ms) / 1000.0,
		"seq":     _seq,
		"player":  _player_id,
		"session": _session_id,
		"params":  params,
	}
	_log_local(e)
	if OS.is_debug_build():
		print("[analytics] %s %s" % [name, JSON.stringify(params)])

	# Route to GameAnalytics as a design event: "name:key1=val1:key2=val2"
	if _ga:
		var parts := [name]
		for k in params:
			parts.append("%s=%s" % [k, str(params[k])])
		var ga_event := ":".join(parts).substr(0, 64)   # GA design events max 64 chars
		_ga.addDesignEvent(ga_event)

# ── game funnel helpers ───────────────────────────────────────────────────────
func match_start(stage: int, n_kingdoms: int, mode: String, duration: float) -> void:
	event("match_start", {"stage": stage, "kingdoms": n_kingdoms, "mode": mode, "duration": duration})
	if _ga:
		_ga.addProgressionEvent("start", "stage_%02d" % stage, mode, "", {})

func first_capture(seconds: float) -> void:
	event("first_capture", {"seconds": snappedf(seconds, 0.1)})
	if _ga:
		_ga.addDesignEventWithValue("first_capture", snappedf(seconds, 0.1))

func match_end(win: bool, reason: String, rank: int, pct: float, duration: float, coins: int) -> void:
	event("match_end", {
		"win": win, "reason": reason, "rank": rank,
		"pct": snappedf(pct, 0.001), "duration": snappedf(duration, 0.1), "coins": coins,
	})
	if _ga:
		var status := "complete" if win else "fail"
		_ga.addProgressionEventWithScore(status, "match", reason, "", int(pct * 1000))

func building_bought(kind: String, cost: int) -> void:
	event("building_bought", {"kind": kind, "cost": cost})
	if _ga:
		_ga.addDesignEventWithValue("building_bought:%s" % kind, float(cost))

func ad_event(kind: String, placement: String, completed: bool = true) -> void:
	event("ad", {"kind": kind, "placement": placement, "completed": completed})

func iap_event(product_id: String, simulated: bool) -> void:
	event("iap_purchase", {"product": product_id, "simulated": simulated})
	if _ga and not simulated:
		# amount in cents; currency from your store config
		_ga.addBusinessEvent("USD", 0, product_id, "iap", "shop", {})

func progression(status: String, name: String, extra: Dictionary = {}) -> void:
	var p := {"status": status, "id": name}
	p.merge(extra)
	event("progression", p)
	if _ga:
		_ga.addProgressionEvent(status, name, "", "", {})

# ── session end ───────────────────────────────────────────────────────────────
func _end_session() -> void:
	if not _enabled:
		return
	var secs := float(Time.get_ticks_msec() - _session_start_ms) / 1000.0
	event("session_end", {"length": snappedf(secs, 0.1), "session_num": _session_num})

# ── local JSONL log ───────────────────────────────────────────────────────────
func _log_local(e: Dictionary) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if f == null:
			return
	f.seek_end()
	if f.get_position() > MAX_LOG_BYTES:
		f.close()
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if f == null:
			return
	f.store_line(JSON.stringify(e))
	f.close()

func _new_id() -> String:
	var s := "%d-%d-%d" % [Time.get_ticks_usec(), randi(), randi()]
	return s.sha256_text().substr(0, 24)
