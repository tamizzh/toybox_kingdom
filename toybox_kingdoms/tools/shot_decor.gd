## Tier-progression check: three kingdoms at rising tiers (Outpost / Village / City)
## side by side, so the unlock ladder is visible — Outpost = bare houses+flags; Village
## adds farms/flowers/windmill; City adds keep towers + a denser town.
##   godot --path . res://toybox_kingdoms/tools/shot_decor.tscn
extends Node3D

const Grid := preload("res://toybox_kingdoms/grid/territory_grid.gd")
const Decor := preload("res://toybox_kingdoms/kingdom/decorations.gd")
const Populace := preload("res://toybox_kingdoms/kingdom/populace.gd")
const Windmills := preload("res://toybox_kingdoms/kingdom/windmills.gd")
const Flags := preload("res://toybox_kingdoms/kingdom/flags.gd")
const CELL := 0.6

func _tier(n: int) -> int:
	if n < 300: return 1
	elif n < 800: return 2
	elif n < 1800: return 3
	return 4

func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600, 720)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8fc24a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e3eaee")
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.2
	add_child(sun)

	var grid := Grid.new()
	grid.setup(140, 80)
	# three realms of rising size → rising tier
	var realms := [
		{"kid": 1, "home": Vector2i(22, 40), "r": 9, "col": Color("2f7de0")},    # Outpost T1
		{"kid": 2, "home": Vector2i(60, 40), "r": 15, "col": Color("e0542f")},   # Village T2
		{"kid": 3, "home": Vector2i(104, 40), "r": 26, "col": Color("8a3fd0")},  # City T3/4
	]
	var homes := {}
	var colors := {}
	var tiers := {}
	for r in realms:
		grid.seed_kingdom(r["kid"], r["home"].x, r["home"].y, r["r"])
		homes[r["kid"]] = r["home"]
		colors[r["kid"]] = r["col"]
		tiers[r["kid"]] = _tier(grid.territory_count(r["kid"]))

	# flat plate at prop height so we judge the decoration only
	var plate := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140 * CELL, 80 * CELL)
	plate.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5fa33a")
	plate.material_override = gm
	plate.position.y = 0.07
	add_child(plate)

	var pop := Populace.new(); add_child(pop); pop.setup(grid, CELL, colors, homes); pop.rebuild(tiers)
	var decor := Decor.new(); add_child(decor); decor.setup(grid, CELL, homes); decor.rebuild(tiers)
	var wind := Windmills.new(); add_child(wind); wind.setup(grid, CELL, colors, homes); wind.rebuild(tiers)
	var flags := Flags.new(); add_child(flags); flags.setup(grid, CELL, colors); flags.rebuild()
	print("TIERS ", tiers, "  farms=", decor._farm.multimesh.instance_count,
		" flowers=", decor._flower.multimesh.instance_count,
		" towers=", pop._tower.multimesh.instance_count)

	var cam := Camera3D.new()
	cam.fov = 55
	add_child(cam)
	var focus := Vector3((63 - 70) * CELL, 0.3, 0.3)
	cam.global_position = focus + Vector3(0, 24, 30)
	cam.look_at(focus, Vector3.UP)
	cam.make_current()

	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.claude/shot_decor.png")
	img.save_png(out)
	print("DECOR_SHOT_SAVED: ", out)
	get_tree().quit()
