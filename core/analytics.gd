extends Node

# Autoload. Backend-agnostic analytics facade. Call Analytics.event(...) anywhere;
# this layer stamps each event with player/session identity, buffers them, and
# flushes a batch to a collector. Until a real backend is wired it logs every event
# to the console (debug) and appends a local JSONL file (user://analytics_log.jsonl)
# so the full funnel is inspectable NOW, with no SDK installed.
#
# To go live: set ENDPOINT (a HTTPS collector that accepts a JSON {"events":[...]}
# POST — e.g. a tiny serverless function, or GameAnalytics' REST ingest) and events
# start POSTing in batches. Every call site stays unchanged. Marked TODO(real-sdk).
#
# Privacy: events only leave the device once consent is granted (MonetizationManager
# consent flow → SaveManager.consent_done). Before that they still log locally.

# ── config ────────────────────────────────────────────────────────────────────
const ENDPOINT := ""                 # TODO(real-sdk): set to your collector URL to enable network send
const PATH := "user://analytics.cfg" # persists the stable player id + lifetime session count
const LOG_PATH := "user://analytics_log.jsonl"   # local event log (always written in debug)
const FLUSH_EVERY := 20              # flush when the buffer reaches this many events
const FLUSH_INTERVAL := 30.0         # ...or at least this often (seconds)
const MAX_LOG_BYTES := 1 << 20       # cap the local log at ~1 MB (rotates when exceeded)

# ── identity / session ────────────────────────────────────────────────────────
var _cfg := ConfigFile.new()
var _player_id := ""
var _session_id := ""
var _session_num := 0
var _seq := 0
var _session_start_ms := 0
var _enabled := true                 # master kill-switch (e.g. dev opt-out)

# ── buffering ─────────────────────────────────────────────────────────────────
var _buffer: Array = []
var _flush_t := 0.0
var _http: HTTPRequest
var _sending := false

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

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	# kick the session off
	event("session_start", {
		"session_num": _session_num,
		"platform": OS.get_name(),
		"version": ProjectSettings.get_setting("application/config/version", "0"),
		"mobile": DeviceMode.is_mobile,
		"locale": OS.get_locale_language(),
	})

func _process(delta: float) -> void:
	if _buffer.is_empty():
		return
	_flush_t -= delta
	if _flush_t <= 0.0 or _buffer.size() >= FLUSH_EVERY:
		flush()

# Mobile sends the app to the background instead of closing — that's the real
# "session over" signal on phones. Flush + close the session on pause and on quit.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_end_session()
		flush()

# ── public API ────────────────────────────────────────────────────────────────
# Record one event. `name` is a stable snake_case key; `params` is a flat dict of
# scalars (strings / numbers / bools). Cheap when disabled.
func event(name: String, params: Dictionary = {}) -> void:
	if not _enabled:
		return
	_seq += 1
	var e := {
		"name": name,
		"ts": int(Time.get_unix_time_from_system() * 1000.0),
		"t": float(Time.get_ticks_msec() - _session_start_ms) / 1000.0,  # seconds into session
		"seq": _seq,
		"player": _player_id,
		"session": _session_id,
		"params": params,
	}
	_buffer.append(e)
	_log_local(e)
	if OS.is_debug_build():
		print("[analytics] %s %s" % [name, JSON.stringify(params)])

# ── game funnel helpers (typed seams the rest of the game calls) ──────────────
# These keep event names + param shapes consistent so dashboards stay clean.
func match_start(stage: int, n_kingdoms: int, mode: String, duration: float) -> void:
	event("match_start", {"stage": stage, "kingdoms": n_kingdoms, "mode": mode, "duration": duration})

func first_capture(seconds: float) -> void:
	event("first_capture", {"seconds": snappedf(seconds, 0.1)})

func match_end(win: bool, reason: String, rank: int, pct: float, duration: float, coins: int) -> void:
	event("match_end", {
		"win": win, "reason": reason, "rank": rank,
		"pct": snappedf(pct, 0.001), "duration": snappedf(duration, 0.1), "coins": coins,
	})

func building_bought(kind: String, cost: int) -> void:
	event("building_bought", {"kind": kind, "cost": cost})

func ad_event(kind: String, placement: String, completed: bool = true) -> void:
	event("ad", {"kind": kind, "placement": placement, "completed": completed})

func iap_event(product_id: String, simulated: bool) -> void:
	event("iap_purchase", {"product": product_id, "simulated": simulated})

func progression(status: String, name: String, extra: Dictionary = {}) -> void:
	# status: "start" | "complete" | "fail"  — e.g. progression("complete", "stage_3")
	var p := {"status": status, "id": name}
	p.merge(extra)
	event("progression", p)

# ── network flush ─────────────────────────────────────────────────────────────
func flush() -> void:
	_flush_t = FLUSH_INTERVAL
	if _buffer.is_empty() or _sending:
		return
	if ENDPOINT == "" or not _enabled:
		_buffer.clear()   # no collector yet → the local JSONL log is the system of record
		return
	# Only transmit once the player has consented (events still logged locally before).
	if MonetizationManager.needs_consent():
		return
	var batch: Array = _buffer.duplicate()
	_buffer.clear()
	var body := JSON.stringify({"events": batch})
	var headers := ["Content-Type: application/json"]
	# TODO(real-sdk): if the collector needs auth/HMAC (e.g. GameAnalytics), sign here.
	_sending = true
	var err := _http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_sending = false
		# put the batch back so we retry on the next flush rather than dropping data
		_buffer = batch + _buffer

func _on_request_completed(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_sending = false
	if code < 200 or code >= 300:
		if OS.is_debug_build():
			print("[analytics] flush failed http=%d (kept locally)" % code)

# ── session end ───────────────────────────────────────────────────────────────
func _end_session() -> void:
	if not _enabled:
		return
	var secs := float(Time.get_ticks_msec() - _session_start_ms) / 1000.0
	event("session_end", {"length": snappedf(secs, 0.1), "session_num": _session_num})

# ── local log (the always-on sink) ────────────────────────────────────────────
func _log_local(e: Dictionary) -> void:
	# Append one JSON object per line. Rotate when the file gets large so a long-lived
	# install doesn't grow it without bound.
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)   # first write creates it
		if f == null:
			return
	f.seek_end()
	if f.get_position() > MAX_LOG_BYTES:
		f.close()
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)   # truncate-rotate
		if f == null:
			return
	f.store_line(JSON.stringify(e))
	f.close()

func _new_id() -> String:
	# Random-ish opaque id; no PII. Good enough to thread a player/session together.
	var s := "%d-%d-%d" % [Time.get_ticks_usec(), randi(), randi()]
	return s.sha256_text().substr(0, 24)
