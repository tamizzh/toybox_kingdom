extends MiniGameBase3D

# A large floor disc flashes a player color. Tap ONLY when it matches YOUR color.
# Right +1, wrong -1. Highest score wins. (3D arena)

const HOLD_TIME := 1.1   # seconds before picking a new color
const FLASH_HOLD := 0.30 # bright initial flash duration

var _cur: int = 0        # player id whose color is showing
var _t: float = HOLD_TIME
var _flash: float = 0.0

# 3D disc that changes color
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _glow_t: float = 0.0

# 2D color label
var _lbl: Label

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	action_label = "MATCH"
	add_child(build_arena(ARENA_HX, ARENA_HZ, 1.6, 0.95, true, false))

	# ── Big floor colour disc ──────────────────────────────────────────────────
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.emission_enabled = true
	_disc_mat.emission_energy_multiplier = 2.5

	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 5.0
	cyl.bottom_radius = 5.0
	cyl.height        = 0.10
	cyl.rings         = 1
	_disc.mesh = cyl
	_disc.material_override = _disc_mat
	_disc.position = Vector3(0, 0.05, 0)
	add_child(_disc)

	# White ring outline
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1, 1, 1, 0.70)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color.WHITE
	ring_mat.emission_energy_multiplier = 1.0
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.85; torus.outer_radius = 5.15; torus.rings = 64; torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = ring_mat
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 0.08, 0)
	add_child(ring)

	# ── 2D player name label ───────────────────────────────────────────────────
	_lbl = make_label("", Vector2(Palette.CENTER_X - 120, Palette.DESIGN_H * 0.36), 64, Color.WHITE)

	spawn_avatars(corner_spawns(3.5))
	for p in players:
		avatars[p.id].speed = 4.0

	_pick()

func _pick() -> void:
	_cur = players[randi() % players.size()].id
	_t = HOLD_TIME
	_flash = FLASH_HOLD
	var col := Palette.player_color(_cur)
	_disc_mat.albedo_color = col
	_disc_mat.emission     = col
	_disc_mat.emission_energy_multiplier = 5.0
	if _lbl:
		_lbl.text = "P%d" % (_cur + 1)
		_lbl.add_theme_color_override("font_color", col)
	AudioManager.play("count")

func _game_process(delta: float) -> void:
	_glow_t += delta
	_t -= delta
	_flash = maxf(0.0, _flash - delta)

	# Pulsing emission
	var base_emit := 2.5 + _flash * 3.0
	_disc_mat.emission_energy_multiplier = base_emit + 0.8 * sin(_glow_t * 3.5)

	if _t <= 0.0:
		_pick()
		return

	for p in players:
		if InputManager.get_action_just(p.id):
			if p.id == _cur:
				p.round_value += 1.0
				avatars[p.id].pop()
				AudioManager.play("collect")
			else:
				p.round_value = maxf(0.0, p.round_value - 1.0)
				AudioManager.play("hit")

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
