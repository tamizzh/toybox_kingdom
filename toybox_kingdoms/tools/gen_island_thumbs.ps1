# gen_island_thumbs.ps1 — generate world-map thumbnail screenshots for all 20 islands.
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File toybox_kingdoms\tools\gen_island_thumbs.ps1
#
# Each island boots its own Godot process (shot_one_island.tscn), snaps the overhead
# map view, saves a 480x270 PNG to assets/islands/island_N.png, then quits.
# After it finishes, open the Godot editor once so it imports the new PNGs.

$godot  = "C:\Users\rpandian\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
$scene  = "res://toybox_kingdoms/tools/shot_one_island.tscn"
$total  = 20
$ok     = 0
$failed = 0

New-Item -ItemType Directory -Force -Path "assets\islands" | Out-Null

for ($i = 0; $i -lt $total; $i++) {
    Write-Host "Island $($i + 1) / $total ..." -NoNewline

    $env:TBK_ENDLESS      = "1"
    $env:TBK_ISLAND       = "$i"
    $env:TBK_AUTOCONTINUE = "1"  # prevent 6-s block if player is eliminated early

    # Start-Process (without -NoNewWindow) lets Godot open its own window,
    # which is required for the GPU renderer to work on Windows/D3D12.
    $proc = Start-Process -FilePath $godot `
        -ArgumentList "--path", ".", $scene `
        -Wait -PassThru

    $outFile = "assets\islands\island_$i.png"
    if ($proc.ExitCode -eq 0 -and (Test-Path $outFile)) {
        $kb = [math]::Round((Get-Item $outFile).Length / 1KB, 0)
        Write-Host " OK  ($kb KB)"
        $ok++
    } else {
        Write-Host " FAILED (exit=$($proc.ExitCode))"
        $failed++
    }
}

Write-Host ""
Write-Host "Done: $ok ok, $failed failed"
if ($ok -gt 0) {
    Write-Host "Open the Godot editor to import the new PNGs, then the world map will use them."
}
