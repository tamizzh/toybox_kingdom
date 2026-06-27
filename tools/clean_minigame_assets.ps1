# clean_minigame_assets.ps1
# Removes mini-game leftover assets and dead reference files.
# Usage:
#   powershell -ExecutionPolicy Bypass .\tools\clean_minigame_assets.ps1          # apply
#   powershell -ExecutionPolicy Bypass .\tools\clean_minigame_assets.ps1 -WhatIf  # dry-run

param([switch]$WhatIf)

$root    = Split-Path -Parent $PSScriptRoot
$deleted = 0

function Remove-Asset {
    param([string]$rel)
    $full = Join-Path $root $rel
    $imp  = "$full.import"
    foreach ($f in @($full, $imp)) {
        if (Test-Path $f) {
            if ($WhatIf) { Write-Host "[dry-run] $($f.Replace($root+'\\',''))" }
            else          { Remove-Item $f -Force; Write-Host "deleted  $($f.Replace($root+'\\',''))" }
            $script:deleted++
        }
    }
}

function Remove-Dir {
    param([string]$rel)
    $full = Join-Path $root $rel
    if (Test-Path $full) {
        if ($WhatIf) { Write-Host "[dry-run] $rel\" }
        else          { Remove-Item $full -Recurse -Force; Write-Host "removed  $rel\" }
        $script:deleted++
    }
}

# ── Mini-game sprite + thumbnail directories ──────────────────────────────────
Remove-Dir "assets\sprites"
Remove-Dir "assets\thumbs"

# ── Unused 3D models ──────────────────────────────────────────────────────────
Remove-Asset "assets\models\snake_segment.glb"
Remove-Asset "assets\models\crate.glb"

# ── PBR floor textures (ground is flat/paper, not PBR) ───────────────────────
foreach ($f in @("floor_albedo","floor_ao","floor_normal","floor_roughness")) {
    Remove-Asset "assets\$f.png"
}

# ── Unused loose assets ───────────────────────────────────────────────────────
foreach ($f in @(
    "assets\slate_noise.png",
    "assets\main_men_atlas.png",
    "assets\texture.png",
    "assets\blob.png",
    "assets\blob_shadow.png",
    "assets\open.png",
    "assets\round.png",
    "assets\spreading.png"
)) { Remove-Asset $f }

# ── OBJ/MTL tree source files (for GLBs already deleted) ─────────────────────
# tree-round and tree-spreading are kept — their GLBs are in use
foreach ($name in @("tree-branched","tree-conical","tree-open","tree-oval","tree-pyramidal","tree-vase")) {
    Remove-Asset "assets\$name.obj"
    Remove-Asset "assets\$name.mtl"
}
Remove-Asset "assets\tree-columnar.obj"

# ── Root-level tank / reference era files ─────────────────────────────────────
foreach ($f in @(
    "tank.blend", "tank.glb",
    "tank_34.png", "tank_front.png", "tank_render.png", "tank_side.png", "tank_top.png",
    "_cap_snake_battle.png",
    "mascot.png",
    "race_target.png", "snake_target.png", "target.png", "target_art.png",
    "tiles.png"
)) { Remove-Asset $f }

Write-Host ""
if ($WhatIf) {
    Write-Host "Dry-run complete — $deleted items would be removed. Re-run without -WhatIf to apply."
} else {
    Write-Host "Done — $deleted items removed."
}
