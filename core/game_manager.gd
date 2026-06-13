extends Node

# Autoload singleton. Orchestrates the match loop:
# menu -> random round -> score -> (repeat until first-to-target) -> results.

signal match_started
signal show_game_grid              # show the game-picker grid
signal round_started(game)        # game: MiniGameBase node (main mounts it)
signal round_result(results, title)
signal match_finished(winner_id)
signal returned_to_menu

const ROUND_GAP := 2.5

var player_count: int = 2
var players: Array = []            # Array[PlayerData]
var current_game: Node = null   # MiniGameBase (2D) or MiniGameBase3D
var _match_over: bool = false

func _ready() -> void:
	ScoreManager.match_won.connect(_on_match_won)

func setup_match(count: int) -> void:
	player_count = clampi(count, 1, 4)
	players = []
	for i in player_count:
		players.append(PlayerData.new(i))
	ScoreManager.setup(players, 5)
	_match_over = false

func start_match() -> void:
	_match_over = false
	match_started.emit()
	show_game_grid.emit()

func pick_game(index: int) -> void:
	if _match_over:
		return
	InputManager.reset()
	var entry: Dictionary = MiniGameRegistry.GAMES[index]
	var game: Node = load(entry.script).new()   # 2D MiniGameBase or 3D MiniGameBase3D
	game.game_title = entry.title
	game.round_duration = float(entry.get("duration", 30.0))
	game.category = entry.get("category", "")
	game.slug = MiniGameRegistry.slug(entry)
	game.arena_color = Palette.category_arena(game.category)
	current_game = game
	game.round_finished.connect(_on_round_finished.bind(entry.title), CONNECT_ONE_SHOT)
	round_started.emit(game)
	game.start_game(players)

func _on_round_finished(results: Dictionary, title: String) -> void:
	ScoreManager.add_round_results(results)
	round_result.emit(results, title)
	if _match_over:
		return
	await get_tree().create_timer(ROUND_GAP).timeout
	if _match_over:
		return
	show_game_grid.emit()

func _on_match_won(winner_id: int) -> void:
	_match_over = true
	await get_tree().create_timer(ROUND_GAP).timeout
	match_finished.emit(winner_id)

func return_to_menu() -> void:
	_match_over = true
	current_game = null
	returned_to_menu.emit()
