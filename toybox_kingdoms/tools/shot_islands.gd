## Island thumbnail batch generator — launcher stub.
## Use the PowerShell script instead (works around Godot-spawning-Godot instability):
##
##   powershell -ExecutionPolicy Bypass -File toybox_kingdoms\tools\gen_island_thumbs.ps1
##
## The PS1 script calls shot_one_island.tscn once per island (0-19) and saves
## 480×270 PNGs to assets/islands/island_N.png.
## After running, open the Godot editor so it auto-imports the new PNGs.

extends Node

func _ready() -> void:
	push_error("Run gen_island_thumbs.ps1 instead — see script header for instructions.")
	get_tree().quit()
