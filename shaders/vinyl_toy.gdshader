shader_type spatial;
// Shiny toy-vinyl look for the player mascots. Half-lambert wrap + fake SSS keeps
// the spheres soft and rounded. Strong GGX spec + wide fresnel rim + a baked
// "candy-coat" catch-light (white dot) sell the premium shiny-toy read.
// Works on the Mobile renderer (no SSS feature needed).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  base_color   : source_color = vec4(0.86, 0.16, 0.16, 1.0);
uniform float roughness    : hint_range(0.0, 1.0) = 0.08;  // very glossy — toy surface
uniform float specular     : hint_range(0.0, 1.0) = 0.78;

uniform float wrap         : hint_range(0.0, 1.0) = 0.45;  // half-lambert softness
uniform vec4  sss_tint     : source_color = vec4(1.0, 0.72, 0.64, 1.0);  // gentle warmth, not heavy red
uniform float sss_strength : hint_range(0.0, 1.0) = 0.30;

uniform vec4  rim_color    : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_power    : hint_range(0.5, 8.0) = 3.5;   // wide rim → candy-coat halo around silhouette
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;  // strong glow for shiny-toy pop

// Baked catch-light: a bright white dot from a fixed upper-left camera-space
// direction simulates the unmistakable specular blob on shiny plastic/vinyl toys.
uniform float catchlight_power    : hint_range(1.0, 128.0) = 42.0;
uniform float catchlight_strength : hint_range(0.0, 2.0)   = 0.70;

void fragment() {
	ALBEDO    = base_color.rgb;
	ROUGHNESS = roughness;
	METALLIC  = 0.0;
	SPECULAR  = specular;

	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);

	// Wide fresnel rim — candy-coat halo.
	float rim = pow(1.0 - ndv, rim_power);

	// Baked catch-light: fixed upper-left key in view space so the dot tracks
	// the normal as the blob rotates, giving a lively shiny-toy look.
	vec3  key     = normalize(vec3(-0.35, 0.70, 0.60));
	float ndl_key = clamp(dot(normalize(NORMAL), key), 0.0, 1.0);
	float spot    = pow(ndl_key, catchlight_power) * catchlight_strength;

	EMISSION = rim_color.rgb * rim * rim_strength + vec3(spot);
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
