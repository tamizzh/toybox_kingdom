# Party Pals Arena — Visual & Monetization Improvement Plan

## Visual Audit Findings

### Main Menu
- Dark background, "PARTY PALS ARENA" logo, clean two-column layout ✓
- **Problem:** Hero panel is empty white space (circles on beige). Doesn't show gameplay.

### Game Grid
- Colorful 6-column tile grid with category colors ✓
- **Problem:** 30 tiles with no hierarchy, no "play count", players don't know which games are fun.

### Sprint Race / Tank Battle (3D Gameplay)
- Toy-box walls with alternating color blocks look genuinely good ✓
- Blob avatars are cute ✓
- **Problem:** Floor is flat grey — arena feels hollow.
- **Problem:** Instruction labels are plain white text — look like debug tooltips.

### Match Winner Screen
- **WORST SCREEN IN THE GAME.** Just text + grey buttons. No drama, no stats, no confetti.

---

## Changes — Ordered by Impact

### ✅ 1. Arena Floor — Checkerboard Tiles (30 min)
- `shared/wall_arena3d.gd`: Replace flat floor mesh with checkerboard pattern
- Two alternating light colors (cream + light grey)

### ✅ 2. In-Game Instruction Label — Styled Pill (30 min)
- `core/mini_game_base_3d.gd` → `make_label()`: Add semi-transparent rounded background behind text

### ✅ 3. Match Winner Screen — Full Rebuild (4 hours)
- `ui/results_screen.gd`: Add confetti, animated avatar, score recap, funny stat
- Reuse `_play_win_effects()` confetti from MiniGameBase3D

### ✅ 4. Random Game Button in Grid (1 hour)
- `ui/game_grid.gd`: 🎲 RANDOM tile added as first item — slot-machine spins 22 ticks with slowing cadence, lands on random game name, then calls `GameManager.pick_game()`

### ✅ 5. Match Point Announcement (1 hour)
- `ui/game_grid.gd._build_match_point_overlay()`: Checks `ScoreManager` on each grid show. If any player is at target-1 score, spawns a full-screen dark overlay with "MATCH POINT 🔥" bounce-in and player name, fades out after 2.5s revealing the grid beneath.

---

## Monetization Path

### Immediate
- Export to Android/iOS at **$2.99** one-time purchase
- Party games with no daily loop = one-time purchase model

### IAP Layer 1 — Avatar Color Packs (2 days)
- Unlock additional color palettes for $0.99 each ("Neon", "Pastel", "Gold")
- Hook into `Palette.player_color()` → override per player slot

### IAP Layer 2 — Arena Themes (1 week)
- "Space Station", "Beach Party", "Snow Globe"
- Swap `arena_color`, floor tile colors, wall materials
- Already driven by `MiniGameBase3D.arena_color`

---

## Virality — Score Card Share

- End of match: generate image card (match result + funniest stat)
- Mobile: save to camera roll via Godot 4 `DisplayServer`
- No backend needed — pure local share moment
