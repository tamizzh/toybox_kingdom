# 3D Migration — Pending Tasks

Status: all 30 minigames ported from 2D (`MiniGameBase`) to true 3D
(`MiniGameBase3D`) and they pass Godot's parse/import scan. The items below are
what's left to finish/polish the conversion.

## 1. Visual verification (each game)
The ports were written by reasoning about the axis mapping (2D `x`→3D `x`,
2D `y`→3D `z`, jumps→`y`); they parse but have **not all been seen rendering**.
Spot-check captured so far: `_cap_snake_battle.png` (others were mid-capture).

- [ ] Run each minigame and confirm it renders + plays:
  - Combat: tank_battle ✅(seen), sword_duel, bomb_throw, laser_survival, mini_shooter
  - Racing: sprint_race, lane_switch, obstacle_dash, ice_slide, hill_climb
  - Sports: mini_soccer, sumo_push, basketball_rush, tug_of_war, hockey_slide
  - Growth: snake_battle, blob_growth, zone_shrink, king_of_arena, virus_spread
  - Reaction: reaction_tap, stop_timer, color_match, light_signal, memory_sequence
  - Platform: falling_platforms, lava_rising, jump_gap, moving_block, rotating_platform
- [ ] Capture harness for spot-checks: `_cap_multi.gd` / `_cap_multi.tscn`
      (run windowed: `godot --path . res://_cap_multi.tscn`). Remove when done.

## 2. Tuning pass (likely needed after seeing them)
- [ ] Per-game constants: avatar `speed`, arena fit, marker/box sizes, bullet/
      ball speeds — values were converted ~px→units by eye.
- [ ] Camera angle/height in `core/mini_game_base_3d.gd` `_build_world()`
      (currently perspective at (0,17,12), fov 50) — confirm it frames the
      `ARENA_HX=12 / ARENA_HZ=7` arena for every game; consider per-game override.
- [ ] Joystick→3D direction sign checks (movement + facing) — flip if mirrored.
- [ ] laser_survival: verify beam visual lines up with hit detection
      (uses `_pivot.rotation.y = -_angle`).
- [ ] lava_rising: 2D vertical "rise" was mapped to the **Z axis**; confirm it
      feels right or remap.
- [ ] jump_gap / obstacle_dash: jump height (Y) + gap collision window.

## 3. End-to-end flow
- [ ] Play a full match in Godot (menu → grid → 3D round → results → repeat)
      to confirm the hybrid launcher works:
  - `core/game_manager.gd` (`current_game`/`game` are `Node`, not `MiniGameBase`)
  - `main.gd` `_on_round_started` (guards `modulate` with `if game is CanvasItem`)
- [ ] Confirm HUD time/status + winner overlay still show over the 3D view.
- [ ] Confirm touch controls + keyboard input drive Avatar3D.

## 4. Characters / art
- [ ] Non-tank games use a placeholder colored-sphere mascot (`Avatar3D`
      `_build_default_visual`). Replace with proper 3D character model(s) if
      wanted; tank_battle already swaps in `tank.glb` via `set_model`.
- [ ] Optional: real 3D arena art / floor textures per category (currently flat
      colored floor from `shared/wall_arena3d.gd`).

## 5. Cleanup (leftovers from the 2D tank work — harmless but unused)
- [ ] `shared/tank3d.gd` (SubViewport hack) — no longer used.
- [ ] `assets/sprites/tank_battle.png` (baked render) — 3D game ignores it.
- [ ] `theme/flat_figure.gd` `body_color_as_line` / `face_angle` additions — 2D-only, unused now.
- [ ] Temp capture files: `_cap_multi.gd`, `_cap_multi.tscn`, `_cap_*.png`.
- [ ] Old 2D `core/mini_game_base.gd` + 2D `players/*` once 3D is confirmed good
      (currently kept so nothing breaks mid-migration).

## Key references
- 3D base: `core/mini_game_base_3d.gd` (camera/lights/arena + helpers:
  `spawn_avatars`, `corner_spawns`, `lane_spawns`, `clamp_avatar`,
  `spawn_marker`, `spawn_ball`, `spawn_disc`, `make_bar`, `make_label`).
- 3D avatar: `players/avatar3d.gd` (`set_model`, `set_body_color`,
  `set_body_scale`, `face`, `momentum`).
- 3D bullet/arena: `shared/bullet3d.gd`, `shared/wall_arena3d.gd`.
- Refresh class cache after adding new `class_name`s:
  `godot --headless --editor --quit --path .`
- Godot: `C:\Users\rpandian\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`
