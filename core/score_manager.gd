extends Node

# Autoload singleton. Persists match scores and decides the match winner
# (first player to reach target_score).

signal scores_updated
signal match_won(player_id)

var target_score: int = 5
var players: Array = [] # Array[PlayerData]

func setup(player_list: Array, target: int = 5) -> void:
	players = player_list
	target_score = target
	for p in players:
		p.score = 0
	scores_updated.emit()

func add_round_results(results: Dictionary) -> void:
	# results: { player_id: points }
	for id in results.keys():
		var p := _player(id)
		if p:
			p.score += int(results[id])
	scores_updated.emit()
	var winner := _check_winner()
	if winner >= 0:
		match_won.emit(winner)

func leader() -> PlayerData:
	var best: PlayerData = null
	for p in players:
		if best == null or p.score > best.score:
			best = p
	return best

func sorted_by_score() -> Array:
	var arr := players.duplicate()
	arr.sort_custom(func(a, b): return a.score > b.score)
	return arr

func _player(id: int) -> PlayerData:
	for p in players:
		if p.id == id:
			return p
	return null

func _check_winner() -> int:
	var best := -1
	var best_score := target_score - 1
	for p in players:
		if p.score >= target_score and p.score > best_score:
			best = p.id
			best_score = p.score
	return best
