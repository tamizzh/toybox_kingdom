shader_type spatial;
// Glossy designer-vinyl look for the player mascots. Custom light() gives a
// half-lambert wrap + cheap subsurface (warm light bleeding to the shadow side)
// so the spheres read as soft premium vinyl, not hard plastic. Tight GGX spec +
// fresnel rim sell the gloss. Works on the Mobile renderer (no SSS feature needed).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  base_color   : source_color = vec4(0.86, 0.16, 0.16, 1.0);
uniform float roughness    : hint_range(0.0, 1.0) = 0.20;  // glossy
uniform float specular     : hint_range(0.0, 1.0) = 0.62;

uniform float wrap         : hint_range(0.0, 1.0) = 0.45;  // half-lambert softness
uniform vec4  sss_tint     : source_color = vec4(1.0, 0.45, 0.40, 1.0);
uniform float sss_strength : hint_range(0.0, 1.0) = 0.30;

uniform vec4  rim_color    : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_power    : hint_range(0.5, 8.0) = 4.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.40;

void fragment() {
	ALBEDO    = base_color.rgb;
	ROUGHNESS = roughness;
	METALLIC  = 0.0;
	SPECULAR  = specular;

	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	EMISSION  = rim_color.rgb * pow(1.0 - ndv, rim_power) * rim_strength;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));

	// Half-lambert wrap → soft, rounded falloff (toy/vinyl signature).
	float wrapped = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	vec3  diffuse = ATTENUATION * LIGHT_COLOR * wrapped;

	// Fake SSS: warm tint bleeding onto the back/shadow side.
	float back = clamp(-ndl, 0.0, 1.0);
	vec3  sss  = sss_tint.rgb * back * sss_strength * LIGHT_COLOR * ATTENUATION;

	DIFFUSE_LIGHT += (diffuse + sss) * ALBEDO;
}
