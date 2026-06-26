# Toybox Kingdoms — Visual Evolution Roadmap

**Goal:** "A tiny living toy kingdom" — cute, clean, readable, bright, premium, toy-like.
**Constraint:** same mechanics, same poly budget, 60 FPS on mobile.

Reference: `assets/simple_target.png`.

---

## The core finding

The game is already feature-complete and visually busy. The distance to the target is **subtraction, not addition.** `simple_target.png` is *flatter, brighter, and cleaner* than the current build:

| Element | Current build | Target | Direction |
|---|---|---|---|
| Ground | per-pixel value-noise clay + seam-AO + plateau bump (`territory_ground.gd`) | flat saturated regions, soft bevel edge, light border ribbon | **flatten + crisp borders** |
| Lighting | warm key + SSAO 3.2 + glow + depth fog | bright, airy, soft shadow, faint AO | **calm it down** |
| Buildings | 1 GLB castle + blob populace | clusters of simple repeated houses/castles/windmill | **more variety, simpler geo** |
| Characters | mascot blobs, king has crown+cape (human only) | every ruler is a crowned blob w/ banner | **personality for all** |
| UI | functional HUD/minimap | rounded panels, kingdom accents, soft motion | **polish pass** |

Below, every task is ranked **Visual Impact (1–5) / Dev Time / Perf Cost**, highest impact-per-hour first.

---

## TIER 0 — Free wins (do first, half a day total)

### 0.1 Calm the lighting — **Impact 5 / Time 1h / Perf −(faster)**
The current rig fights the toy look: SSAO 3.2 + tight radius carves harsh contact crevices, glow softlight muddies, fog is dark green.
**Steps** (`kingdom_match.gd:_build_environment`):
- `ssao_intensity 3.2 → 1.4`, `ssao_radius 0.45 → 0.9`, `ssao_power 2.4 → 1.6` (faint AO, not a crevice ring).
- `glow_blend_mode SOFTLIGHT → ADDITIVE`, `glow_intensity 0.5 → 0.35`, keep `hdr_threshold 1.05` so only the trail/crown/coins bloom.
- `ambient_light_energy 0.40 → 0.55`, ambient color `cfe0ee → e8f0ff` (brighter, airier shadow sides).
- `shadow_opacity 0.82 → 0.55`, `shadow_blur 0.7 → 1.3` (soft toy shadow, not hard tabletop).
- `fog_light_color 16241a → bright sky tint`, push `fog_depth_begin` out so the play area never hazes.
Verify: `tools/shot_kingdom.tscn`.

### 0.2 Flatten the ground noise — **Impact 5 / Time 2h / Perf −(faster)**
The clay shader's per-pixel `vnoise` + 4-tap relief is the heaviest GPU cost AND the thing that reads "procedural/busy" instead of "handcrafted." Target regions are nearly flat.
**Steps** (`territory_ground.gd` SHADER_CODE):
- Drop fragment `vnoise` mottling to ~25% strength (or bake to a single low-freq term).
- Keep the **plateau** (claimed land rising) — that's the toy-diorama silhouette — but reduce `bump_amp 0.045 → 0.015`.
- Replace seam-AO darkening with a **crisp light border** between *different* owners (see 1.1).
Net: fewer ALU ops per pixel → mobile headroom back.

### 0.3 Saturation/contrast unify — **Impact 3 / Time 30m / Perf 0**
In `Environment.adjustment`: contrast ~1.06, saturation ~1.12, brightness 1.0. One global grade so every asset "belongs in the same toy box."

---

## TIER 1 — High impact, low risk (the look pivot, ~3 days)

### 1.1 Crisp kingdom borders — **Impact 5 / Time 4h / Perf 0**
The single biggest "readability at a glance" win. Target has a clean lighter ribbon where two kingdoms meet.
**Steps** (`territory_ground.gdshader` fragment): sample the 4 neighbour texels of `own`. If any neighbour owner ≠ this owner, blend toward `mix(kcolor, white, 0.5)` over a ~1.5px band. Neutral↔owned edge → soft sandy rim (already have `sand_col`). No new draw calls, no CPU.

### 1.2 Building variety via simple geo — **Impact 5 / Time 1.5d / Perf low**
Target villages are clusters of **repeated simple houses + a windmill + a watchtower**, not one big castle. You already have the MultiMesh populace system (`kingdom/populace.gd`) and tier gating.
**Steps** — generate 4 tiny GLBs in Blender via `tools/tbk_lib.py` (cube+cone+cylinder+bevel, one joined mesh each):
- `house_a.glb` (box body + cone roof), `house_b.glb` (L-shape), `tower.glb`, `market.glb`.
- Feed them as additional MultiMesh batches in `populace.gd`, hash-selected per cell (you already hash cell→house/citizen/empty). Reuse the existing pop-in custom-data shader.
- Roofs tint kingdom-colour (per-instance custom data), walls stay cream — matches target.
Keep total prop instances under existing caps (HOUSE_CAP/CIT_CAP). No new draw calls beyond the 4 batches.

