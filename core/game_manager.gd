extends Node

# Autoload singleton. Orchestrates the match loop:
# menu -> random round -> score -> (repeat until first-to-target) -> results.

signal match_started
signal show_game_grid              # show the game-picker grid (manual "Pick Games" mode)
signal show_next_game(index, is_first)  # party mode: reveal the next auto-picked game
signal round_started(game)        # game: MiniGameBase node (main mounts it)
signal round_result(results, title)
signal match_finished(winner_id)
signal returned_to_menu

const ROUND_GAP := 1.6
const ROUND_COINS := 10    # earned each round played
const MATCH_COINS := 50    # earned for finishing a match

var last_match_coins: int = 0   # coins earned across the just-finished match (results screen)
var _match_coins: int = 0

# Party mode (default): games auto-advance in a random rotation with a quick
# reveal between rounds — no picking. Turn off for the manual game-grid picker.
var party_mode: bool = true
var _last_index: int = -1          # last game played (avoid back-to-back repeats)

var player_count: int = 2          # total players (humans + CPUs)
var players: Array = []            # Array[PlayerData]
var current_game: Node = null   # MiniGameBase (2D) or MiniGameBase3D
var _match_over: bool = false

# Last match setup, so "Play Again" repeats the same humans/CPUs/difficulty.
var last_human_count: int = 2
var last_cpu_count: int = 0
var last_difficulty: int = 1

func _ready() -> void:
	ScoreManager.match_won.connect(_on_match_won)

func setup_match(human_count: int, cpu_count: int = 0, difficulty: int = 1) -> void:
	human_count = clampi(human_count, 1, 4)
	cpu_count = clampi(cpu_count, 0, 4 - human_count)
	last_human_count = human_count
	last_cpu_count = cpu_count
	last_difficulty = difficulty
	player_count = human_count + cpu_count
	players = []
	for i in player_count:
		var p := PlayerData.new(i)
		if i >= human_count:
			p.is_ai = true
			p.ai_difficulty = difficulty
			p.display_name = "CPU" if cpu_count == 1 else "CPU %d" % (i - human_count + 1)
		players.append(p)
	ScoreManager.setup(players, 5)
	_match_over = false

# Repeat the last match configuration (used by the results "Play Again" button).
func replay_last() -> void:
	setup_match(last_human_count, last_cpu_count, last_difficulty)

func start_match() -> void:
	_match_over = false
	_match_coins = 0
	_last_index = -1
	SaveManager.bump_stat("matches_played")
	match_started.emit()
	_advance_round(true)

# Route to the next round: party mode reveals an auto-picked game; manual mode
# shows the picker grid.
func _advance_round(is_first: bool = false) -> void:
	if _match_over:
		return
	if party_mode:
		show_next_game.emit(_pick_next_index(), is_first)
	else:
		show_game_grid.emit()

# Random launch game, avoiding an immediate repeat when more than one is available.
func _pick_next_index() -> int:
	var idxs: Array = MiniGameRegistry.launch_indices()
	if idxs.is_empty():
		return 0
	var choice: int = idxs[randi() % idxs.size()]
	if idxs.size() > 1:
		while choice == _last_index:
			choice = idxs[randi() % idxs.size()]
	return choice

func _is_human(id: int) -> bool:
	for p in players:
		if p.id == id:
			return not p.is_ai
	return false

func _top_scorer(results: Dictionary) -> int:
	var best := -1
	var best_id := -1
	for id in results:
		if int(results[id]) > best:
			best = int(results[id])
			best_id = id
	return best_id

func pick_game(index: int) -> void:
	if _match_over:
		return
	_last_index = index
	InputManager.reset()
	MiniGameRegistry.record_play(index)
	var entry: Dictionary = MiniGameRegistry.GAMES[index]
	var game: Node = load(entry.script).new()   # 2D MiniGameBase or 3D MiniGameBase3D
	game.game_title = entry.title
	game.round_duration = float(entry.get("duration", 30.0))
	game.category = entry.get("category", "")
	game.slug = MiniGameRegistry.slug(entry)
	if "tagline" in game:
		game.tagline = entry.get("tagline", "")
	game.arena_color = Palette.category_arena(game.category)
	current_game = game
	game.round_finished.connect(_on_round_finished.bind(entry.title), CONNECT_ONE_SHOT)
	round_started.emit(game)
	game.start_game(players)

func _on_round_finished(results: Dictionary, title: String) -> void:
	ScoreManager.add_round_results(results)
	round_result.emit(results, title)
	MonetizationManager.note_round_finished()

	# Progression: playing a round always earns a little; track human round wins.
	SaveManager.add_coins(ROUND_COINS)
	SaveManager.add_xp(10)
	_match_coins += ROUND_COINS
	SaveManager.bump_stat("rounds_played")
	var rwin := _top_scorer(results)
	if rwin >= 0 and _is_human(rwin):
		SaveManager.bump_stat("rounds_won")

	if _match_over:
		return
	await get_tree().create_timer(ROUND_GAP).timeout
	if _match_over:
		return
	MonetizationManager.maybe_show_interstitial()
	_advance_round()

func _on_match_won(winner_id: int) -> void:
	_match_over = true
	SaveManager.add_coins(MATCH_COINS)
	SaveManager.add_xp(40)
	_match_coins += MATCH_COINS
	last_match_coins = _match_coins
	if _is_human(winner_id):
		SaveManager.bump_stat("matches_won")
	await get_tree().create_timer(ROUND_GAP).timeout
	match_finished.emit(winner_id)

func return_to_menu() -> void:
	_match_over = true
	current_game = null
	returned_to_menu.emit()
