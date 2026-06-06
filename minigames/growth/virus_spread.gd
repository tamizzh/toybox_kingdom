extends MiniGameBase

# One player starts infected. Touch spreads it. Stay clean as long as possible —
# players clean at the end (most clean time) win.

const TOUCH := 54.0
const IMMUNE := 1.0

var _infected := {}
var _imm := {}

func _setup_round() -> void:
	win_condition = WinType.HIGH_SCORE
	draw_background()
	add_child(WallArena.build(arena_rect))
	spawn_avatars(corner_spawns(arena_rect))
	for p in players:
		avatars[p.id].speed = 300.0
		_infected[p.id] = false
		_imm[p.id] = 0.0
	var first: int = players[randi() % players.size()].id
	_set_infected(first)
	make_label("Avoid the infected — stay clean!", Vector2(420, 116), 24)

func _set_infected(id: int) -> void:
	_infected[id] = true
	_imm[id] = IMMUNE
	avatars[id].figure.set_color(Palette.DANGER)

func _game_process(delta: float) -> void:
	for p in players:
		_imm[p.id] = maxf(0.0, _imm[p.id] - delta)
		if not _infected[p.id]:
			p.round_value += delta
	for a in players:
		if not _infected[a.id]:
			continue
		for b in players:
			if _infected[b.id] or _imm[b.id] > 0.0:
				continue
			if avatars[a.id].position.distance_to(avatars[b.id].position) < TOUCH:
				_set_infected(b.id)
	var clean := 0
	for p in players:
		if not _infected[p.id]:
			clean += 1
	if clean == 0:
		finish_round(_compute_results())

func _compute_results() -> Dictionary:
	var vals := {}
	for p in players:
		vals[p.id] = p.round_value
	return rank_by_value(vals, true)
