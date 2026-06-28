extends Node

# Autoload. One place for all sound: a pool of one-shot SFX players plus a single
# crossfading music player. SFX go to the "SFX" bus, music to "Music", both under
# "Master" — so the Settings screen can set per-category volume. Music WAVs loop.

const SFX := {
	"tap":       preload("res://assets/audio/click.mp3"),
	"count":     preload("res://assets/audio/sfx_count.wav"),
	"go":        preload("res://assets/audio/sfx_go.wav"),
	"collect":   preload("res://assets/audio/sfx_collect.wav"),
	"hit":       preload("res://assets/audio/sfx_eliminates.wav"),
	"eliminate": preload("res://assets/audio/sfx_eliminates.wav"),
	"round_win": preload("res://assets/audio/sfx_round_win.wav"),
	"win":       preload("res://assets/audio/sfx_win.wav"),
	"defeat":    preload("res://assets/audio/sfx_eliminates.wav"),
}
const MUSIC := {
	"menu": preload("res://assets/audio/music_menu.mp3"),
	"game": preload("res://assets/audio/music_game.mp3"),
}

const SFX_MAX_SEC := {
	"tap":      1.0,
	"eliminate": 1.0,
}

const POOL := 10

var _sfx: Array[AudioStreamPlayer] = []
var _idx: int = 0
var _music: AudioStreamPlayer
var _current_music: String = ""
var _music_base_db: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for s in MUSIC.values():
		_enable_loop(s)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)

# Buses normally come from default_bus_layout.tres; create them if it's missing
# so audio never silently fails.
func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")

func _enable_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# 16-bit mono → 2 bytes per frame
		w.loop_end = int(w.data.size() / 2)
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true

# ── playback ─────────────────────────────────────────────────────────────────
func play(sfx_name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not SFX.has(sfx_name):
		return
	var p := _sfx[_idx]
	_idx = (_idx + 1) % POOL
	var s: AudioStream = SFX[sfx_name]
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()
	if SFX_MAX_SEC.has(sfx_name):
		var dur: float = SFX_MAX_SEC[sfx_name]
		var timer := get_tree().create_timer(dur)
		timer.timeout.connect(func() -> void:
			if p.stream == s and p.playing:
				p.stop())

func play_music(which: String) -> void:
	if which == _current_music and _music.playing:
		return
	if not MUSIC.has(which):
		return
	_current_music = which
	_music.stream = MUSIC[which]
	_music.volume_db = _music_base_db
	_music.play()

func stop_music() -> void:
	_current_music = ""
	_music.stop()

# ── volume (0..1 linear), called by Settings / SaveManager ──────────────────
func set_music_volume(linear: float) -> void:
	_set_bus("Music", linear)

func set_sfx_volume(linear: float) -> void:
	_set_bus("SFX", linear)

func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))

func get_music_volume() -> float:
	var idx := AudioServer.get_bus_index("Music")
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx != -1 else 1.0

func get_sfx_volume() -> float:
	var idx := AudioServer.get_bus_index("SFX")
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx != -1 else 1.0
