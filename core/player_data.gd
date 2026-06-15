class_name PlayerData
extends RefCounted

# Lightweight per-player record carried across the whole match.

var id: int = 0
var display_name: String = "P1"
var color: Color = Color.WHITE
var score: int = 0

# Solo "vs CPU" support. Human players are driven by touch/keyboard; AI players
# are driven by AIController, which writes into InputManager for this id.
var is_ai: bool = false
var ai_difficulty: int = 1   # 0=easy, 1=normal, 2=hard

# Per-round transient state (reset each round by MiniGameBase).
var alive: bool = true
var finished: bool = false
var rank: int = 0
var round_value: float = 0.0

func _init(p_id: int = 0) -> void:
	id = p_id
	display_name = Palette.player_name(p_id)
	color = Palette.player_color(p_id)

func reset_round() -> void:
	alive = true
	finished = false
	rank = 0
	round_value = 0.0
