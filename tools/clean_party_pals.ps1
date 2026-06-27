# clean_party_pals.ps1
# Removes the Party Pals Arena mini-game system — not used by Toybox Kingdoms.
# All files are git-tracked so recovery is: git checkout HEAD~1 -- <path>
#
# Usage:
#   powershell -ExecutionPolicy Bypass .\tools\clean_party_pals.ps1          # apply
#   powershell -ExecutionPolicy Bypass .\tools\clean_party_pals.ps1 -WhatIf  # dry-run

param([switch]$WhatIf)

$root    = Split-Path -Parent $PSScriptRoot
$deleted = 0

function Remove-File {
    param([string]$rel)
    $full = Join-Path $root $rel
    if (Test-Path $full) {
        if ($WhatIf) { Write-Host "[dry-run] $rel" }
        else          { Remove-Item $full -Force; Write-Host "deleted  $rel" }
        $script:deleted++
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

# ── Whole directories ────────────────────────────────────────────────────────
Remove-Dir "assets\arenas"
Remove-Dir "minigames"
Remove-Dir "shared"

# ── Core mini-game system ─────────────────────────────────────────────────────
foreach ($f in @(
    "core\game_manager.gd", "core\game_manager.gd.uid",
    "core\mini_game_base.gd", "core\mini_game_base.gd.uid",
    "core\mini_game_base_3d.gd", "core\mini_game_base_3d.gd.uid",
    "core\mini_game_registry.gd", "core\mini_game_registry.gd.uid",
    "core\ai_controller.gd", "core\ai_controller.gd.uid"
)) { Remove-File $f }

# ── Party Pals UI screens ─────────────────────────────────────────────────────
foreach ($f in @(
    "ui\game_grid.gd", "ui\game_grid.gd.uid", "ui\game_grid.tscn",
    "ui\game_tile.gd", "ui\game_tile.gd.uid",
    "ui\next_game_screen.gd", "ui\next_game_screen.gd.uid",
    "ui\results_screen.gd", "ui\results_screen.gd.uid", "ui\results_screen.tscn",
    "ui\hud.gd", "ui\hud.gd.uid", "ui\hud.tscn"
)) { Remove-File $f }

# ── Party Pals root entry point ───────────────────────────────────────────────
foreach ($f in @("main.gd", "main.gd.uid", "main.tscn")) { Remove-File $f }

# ── Remove GameManager autoload from project.godot ───────────────────────────
$godot = Join-Path $root "project.godot"
$content = Get-Content $godot -Raw
$patched = $content -replace '\r?\nGameManager="\*res://core/game_manager\.gd"', ''
if ($content -ne $patched) {
    if ($WhatIf) {
        Write-Host "[dry-run] patch project.godot: remove GameManager autoload"
    } else {
        Set-Content $godot $patched -Encoding utf8 -NoNewline
        Write-Host "patched  project.godot (removed GameManager autoload)"
    }
    $script:deleted++
}

Write-Host ""
if ($WhatIf) {
    Write-Host "Dry-run complete — $deleted items would be removed. Re-run without -WhatIf to apply."
} else {
    Write-Host "Done — $deleted items removed."
}
