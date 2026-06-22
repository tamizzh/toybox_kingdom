extends Node3D

# Low-poly toy castle (Blender model). The "roof" submesh is tinted to the kingdom
# colour; the castle scales up as the kingdom levels and pops on upgrade.

const CASTLE := preload("res://assets/models/castle.glb")
const BASE_Y := 0.0
const ROOF_SHADER := """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec4 roof_color : source_color = vec4(1.0);

void fragment() {
	vec3 base = roof_color.rgb;
	// SAME base shade as the ground plate (base*0.96) but a glossy high-quality-toy
	// FINISH: low roughness → sharp sun glint, a candy-coat fresnel rim, and a baked
	// catch-light dot — the signature shiny-vinyl read (cf. vinyl_toy.gdshader).
	ALBEDO = base * 0.96;
	ROUGHNESS = 0.26;                                 // glossy, but a TIGHT glint not a broad sheen
	METALLIC = 0.0;
	SPECULAR = 0.5;

	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.8);                  // narrow candy-coat halo, doesn't whiten the body
	vec3 key = normalize(vec3(-0.35, 0.70, 0.60));    // fixed view-space key direction
	float ndl_key = clamp(dot(normalize(NORMAL), key), 0.0, 1.0);
	float spot = pow(ndl_key, 52.0) * 0.42;           // small, sharp plastic catch-light dot
	// keep the white emission MINIMAL so the roof's blue stays true to its tile
	EMISSION = vec3(1.0) * (rim * 0.06 + spot);
}
"""

var color: Color = Color.WHITE
var tier: int = 0
var _model: Node3D

func set_color(c: Color) -> void:
	color = c
	_apply_roof()

# Re-tint the roof live (e.g. when this castle is captured by another kingdom).
func _apply_roof() -> void:
	if _model == null:
		return
	var roof := _model.find_child("roof", true, false)
	if roof is MeshInstance3D:
		var m := (roof as MeshInstance3D).material_override
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("roof_color", color)

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
		sm.albedo_color = Color("f0dec1")   # warm neutral toy-stone cream
		sm.roughness = 0.33                 # subtle vinyl sheen so the keep reads as glossy toy
		sm.metallic_specular = 0.6
		sm.rim_enabled = true
		sm.rim = 0.25
		sm.rim_tint = 0.2
		(stone as MeshInstance3D).material_override = sm
	var roof := _model.find_child("roof", true, false)
	if roof is MeshInstance3D:
		var sh := Shader.new()
		sh.code = ROOF_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("roof_color", color)
		(roof as MeshInstance3D).material_override = m

func _apply_scale() -> void:
	_model.scale = Vector3.ONE * (0.86 + float(tier) * 0.12)   # chunky toy-castle read

func _pop() -> void:
	var s := _model.scale
	_model.scale = s * 0.82
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_model, "scale", s, 0.35)
