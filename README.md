# Party Pals Arena — Local Multiplayer Framework (Godot 4.6)

A couch-multiplayer (2–4 players, one device) party-game framework with **30 mini-games**
under a unified "Minimal Flat Arcade" art style. Runs on **PC and Android**, no plugins.

## Run
Open the project in Godot 4.6 and press **F5**. `main.tscn` is the entry scene.

- **Touch:** every player gets an on-screen joystick + action button (corners of the screen).
- **Keyboard (PC convenience):** P1 = WASD + Space, P2 = Arrows + Enter.
- **Match:** random mini-games (no immediate repeat). First player to **5 points** wins.

## Architecture

| Layer | Files |
|---|---|
| Autoload singletons | `core/input_manager.gd`, `core/score_manager.gd`, `core/game_manager.gd` |
| Data / base | `core/player_data.gd`, `core/round_timer.gd`, `core/mini_game_base.gd`, `core/mini_game_registry.gd` |
| Theme / visuals | `theme/palette.gd`, `theme/flat_figure.gd` |
| Reusable | `players/player_avatar.tscn` + `players/player_controller.gd`, `shared/bullet.*`, `shared/wall_arena.gd` |
| UI | `ui/main_menu`, `ui/hud`, `ui/results_screen`, `ui/touch_controls` (+ `virtual_joystick.gd`, `action_button.gd`) |
| Root | `main.tscn` + `main.gd` |
| Mini-games | `minigames/<category>/<name>.gd` (30 total) |

**Flow:** `MainMenu → (random MiniGame → round results)* → MatchResults → MainMenu`,
driven by signals from `GameManager`. `main.gd` mounts/swaps screens in `ScreenHost` and
keeps the HUD + touch overlays persistent.

Communication is signal-based. Mini-games never touch raw input or scene-switching — they
read `InputManager.get_move(id)` / `get_action(id)` and report a results dictionary.

## Add a new mini-game (3 steps)

1. Create `minigames/<category>/<name>.gd` that `extends MiniGameBase`. Override
   `_setup_round()` and `_compute_results()`, optionally `_game_process(delta)`:

   ```gdscript
   extends MiniGameBase

   func _setup_round() -> void:
       win_condition = WinType.LAST_ALIVE        # or HIGH_SCORE / FAST_TIME
       draw_background()
       add_child(WallArena.build(arena_rect))     # floor + walls (optional)
       spawn_avatars(corner_spawns(arena_rect))   # auto-tinted flat figures

   func _game_process(delta: float) -> void:
       # read InputManager.get_move(id)/get_action(id); call eliminate(id), etc.
       pass

   func _compute_results() -> Dictionary:
       return survivor_results(3)                 # or award_by_rank([...]) / rank_by_value({...})
   ```

2. (Optional) build extra visuals in code via `make_rect()` / `make_label()` / `_draw()`.
   No `.tscn` is required — games are instanced from their script.

3. Append one entry to `core/mini_game_registry.gd`:

   ```gdscript
   {"script": "res://minigames/<category>/<name>.gd", "title": "My Game", "category": "Misc", "duration": 30.0},
   ```

   It now joins the random rotation automatically.

### Helpers available on `MiniGameBase`
`spawn_avatars`, `corner_spawns`, `lane_spawns`, `clamp_avatar`, `eliminate`, `survivors`,
`check_last_alive`, `award_by_rank`, `rank_by_value`, `survivor_results`, `make_rect`,
`make_label`, `draw_background`, `finish_round`, `time_left`, `elapsed`.
