shader_type spatial;
// Dark matte concrete-slate tile. A noise-driven roughness break-up catches the
// key light softly (so flat tiles don't read as dead matte), with an optional
// crisp "painted" overlay (arrows / stars) sampled with mipmaps so it never
// pixelates at grazing camera angles. Mobile-renderer safe.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  slate_a      : source_color = vec4(0.408, 0.451, 0.510, 1.0); // 687382 darker slate
uniform vec4  slate_b      : source_color = vec4(0.345, 0.388, 0.447, 1.0); // 586372 deeper slate
uniform float tile_blend   : hint_range(0.0, 1.0) = 0.0; // 0 = slate_a, 1 = slate_b (set per checker cell)

uniform float rough_base   : hint_range(0.0, 1.0) = 0.78;
uniform float rough_var    : hint_range(0.0, 0.5) = 0.14;
uniform sampler2D rough_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float noise_scale   = 3.0;

// Painted-on decals (arrows, stars). Premultiplied/with alpha; tinted by paint_color.
uniform sampler2D paint_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec4  paint_color  : source_color = vec4(1.0, 0.62, 0.18, 1.0);
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0; // 0 = no paint on this tile

void fragment() {
	vec3 base = mix(slate_a.rgb, slate_b.rgb, tile_blend);

	float n = texture(rough_noise, UV * noise_scale).r;
	ROUGHNESS = clamp(rough_base + (n - 0.5) * 2.0 * rough_var, 0.0, 1.0);
	METALLIC  = 0.0;
	SPECULAR  = 0.35;

	vec4 paint = texture(paint_tex, UV);
	float pa = paint.a * paint_amount;
	ALBEDO = mix(base, paint_color.rgb, pa);
}
