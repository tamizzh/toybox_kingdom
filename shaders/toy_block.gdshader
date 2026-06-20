shader_type spatial;
// Beveled molded-plastic toy block for the LEGO-style border walls.
// Adds a soft fresnel rim (volume), a tight plastic spec, and a faint
// repeating star overlay blended into the albedo. Works on the Mobile renderer.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  base_color   : source_color = vec4(0.91, 0.19, 0.19, 1.0);
uniform float roughness    : hint_range(0.0, 1.0) = 0.30;   // glossy plastic
uniform float metallic     : hint_range(0.0, 1.0) = 0.0;
uniform float specular     : hint_range(0.0, 1.0) = 0.55;   // tight highlight

// Faint star pattern baked into the albedo (premium molded look).
uniform sampler2D star_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float star_scale    = 2.5;
uniform float star_strength : hint_range(0.0, 1.0) = 0.10;
uniform vec2  star_offset   = vec2(0.0);

// Soft rim light / fresnel that fakes rounded, clay-like volume on flat-ish faces.
uniform vec4  rim_color    : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_power    : hint_range(0.5, 8.0) = 3.2;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.45;

void fragment() {
	vec3 albedo = base_color.rgb;

	// Star overlay — lightens the surface slightly where the star mask is white.
	float star = texture(star_tex, UV * star_scale + star_offset).r;
	albedo = mix(albedo, albedo * 1.35 + vec3(0.05), star * star_strength);

	ALBEDO    = albedo;
	ROUGHNESS = roughness;
	METALLIC  = metallic;
	SPECULAR  = specular;

	// Fresnel rim → emission so it reads even in shadow, giving soft molded volume.
	float ndv  = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim  = pow(1.0 - ndv, rim_power);
	EMISSION   = rim_color.rgb * rim * rim_strength;
}
