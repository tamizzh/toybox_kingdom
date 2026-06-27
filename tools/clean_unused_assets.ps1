# clean_unused_assets.ps1
# Deletes confirmed-unused assets (and their .import sidecar files).
# Run from the repo root:  powershell -ExecutionPolicy Bypass .\tools\clean_unused_assets.ps1
# Add -WhatIf to do a dry-run first.

param(
    [switch]$WhatIf
)

$root = Split-Path -Parent $PSScriptRoot
$deleted = 0
$skipped = 0

function Remove-Asset {
    param([string]$rel)
    $full = Join-Path $root $rel
    $imp  = "$full.import"
    foreach ($f in @($full, $imp)) {
        if (Test-Path $f) {
            if ($WhatIf) {
                Write-Host "[dry-run] would delete: $f"
            } else {
                Remove-Item $f -Force
                Write-Host "deleted: $rel$(if ($f -like '*.import') { '.import' })"
            }
            $script:deleted++
        } else {
            $script:skipped++
        }
    }
}

function Remove-Dir {
    param([string]$rel)
    $full = Join-Path $root $rel
    if (Test-Path $full) {
        if ($WhatIf) {
            Write-Host "[dry-run] would remove dir: $full"
        } else {
            Remove-Item $full -Recurse -Force
            Write-Host "removed dir: $rel"
        }
        $script:deleted++
    }
}

# ── Whole directories ────────────────────────────────────────────────────────
Remove-Dir "assets\_alternates"
Remove-Dir "assets\controls"

# ── Unused tree GLB models ───────────────────────────────────────────────────
foreach ($name in @("tree-conical","tree-open","tree-oval","tree-pyramidal","tree-vase","tree")) {
    Remove-Asset "assets\models\$name.glb"
}
Remove-Asset "assets\models\island.glb"

# ── Unused tree Blender source files ─────────────────────────────────────────
# (tree-round.blend and tree-spreading.blend are kept — those models are in use)
foreach ($name in @("tree-conical","tree-open","tree-oval","tree-pyramidal","tree-vase")) {
    Remove-Asset "assets\$name.blend"
}

# ── Blender backup ───────────────────────────────────────────────────────────
Remove-Asset "tank.blend1"

# ── Leftover reference/screenshot images ─────────────────────────────────────
Remove-Asset "assets\mascot_ChatGPT Image Jun 24, 2026, 12_05_36 AM.png"
Remove-Asset "assets\mascot_Screenshot 2026-06-23 235030.png"

# ── Test / placeholder images ─────────────────────────────────────────────────
foreach ($name in @("6NbeqC","branched","columnnar","myNNAc","oval","pyramid","vase","poster","preview")) {
    Remove-Asset "assets\$name.png"
}
Remove-Asset "assets\_row_colored.png"
Remove-Asset "assets\_row_grass.png"

# ── Unused ground / dirt / sand texture variants ──────────────────────────────
# ground_dirt_1 is USED — skip it
Remove-Asset "assets\floor_height.png"
foreach ($i in @(0,2,3)) { Remove-Asset "assets\ground_dirt_$i.png" }
foreach ($i in @(0,1,2,3)) { Remove-Asset "assets\ground_sand_$i.png" }

# ── Unused tile variants ──────────────────────────────────────────────────────
# tile_grass_0-3 are USED — only delete 4-6
foreach ($i in @(0,1,2,3,4,5,6,7)) { Remove-Asset "assets\tile_color_$i.png" }
Remove-Asset "assets\tile_dirt.png"
Remove-Asset "assets\tile_grass.png"
foreach ($i in @(4,5,6)) { Remove-Asset "assets\tile_grass_$i.png" }

# ── Unused duplicate mascot model ────────────────────────────────────────────
Remove-Asset "players\mascot.glb"

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
if ($WhatIf) {
    Write-Host "Dry-run complete. $deleted file(s) would be removed. Re-run without -WhatIf to apply."
} else {
    Write-Host "Done. $deleted file(s) removed, $skipped already absent."
}
