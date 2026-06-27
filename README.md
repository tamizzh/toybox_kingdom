# Toybox Kingdoms (Godot 4.6)

A fast, cozy **territory-conquest** game with a premium toy-diorama look. Drive your
Toy King around an island grid, leave a trail, loop back to **claim land**, cut rivals'
trails to **pop** them, and grow your castle through 6 tiers. Conquer a rival's castle
(at equal-or-higher tier) to take their kingdom. Built mobile-first (Android/iOS),
also runs on desktop and web.

Core mechanic is the `.io` carve-and-enclose loop (Paper.io / Splix lineage) layered
with a castle-siege + light build economy for strategic depth.

## Run

Open in **Godot 4.6** and press F5 — `ui/main_menu.tscn` is the boot scene.
Renderer is **Mobile**; web uses **gl_compatibility**; physics is **Jolt**; landscape.

Headless error check / harness flags (set as env vars):

| Flag | Effect |
|---|---|
| `TBK_FASTMATCH=<sec>` | Override match length (short matches for headless testing) |
| `TBK_ENDLESS=1` | Force the endless island-chain mode |
| `TBK_DAILY=1` | Force the daily challenge |
| `TBK_FIRSTMATCH=1` | Force the first-ever-match path (coach + pure-carve HUD) |
| `TBK_COLDOPEN=1` / `TBK_NO_COLDOPEN=1` | Force / disable cold-open into a match |
| `TBK_NO_ANALYTICS=1` | Disable the analytics autoload |
| `TBK_DEBUG=1` | On-screen/perf debug |

Headless example:
`godot --headless --path . "res://toybox_kingdoms/kingdom_match.tscn" --quit-after 120`

## Game modes

All three reuse one match scene (`toybox_kingdoms/kingdom_match.gd`); a transient
`SaveManager.mode()` selects behaviour. The menu maps:

- **PLAY → endless island chain** (`timed`/`endless`, identical): a **truly untimed**
  run of escalating islands. Conquer an island (last kingdom standing) → a camera
  pull-out + "Sailing to the next island" wipe → the next, harder island, score carried
  over. Losing all your castles ends the run. No clock, no timeout. Score = peak land %
  + rivals conquered + per-island clear bonus; persistent best is chased.
- **Conquer Rush → campaign** (`campaign`): a 10-stage ladder
  (`toybox_kingdoms/data/campaign.gd`), escalating rivals, each a timed match. The
  button opens the campaign ladder (stages, progress, locks) and shows progress
  ("· N/10"). In-match a "STAGE N/10 · Title" chip + start toast surface where you are.
- **Daily challenge** (`daily`, via the menu rewards icon → `ui/daily_screen.gd`): a
  single **date-seeded** timed run — the same board for everyone that day. First
  completion pays a streak-scaling coin reward; replays update the day's best only.

## Systems

### Onboarding & first session
- **Cold-open**: a never-played install boots straight into its first match (no menu
  taps). The how-to slideshow is marked seen so the in-match coach teaches instead.
- **First-match coach**: a guided two-beat banner ("draw a loop" → "loop back home"),
  dismissed on first claim, plus a **pure-carve HUD** (build economy hidden on match 1)
  and a slightly larger starting home so the first claim lands fast.
- Stage-driven match length: first campaign match is short (90s), ramping to 300s.

### Analytics (`core/analytics.gd`, autoload `Analytics`)
Backend-agnostic facade modelled on `MonetizationManager`. `Analytics.event(name, params)`
or typed helpers (`match_start`, `first_capture`, `match_end`, `building_bought`,
`ad_event`, `iap_event`, `progression`). Stamps each event with a stable player id +
per-launch session id; buffers + batch-flushes to a collector **once consent is granted**;
**always logs locally** to `user://analytics_log.jsonl` (the system of record until a
backend is wired — set `ENDPOINT` to go live). Funnel covers session, match start/end,
time-to-first-claim, building/ad/iap events, plus `endless_island` / `endless_end` /
`daily_end`.

### Monetization (`core/monetization_manager.gd`, autoload `MonetizationManager`)
Facade over ads + IAP with GDPR/UMP + ATT consent. Real SDK calls are stubbed
(`TODO(real-sdk)`) and fall back to safe simulated behaviour so Shop/consent/rewarded
flows are testable now. Rewarded-ad placements, interstitial frequency cap, and IAP
(remove-ads + cosmetic packs) are wired through this layer.

### Cosmetics — the coin sink (`theme/cosmetics.gd`, `ui/shop_screen.gd`)
Earn coins (any mode) → **Shop** → unlock/equip a cosmetic pack with coins (or IAP).
The equipped pack's **king colour recolours your kingdom in-game** — Toy King, ground
ring, claimed territory and trail — and you're labelled "Your Kingdom". Default is the
classic blue; rivals auto-take the most distinct palette colours and keep colour-matched
names. Packs: Classic (free) / Neon / Pastel / Candy.

### Persistence (`core/save_manager.gd`, autoload `SaveManager`)
`user://save.cfg`: coins, campaign progress, endless best, daily streak/best, XP/level,
owned/selected cosmetics, audio, consent, onboarding. Plus transient run state (current
mode, endless island/score) that survives the scene reloads between islands.

## Key files

| Area | File |
|---|---|
| Match (all modes, HUD, results) | `toybox_kingdoms/kingdom_match.gd` |
| Grid / capture | `toybox_kingdoms/grid/territory_grid.gd` (+ renderer, ground, slabs) |
| AI rivals | `toybox_kingdoms/ai/kingdom_ai.gd` |
| Camera (follow, pull-out/descend, victory orbit) | `toybox_kingdoms/camera/kingdom_camera.gd` |
| Campaign ladder data / screen | `toybox_kingdoms/data/campaign.gd`, `ui/campaign_screen.gd` |
| Menu | `ui/main_menu.gd` |
| Daily overlay | `ui/daily_screen.gd` |
| Analytics / Monetization / Save / Cosmetics | `core/analytics.gd`, `core/monetization_manager.gd`, `core/save_manager.gd`, `theme/cosmetics.gd` |

## Commercial roadmap

Targeting **hybrid-casual (ads + IAP)**, solo-built, aiming for **publisher-readiness**
(strong D1/retention + a low CPI creative → pitch a publisher to fund UA).

- **Phase 0 — Analytics** ✅ (instrumented funnel)
- **Phase 1 — First-30s hook** ✅ (cold-open, 90s first match, guided coach, pure-carve)
- **Phase 2 — Retention loop** ✅ endless · daily · campaign visibility · cosmetic chase.
  Remaining: leaderboards (Firebase/PlayFab).
- **Phase 3 — CPI test & creatives** ⏳ (wire real ad/IAP SDKs, cut 15s vertical clips,
  organic test for a CPI signal)
- **Phase 4 — Decision gate** ⏳ (pitch publishers if D1 ≥ ~40% and CPI is workable; else
  lean self-publish on organic + ASO)

Metric gates to aim for: D1 ≥ 40%, D7 ≥ 12%, 4–6 min sessions, 3+ sessions/day.