### 1.3 Tree/rock cleanup to 3+3 variants — **Impact 3 / Time 3h / Perf −**
You have ~9 tree GLBs scattered. Target uses essentially **round tree, cone pine, bush**. Cut `scatter.gd` to 3 trees + 3 rocks + 1 flower, flat 2-tone colours (already done in code). Fewer unique meshes = fewer MultiMesh batches = faster.

### 1.4 Every ruler is a crowned blob — **Impact 4 / Time 4h / Perf 0**
Target: each enemy is a cute crowned monster with a little banner. Currently only the human gets `make_royal`.
**Steps** (`kingdom_match._spawn_kingdom`): call a lightweight `make_royal` variant for **AI** rulers too (crown only, no cape, lower bloom) so each kingdom has a visible king on its capital. Cheap — one extra crown mesh per ruler (~8 total).

---

## TIER 2 — Polish & life (~2–3 days, do after the look lands)

### 2.1 Animation/life pass — **Impact 4 / Time 1.5d / Perf low**
All vertex-shader or MultiMesh-custom-data driven (zero CPU per instance), the way pop-in already works:
- **Windmill blades rotate** — already have `windmills.gd`; add `TIME`-driven blade spin in its shader.
- **Flags wave** — `flags.gd` vertex sine on `TIME`.
- **Trees sway** — add a tiny `sin(TIME + instance_hash)` x-tilt to the scatter shader vertex.
- **Citizens wander** — currently bob in place; let a few drift on a hash-phased Lissajous path (vertex only).
- **Birds** — one MultiMesh of ~6 quads on a looping spline, occasional. Pure GPU.
- **Coins bounce** — you already pop the HUD coin chip; add a 3D coin-burst reuse from `capture_fx.gd`.

### 2.2 Procedural roads — **Impact 4 / Time 1d / Perf low**
Target connects castle→village with curved light paths. Generate a road ribbon as a MultiMesh of flat quads (or a second ownership-texture channel painted along a spline from capital to nearest cluster). Stone-road look at higher tier per the design ladder.

### 2.3 Tiered kingdom evolution polish — **Impact 4 / Time 1d / Perf 0**
You already gate decor by castle tier. Align the ladder exactly to the brief:
L1 castle+flags → L2 +2 houses+roads → L3 +windmill+farm+tower → L4 +market+stone roads+garden → L5 royal castle+statues. Just thresholds + which batches unlock in `populace.gd`/`decorations.gd`/`windmills.gd`.

---

## TIER 3 — UI polish (~2 days, parallelizable)

### 3.1 Panel restyle — **Impact 4 / Time 1d / Perf 0**
Keep layout (`ui/hud.gd`, `ui/minimap.gd`). Swap to rounded `StyleBoxFlat` (corner radius ~14, soft drop shadow already present at lines 1267/1437), consistent padding, kingdom-colour accent strip per panel. Match target's dark translucent rounded chips.

### 3.2 Iconography + soft motion — **Impact 3 / Time 1d / Perf 0**
- Consistent glyph set (`ui/glyph_icon.gd`) for population/coins/timer/boost/shield/map.
- Hover/press: scale-tween 1.0→1.06 on buttons (Tween, trivial).
- Coin counter: tween the number + pulse the chip on income tick (you have `_pop_coins_chip`).
- Minimap: render regions as the puzzle-piece shapes already in the ownership texture; ring the player white (done).

---

## Performance ledger

Everything above is **net-neutral-to-faster** because the two heaviest current costs (ground per-pixel noise, SSAO) get reduced, and all new content rides existing systems:
- **MultiMesh** for all props/buildings/birds/citizens (already the pattern). New buildings = +4 draw calls total, not per-instance.
- **Shared materials / custom-data shaders** for pop-in, sway, bob, wave — zero per-instance CPU.
- **Object pooling** already in `capture_fx.gd`.
- Mobile guards already in place (`DeviceMode.is_mobile` halves FX, disables SSAO, pulls shadow cascades).
Target headroom: 1000+ decorations / 200+ citizens / thousands of tiles stays comfortable.

---

## Suggested execution order

1. **Day 1 (TIER 0):** lighting calm + ground flatten + grade. *This alone moves the build ~50% toward the target* and buys mobile perf.
2. **Days 2–4 (TIER 1):** crisp borders → building variety → tree cleanup → crowned AI rulers.
3. **Days 5–7 (TIER 2):** animation life pass + roads + tier ladder.
4. **Days 8–9 (TIER 3):** UI polish, in parallel with playtesting.

Verify each step with the existing harnesses: `tools/shot_kingdom.tscn` (town close-up), `shot_decor.tscn` (tier progression), `shot_fx.tscn`, `shot_mascot.tscn`, `tools/shot_mobile` (touch/perf).
