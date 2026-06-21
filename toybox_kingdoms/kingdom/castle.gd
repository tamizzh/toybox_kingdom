extends Node3D

# Low-poly toy castle (Blender model). The "roof" submesh is tinted to the kingdom
# colour; the castle scales up as the kingdom levels and pops on upgrade.

const CASTLE := preload("res://assets/models/castle.glb")
const BASE_Y := 0.0

var color: Color = Color.WHITE
var tier: int = 0
var _model: Node3D

func set_color(c: Color) -> void:
	color = c

func update_tier(t: int) -> void:
	if t == tier:
		return
	var upgraded := t > tier
	tier = t
	if _model == null:
		_build()
	_apply_scale()
	if upgraded:
		_pop()

func _build() -> void:
	_model = CASTLE.instantiate()
	add_child(_model)
	_model.position.y = BASE_Y
	# Colours set in code (don't depend on GLB material import): grey stone keep +
	# kingdom-coloured roofs/banners — the target toy-castle look.
	var stone := _model.find_child("stone", true, false)
	if stone is MeshInstance3D:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color("6d7079")   # medium toy-stone grey
		sm.roughness = 0.85
		(stone as MeshInstance3D).material_override = sm
	var roof := _model.find_child("roof", true, false)
	if roof is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		(roof as MeshInstance3D).material_override = m

func _apply_scale() -> void:
	_model.scale = Vector3.ONE * (0.7 + float(tier) * 0.16)   # grows with the realm

func _pop() -> void:
	var s := _model.scale
	_model.scale = s * 0.82
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_model, "scale", s, 0.35)
