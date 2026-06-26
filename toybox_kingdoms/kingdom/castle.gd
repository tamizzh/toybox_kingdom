extends Node3D

# Six distinct low-poly toy castle models, one per tier.  castle.gd swaps
# the model each time the kingdom levels up (Watchtower → Capital), applying:
#   "stone"  submesh → warm cream StandardMaterial3D
#   "roof"   submesh → kingdom-colour ShaderMaterial (glossy vinyl toy finish)
# The pop-in tween fires on every upgrade for that satisfying level-up bounce.

const CASTLES := [
	preload("res://assets/models/castle_t1.glb"),   # T1 Watchtower
	preload("res://assets/models/castle_t2.glb"),   # T2 Twin Towers
	preload("res://assets/models/castle_t3.glb"),   # T3 Keep
	preload("res://assets/models/castle_t4.glb"),   # T4 Castle
	preload("res://assets/models/castle_t5.glb"),   # T5 Fortress
	preload("res://assets/models/castle_t6.glb"),   # T6 Capital
]
const BASE_Y := 0.0

const ROOF_SHADER := """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
uniform vec4 roof_color : source_color = vec4(1.0);
void fragment() {
	vec3 base = roof_color.rgb;
	// Glossy vinyl-toy roof: low roughness for a sharp sun glint, narrow candy-coat
	// fresnel rim, and a baked catch-light dot — the signature shiny-plastic read.
	ALBEDO   = base * 0.95;
	ROUGHNESS = 0.24;
	METALLIC  = 0.0;
	SPECULAR  = 0.52;
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.6);
	vec3 key  = normalize(vec3(-0.35, 0.70, 0.60));
	float ndl = clamp(dot(normalize(NORMAL), key), 0.0, 1.0);
	float spot = pow(ndl, 54.0) * 0.44;
	EMISSION  = vec3(1.0) * (rim * 0.06 + spot);
}
"""

var color: Color = Color.WHITE
var tier:  int   = 0
var _model: Node3D


func set_color(c: Color) -> void:
	color = c
	_apply_roof()


func update_tier(t: int) -> void:
	if t == tier:
		return
	var upgraded := t > tier
	tier = t
	_build()
	if upgraded:
		_pop()


# ── private ───────────────────────────────────────────────────────────────────

func _build() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	var idx := clampi(tier - 1, 0, CASTLES.size() - 1)
	_model = CASTLES[idx].instantiate()
	add_child(_model)
	_model.position.y = BASE_Y
	_apply_stone()
	_apply_roof()


func _apply_stone() -> void:
	if _model == null:
		return
	var stone := _model.find_child("stone", true, false)
	if stone is MeshInstance3D:
		var sm := StandardMaterial3D.new()
		sm.albedo_color   = Color("ededdd")   # warm neutral toy-stone cream
		sm.roughness      = 0.32              # subtle vinyl sheen so the keep reads as glossy toy
		sm.metallic_specular = 0.58
		sm.rim_enabled    = true
		sm.rim            = 0.22
		sm.rim_tint       = 0.18
		(stone as MeshInstance3D).material_override = sm


func _apply_roof() -> void:
	if _model == null:
		return
	var roof := _model.find_child("roof", true, false)
	if roof is MeshInstance3D:
		var sh := Shader.new()
		sh.code = ROOF_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("roof_color", color)
		(roof as MeshInstance3D).material_override = m


func _pop() -> void:
	if _model == null:
		return
	var s := _model.scale
	_model.scale = s * 0.78
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_model, "scale", s, 0.38)
