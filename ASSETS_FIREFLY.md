# Firefly Asset Guide — "Party Pals Arena"

Drop PNGs into the folders below using the **exact filenames**. Godot auto-imports
them (open the editor once after adding files). Anything missing falls back to the
built-in procedural art, so you can add assets a few at a time.

## Golden rules (read once)
- **Format:** PNG with **transparent background** (except arena backgrounds).
- **Style (paste into every prompt):**
  > flat vector sticker illustration, thick uniform black outline, bold rounded
  > chunky shapes, bright saturated flat colors, soft subtle drop shadow, minimal
  > detail, mobile game icon, centered, plain background, no text
  
- In Firefly: **Content type = Art**, **Effects/Style** none or "Vector look",
  generate on a plain white background, then remove the background to PNG alpha.
- Keep the subject **centered** with a little padding; no text baked into art
  (the game draws titles itself).

---

## 1. Logo  →  `assets/logo/logo.png`
- **Size:** 1024 × 360, transparent.
- **Tip:** AI image tools often misspell text. If the letters come out wrong,
  regenerate or just rely on the in-game procedural title (it renders cleanly).
- **Prompt:**
  > Mobile game logo wordmark reading "PARTY PALS ARENA". Bold chunky rounded
  > uppercase letters stacked on two lines — "PARTY PALS" above "ARENA" — in bright
  > playful colors with a thick black outline on every letter. Flat vector sticker
  > style, thick uniform black outlines, soft drop shadow, transparent background.
  > Clean, centered, no background shapes, no numbers.

---

## 2. Arena backgrounds  →  `assets/arenas/<category>.png`  (6 files)
- **Size:** **1560 × 720 (19.5:9)** to match iPhone 17 Pro Max held in landscape —
  export at 2× (**3120 × 1440**) or device native **2868 × 1320** for crisp art.
  **Full bleed (no transparency).**
- ⚠️ The game runs at 19.5:9. **16:9 art still works** — the game auto-fits the whole
  image (no crop) and fills the side margins with a dimmed copy. For perfect
  **edge-to-edge full-bleed**, re-export arenas at 19.5:9 (sizes above).
- Keep the **center mostly empty/simple** — gameplay happens there; detail belongs
  near the edges. Mid-tone brightness so outlined characters pop.
- Files + prompts (prepend the style line, drop "transparent background"):

| File | Prompt subject |
|---|---|
| `racing.png`   | top-down race track, warm orange/brown ground, lane markings near edges, mostly empty center |
| `combat.png`   | top-down battle arena floor, purple stone tiles, scorch marks near edges, empty center |
| `growth.png`   | top-down grassy field, soft green, scattered leaves near edges, empty center |
| `sports.png`   | top-down sports pitch, blue court, faint white line markings near edges, empty center |
| `reaction.png` | clean studio floor, soft purple, subtle radial glow, very minimal, empty center |
| `platform.png` | top-down warm wood/earth platform floor, orange-brown, plank lines near edges, empty center |

---

## 3. Character bodies  →  `assets/sprites/<slug>.png`  (optional, per game)
- **Size:** 256 × 256, transparent, **front-facing, centered**.
- **CRITICAL:** Body must be **WHITE fill with a thick BLACK outline, and NO eyes**
  (the game tints the white to each player's color and draws googly eyes on top).
- **Prompt template:**
  > Front-facing cute round <CREATURE> character body, **solid white fill**, thick
  > black outline, no eyes, no face, simple rounded shape, flat vector sticker
  > style, soft drop shadow, transparent background, centered.
- Suggested creature per game (only make the ones you want; rest stay as the blob):
  `sprint_race`→runner, `tank_battle`→tank, `bomb_throw`→round bomb,
  `snake_battle`→snake, `blob_growth`→slime blob, `virus_spread`→spiky germ,
  `mini_soccer`→soccer player, `sumo_push`→sumo, `lava_rising`→frog,
  `reaction_tap`→chick. (A single generic critter reused is fine too.)

---

## 4. Grid thumbnails  →  `assets/thumbs/<slug>.png`  (30 files)
- **Size:** 256 × 256, transparent, subject centered with ~12px padding.
- Prepend the style line to each. The tile already supplies a bright colored panel
  behind the thumbnail, so a transparent subject is enough.

| Slug (filename) | Thumbnail subject |
|---|---|
| `sprint_race`       | running character with motion speed lines |
| `lane_switch`       | car switching between three lanes |
| `obstacle_dash`     | character leaping over a striped hurdle |
| `ice_slide`         | penguin sliding on a curved ice trail |
| `hill_climb`        | little car climbing a steep hill |
| `tank_battle`       | cute cartoon tank, top view |
| `sword_duel`        | two crossed cartoon swords |
| `bomb_throw`        | round black bomb with lit fuse and a face |
| `laser_survival`    | character dodging crossing red laser beams |        
| `mini_shooter`      | little cartoon blaster firing a bullet |
| `snake_battle`      | coiled cute cartoon snake |
| `blob_growth`       | smiling green slime blob |
| `zone_shrink`       | character inside a shrinking ring zone |
| `king_of_arena`     | gold crown on a podium |
| `virus_spread`      | spiky round germ with a face |
| `mini_soccer`       | soccer ball going into a goal net |
| `sumo_push`         | two round sumo wrestlers pushing |
| `basketball_rush`   | basketball above a hoop |
| `tug_of_war`        | rope with two hands pulling opposite ways |
| `hockey_slide`      | hockey stick hitting a puck |
| `reaction_tap`      | finger tapping a glowing button with a spark |
| `stop_timer`        | red cartoon stopwatch |
| `color_match`       | four colored rounded squares in a grid |
| `light_signal`      | traffic light with red/yellow/green |
| `memory_sequence`   | four glowing pads in a ring (Simon-style) |
| `falling_platforms` | cracking platform tiles with a character above |
| `lava_rising`       | character standing above rising orange lava |
| `jump_gap`          | character mid-jump over a gap between two platforms |
| `moving_block`      | character dodging a sliding block with motion arrows |
| `rotating_platform` | character standing on a spinning disc with spin arrows |

---

## How to verify
1. Drop PNGs into the right folder with the exact filename.
2. Open the project in Godot once (it imports the textures).
3. Run — thumbnails appear in the grid, characters/backgrounds in-game, logo on the
   menu. Anything you haven't made yet keeps the procedural look automatically.
