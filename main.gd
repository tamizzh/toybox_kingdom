extends Node

# Root view controller. Swaps screens in ScreenHost; keeps HUD + touch persistent.
# Flow: MainMenu → GameGrid → (game plays) → GameGrid → … → MatchResults → MainMenu

@onready var screen_host: Node = $ScreenHost
@onready var hud: Control = $UILayer/HUD
@onready var touch: Control = $TouchLayer/TouchControls

const MAIN_MENU := preload("res://ui/main_menu.tscn")
const GAME_GRID := preload("res://ui/game_grid.tscn")
const RESULTS  := preload("res://ui/results_screen.tscn")

func _ready() -> void:
	GameManager.match_started.connect(_on_match_started)
	GameManager.show_game_grid.connect(_on_show_game_grid)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_result.connect(_on_round_result)
	GameManager.match_finished.connect(_on_match_finished)
	GameManager.returned_to_menu.connect(show_menu)
	show_menu()

# ------------------------------------------------------------------ screen swap

func _clear_host() -> void:
	for c in screen_host.get_children():
		c.queue_free()

func _swap(new_screen: Node) -> void:
	_clear_host()
	new_screen.modulate.a = 0.0
	screen_host.add_child(new_screen)
	var tw := create_tween()
	tw.tween_property(new_screen, "modulate:a", 1.0, 0.18)

func show_menu() -> void:
	hud.visible = false
	touch.visible = false
	_swap(MAIN_MENU.instantiate())

# ------------------------------------------------------------------ game manager signals

func _on_match_started() -> void:
	hud.setup(GameManager.players)
	touch.setup(GameManager.players)

func _on_show_game_grid() -> void:
	hud.visible = false
	touch.visible = false
	_swap(GAME_GRID.instantiate())

func _on_round_started(game: Node) -> void:
	_clear_host()
	game.modulate.a = 0.0
	screen_host.add_child(game)
	var tw := create_tween()
	tw.tween_property(game, "modulate:a", 1.0, 0.18)
	game.time_changed.connect(hud.set_time)
	game.status_changed.connect(hud.set_status)
	hud.set_status(game.game_title)
	hud.set_time(game.round_duration)
	hud.visible = true
	touch.visible = true

func _on_round_result(results: Dictionary, _title: String) -> void:
	hud.flash_round_result(results)
	_show_winner_overlay(results)

func _on_match_finished(winner_id: int) -> void:
	hud.visible = false
	touch.visible = false
	var rs := RESULTS.instantiate()
	_swap(rs)
	rs.show_match_winner(winner_id, GameManager.players)

# ------------------------------------------------------------------ winner overlay

func _show_winner_overlay(results: Dictionary) -> void:
	var best := -1
	var winner_id := -1
	for id in results:
		if int(results[id]) > best:
			best = int(results[id])
			winner_id = id
	if winner_id < 0 or best <= 0:
		return

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100

	var pts := int(best)
	var winner_name := Palette.player_name(winner_id)
	var winner_color := Palette.player_color(winner_id)
	var pt_text := "point" if pts == 1 else "points"

	var label := Label.new()
	label.text = "%s wins!\n+%d %s" % [winner_name, pts, pt_text]
	label.add_theme_font_size_override("font_size", 74)
	label.add_theme_color_override("font_color", winner_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)

	$UILayer.add_child(overlay)

	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.62, 0.25)
	tw.tween_interval(1.6)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.45)
	tw.tween_callback(overlay.queue_free)
