# Party Pals Arena — Local Multiplayer Framework (Godot 4.6)

A couch-multiplayer (2–4 players, one device) party-game framework with **30 mini-games**
rendered in **real 3D**. Runs on **PC and Android**, no plugins.

Each round is a self-contained 3D mini-game played on a top-down-tilted arena: a
`Camera3D` + lighting, an XZ-plane floor with walls, and `CharacterBody3D` avatars
(the tank games swap in `tank.glb`; others use a colored mascot). The HUD,
countdown and menus stay on a 2D `CanvasLayer` overlay on top of the 3D world.

## Run
Open the project in Godot 4.6 and press **F5**. `main.tscn` is the entry scene.
The renderer is **Mobile** (Forward+), physics is **Jolt**, orientation is **landscape**.

- **Desktop vs mobile (auto):** `core/device_mode.gd` (autoload `DeviceMode`) detects the
  platform at startup — **desktop** opens **maximized** (fills the monitor, stays
  resizable); **mobile** goes **fullscreen**. Read `DeviceMode.is_mobile` /
  `DeviceMode.has_touch` anywhere you need to branch on device.
- **Touch (mobile / touchscreen):** every player gets an on-screen joystick + action
  button in the screen corners. These are **hidden on a keyboard-driven desktop** (no
  touchscreen) so the play area stays uncluttered.
- **Keyboard (desktop):** P1 = WASD + Space, P2 = Arrows + Enter.
- **Match:** random mini-games (no immediate repeat). First player to **5 points** wins.
- **Display:** the 3D camera auto-frames the arena to fill whatever viewport it gets
  (desktop, phone landscape, resized window) and re-frames on rotation/resize, so the
  arena always takes the whole space available without cropping gameplay.

## Architecture

| Layer | Files |
|---|---|
| Autoload singletons | `core/input_manager.gd`, `core/score_manager.gd`, `core/game_manager.gd` |
| Data / base | `core/player_data.gd`, `core/round_timer.gd`, `core/mini_game_registry.gd` |
| 3D base (current) | `core/mini_game_base_3d.gd` — every mini-game extends this |
| 3D pieces | `players/avatar3d.gd`, `shared/bullet3d.gd`, `shared/wall_arena3d.gd`, `tank.glb` |
| Theme / visuals | `theme/palette.gd`, `theme/flat_figure.gd` |
| UI (2D overlay) | `ui/main_menu`, `ui/hud`, `ui/results_screen`, `ui/touch_controls` (+ `virtual_joystick.gd`, `action_button.gd`) |
| Root | `main.tscn` + `main.gd` |
| Mini-games | `minigames/<category>/<name>.gd` (30 total) |

> **2D → 3D migration:** the project was originally 2D and has been ported to true 3D.
> The legacy 2D base (`core/mini_game_base.gd`, `players/`, `shared/bullet.*`,
> `shared/wall_arena.gd`) is kept during the transition. `GameManager`/`main.gd` are a
> hybrid launcher — `current_game` is typed `Node` and the round-start fade guards
> `modulate` with `if game is CanvasItem` — so 2D and 3D mini-games can coexist.
> See `pending.md` for remaining polish.

**Flow:** `MainMenu → (random MiniGame → round results)* → MatchResults → MainMenu`,
driven by signals from `GameManager`. `main.gd` mounts/swaps screens in `ScreenHost` and
keeps the HUD + touch overlays persistent.

Communication is signal-based. Mini-games never touch raw input or scene-switching — they
read `InputManager.get_move(id)` / `get_action(id)` and report a results dictionary.

## Add a new mini-game (3 steps)

1. Create `minigames/<category>/<name>.gd` that `extends MiniGameBase3D`. Override
   `_setup_round()` and `_compute_results()`, optionally `_game_process(delta)`:

   ```gdscript
   extends MiniGameBase3D

   func _setup_round() -> void:
	   win_condition = WinType.LAST_ALIVE             # or HIGH_SCORE / FAST_TIME
	   add_child(WallArena3D.build(ARENA_HX, ARENA_HZ)) # floor + 4 walls (optional)
	   spawn_avatars(corner_spawns(2.0))               # XZ-plane, auto-tinted

   func _game_process(delta: float) -> void:
	   # read InputManager.get_move(id)/get_action(id); call eliminate(id), etc.
	   pass

   func _compute_results() -> Dictionary:
	   return survivor_results(3)                      # or award_by_rank([...]) / rank_by_value({...})
   ```

   Gameplay lives on the **XZ plane** (2D `x` → 3D `x`, 2D `y` → 3D `z`, jumps → `y`).
   The shared arena is `ARENA_HX = 12` × `ARENA_HZ = 7` (half-extents, centered on origin).

2. (Optional) build extra visuals in code via the base helpers — `spawn_marker()`,
   `spawn_ball()`, `spawn_disc()` (3D meshes), or `make_label()` / `make_bar()` (2D overlay).
   No `.tscn` is required — games are instanced from their script.

3. Append one entry to `core/mini_game_registry.gd`:

   ```gdscript
   {"script": "res://minigames/<category>/<name>.gd", "title": "My Game", "category": "Misc", "duration": 30.0},
   ```

   It now joins the random rotation automatically.

### Helpers available on `MiniGameBase3D`
World/spawning: `spawn_avatars`, `corner_spawns`, `lane_spawns`, `clamp_avatar`, `xz`,
`spawn_marker`, `spawn_ball`, `spawn_disc`, `get_avatar`.
Overlay (2D): `make_label`, `make_bar`.
Scoring/flow: `eliminate`, `survivors`, `check_last_alive`, `award_by_rank`, `rank_by_value`,
`survivor_results`, `finish_round`, `time_left`, `elapsed`.
The camera auto-frames the `ARENA_HX`/`ARENA_HZ` arena to the viewport (`_frame_camera`).
