extends MeshInstance3D

# ── Ocean: animated sea ringing the island ───────────────────────────────────
# One big glossy plane sitting just BELOW the island board, so everything outside
# the grid rectangle reads as open water. A single fragment shader does it all:
#   • drifting fbm ripples perturb the normal → the sun glints + shimmers on the swell
#   • depth gradient from deep navy out at sea to a lighter teal near the shallows
#   • a wobbling FOAM ring hugs the island's coastline (the rectangle edge, noised so
#     it isn't a clean box) — the white surf where waves meet the beach
# The island plane (territory_ground) is opaque and drawn on top, so the sea is only
# ever visible OUTSIDE the board. 1 draw call, no geometry waves (flat plane).

const SHADER_CODE := """
shader_type spatial;
render_mode cull_back;

uniform vec3 deep = vec3(0.02, 0.17, 0.40);     // open-sea navy
uniform vec3 shallow = vec3(0.09, 0.45, 0.62);  // teal near the shallows
uniform vec3 foam_col = vec3(0.92, 0.97, 1.0);  // surf white
uniform vec2 board_half = vec2(38.4, 28.8);     // island half-extents (world XZ)
uniform float foam_band = 3.0;                  // width of the surf ring (world units)
uniform float wave_amp = 0.35;                  // ripple normal strength
uniform float speed = 1.0;

float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
	vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}
float fbm(vec2 p){
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++){ v += a * vnoise(p); p *= 2.0; a *= 0.5; }
	return v;
}

varying vec3 v_world;
void vertex(){ v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment(){
	vec2 w = v_world.xz;
	float t = TIME * 0.05 * speed;
	vec2 uv1 = w * 0.06 + vec2(t, t * 0.6);
	vec2 uv2 = w * 0.12 - vec2(t * 0.8, t);
	float swell = fbm(uv1) * 0.6 + fbm(uv2) * 0.4;

	// Water colour: deep out at sea, lifting toward teal on the crests.
	vec3 col = mix(deep, shallow, clamp(swell * 0.8 + 0.1, 0.0, 1.0));

	// Ripple normal — central-difference the noise so the sun catches the swell.
	float e = 0.15;
	float nx = fbm(uv1 + vec2(e, 0.0)) - fbm(uv1 - vec2(e, 0.0));
	float nz = fbm(uv1 + vec2(0.0, e)) - fbm(uv1 - vec2(0.0, e));
	vec3 wn = normalize(vec3(-nx * wave_amp, 1.0, -nz * wave_amp));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Shoreline foam: distance OUTSIDE the island rectangle, wobbled by noise so the
	// surf line breaks unevenly instead of tracing a crisp rectangle.
	vec2 d = abs(w) - board_half;
	float outside = length(max(d, vec2(0.0)));
	float wobble = (fbm(w * 0.4 + t * 3.0) - 0.5) * 2.2;
	float edge = outside + wobble;
	float shore = 1.0 - smoothstep(0.0, foam_band, edge);
	// a brighter crest right at the waterline, foamy spray fading outward
	float crest = smoothstep(0.0, 0.6, shore) * (0.6 + 0.4 * fbm(w * 0.8 - t * 4.0));
	col = mix(col, foam_col, clamp(shore * 0.5 + crest * 0.6, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = 0.12;     // glossy water → tight sun glint
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
"""

func setup(p_board_half: Vector2, p_extent := 360.0, p_y := -0.16) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(p_board_half.x * 2.0 + p_extent, p_board_half.y * 2.0 + p_extent)
	mesh = pm

	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	mat.shader = sh
	mat.set_shader_parameter("board_half", p_board_half)
	material_override = mat

	position = Vector3(0, p_y, 0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
