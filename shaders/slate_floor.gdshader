shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Blue periwinkle rubber playground tiles in a checkerboard — matches target.png.
// Two alternating blues laid out as a real per-tile checker, with a soft darker
// groove at the seam and a faint sprinkle of light stars over the surface.
uniform vec4  slate_a      : source_color = vec4(0.30, 0.35, 0.46, 1.0); // lighter blue-gray rubber
uniform vec4  slate_b      : source_color = vec4(0.24, 0.29, 0.39, 1.0); // deeper blue partner
uniform float tile_blend   : hint_range(0.0, 1.0) = 0.0; // unused (checker drives the blend)

// Scattered star sprinkle over the floor (assets/star_overlay.png = white stars
// on black). Sampled in world space, added as a subtle lightening.
uniform sampler2D star_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float star_scale    = 0.035;                 // ~1 star per tile
uniform float star_strength : hint_range(0.0, 1.0) = 0.08;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float world_noise_scale = 0.85;
uniform float fine_noise_scale  = 3.4;
uniform float albedo_noise  : hint_range(0.0, 2.0) = 0.24;
uniform float noise_contrast : hint_range(1.0, 6.0) = 2.0;
uniform float rough_base    : hint_range(0.0, 1.0) = 0.82;
uniform float rough_var     : hint_range(0.0, 0.5) = 0.08;

// Must match ts_x / ts_z in wall_arena3d.gd — set via shader parameter
uniform float tile_pitch_x = 3.2;
uniform float tile_pitch_z = 3.2;

// Bevel profile (target.png): the tile top is a near-flat plateau; right at the
// seam it dips into a soft dark groove, with a faint bright lip just inside the
// groove catching the key light. width = fraction of half-tile the bevel spans.
uniform float bevel_width  : hint_range(0.01, 0.40) = 0.13;
uniform float groove_dark  : hint_range(0.5, 1.0)   = 0.55;  // darkest at the seam
uniform float lip_bright   : hint_range(0.0, 0.6)   = 0.16;  // bright lip just inside
uniform float bevel_dir    : hint_range(0.0, 0.5)   = 0.06;
// Faint cool-warm catchlight tint on the bright lip, neutral on the plateau
uniform vec3  bevel_warm                            = vec3(1.04, 1.02, 0.98);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Per-tile checkerboard: alternate the two blues based on the tile cell index.
	vec2 cell = floor(world_pos.xz / vec2(tile_pitch_x, tile_pitch_z));
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 base = mix(slate_a.rgb, slate_b.rgb, checker);

	// Two octaves of world-space noise → broad mottling + fine rubber surface grit
	float n_broad = texture(noise_tex, world_pos.xz * world_noise_scale).r;
	float n_fine  = texture(noise_tex, world_pos.xz * fine_noise_scale).r;
	float n = mix(n_broad, n_fine, 0.45);
	float dev = clamp((n - 0.5) * noise_contrast, -0.5, 0.5);
	base *= 1.0 + dev * albedo_noise;

	// Bevel: world-space fract gives tile-relative UV (0=edge, 0.5=centre, 1=edge)
	vec2 tile_uv = fract(world_pos.xz / vec2(tile_pitch_x, tile_pitch_z));
	float ex = min(tile_uv.x, 1.0 - tile_uv.x) / bevel_width;
	float ez = min(tile_uv.y, 1.0 - tile_uv.y) / bevel_width;
	float edge_t = clamp(min(ex, ez), 0.0, 1.0);  // 0 = seam, 1 = plateau

	// Groove: darkest at the seam, ramps up to the flat plateau (1.0). Uses the
	// first ~half of the bevel band so the plateau stays large and uniform.
	float groove = mix(groove_dark, 1.0, smoothstep(0.0, 0.55, edge_t));

	// Bright lip: a thin gaussian ridge sitting just inside the groove, brightest
	// where the key light grazes the raised edge.
	float lip = exp(-pow((edge_t - 0.50) / 0.26, 2.0));
	// Directional: top-left lip catches more of the afternoon key light
	float dir = (1.0 - tile_uv.x) * 0.5 + tile_uv.y * 0.5;
	lip *= 1.0 + (dir - 0.5) * 2.0 * bevel_dir / max(lip_bright, 0.001);

	float bev = groove + lip * lip_bright;
	vec3 warm_tint = mix(vec3(1.0), bevel_warm, clamp(lip, 0.0, 1.0));
	base = clamp(base * bev * warm_tint, 0.0, 1.0);

	// Faint star sprinkle over the tiles (lighten toward a soft periwinkle-white).
	float star = texture(star_tex, world_pos.xz * star_scale).r;
	base = mix(base, vec3(0.78, 0.82, 0.92), star * star_strength);

	ALBEDO    = base;
	ROUGHNESS = clamp(rough_base + (n - 0.5) * 2.0 * rough_var, 0.0, 1.0);
	METALLIC  = 0.0;
	SPECULAR  = 0.28;  // soft satin sheen on the rubber tiles
}
