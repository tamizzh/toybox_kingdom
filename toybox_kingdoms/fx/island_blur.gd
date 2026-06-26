extends MeshInstance3D

# ── IslandBlur: soft-focus everything OUTSIDE the play board ──────────────────
# A fullscreen post-process quad that reads the rendered frame + depth, rebuilds
# each pixel's WORLD position, and blurs it by how far it sits OUTSIDE the grid
# rectangle (the island). The board itself stays perfectly crisp; the surrounding
# apron/background melts into a soft tilt-shift haze so the eye locks onto the
# kingdom — the "miniature diorama under glass" read.
#
# Why world-space and not a screen vignette: the camera follows the player, so the
# island is rarely screen-centred. Masking in world XZ keeps the focus glued to the
# board regardless of where the camera roams.

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform vec2 board_half = vec2(38.4, 28.8);  // half extents of the island in world XZ
uniform float inset = 1.0;                    // start blurring this far OUTSIDE the coast
uniform float feather = 10.0;                 // world distance over which blur ramps to full
uniform float max_px = 22.0;                  // peak blur radius, in screen pixels

void vertex() {
	// Fullscreen pass: drive clip space directly, ignore the quad's transform.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float depth = texture(depth_tex, uv).r;
	// Reconstruct world position from depth (Godot reversed-Z post-process recipe).
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;

	// How far this pixel lies outside the island rectangle (0 on/inside the board).
	vec2 d = abs(world.xz) - board_half;
	float outside = length(max(d, vec2(0.0)));
	float amt = smoothstep(inset, inset + feather, outside);

	vec3 col = texture(screen_tex, uv).rgb;
	if (amt > 0.001) {
		vec2 radius = (1.0 / VIEWPORT_SIZE) * max_px * amt;
		vec3 acc = col;
		float total = 1.0;
		// 16-tap two-ring disk — cheap, smooth enough for a soft background.
		for (int i = 0; i < 16; i++) {
			float a = float(i) * 0.39269908;            // 2*PI / 16
			float r = float(i % 2) * 0.5 + 0.5;         // alternate inner/outer ring
			vec2 off = vec2(cos(a), sin(a)) * radius * r;
			acc += texture(screen_tex, uv + off).rgb;
			total += 1.0;
		}
		col = acc / total;
	}
	ALBEDO = col;
}
"""

# Tune the island bounds + blur falloff. Call once after instancing.
func setup(p_board_half: Vector2, p_inset := 1.0, p_feather := 10.0, p_max_px := 22.0) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad

	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	mat.shader = sh
	mat.set_shader_parameter("board_half", p_board_half)
	mat.set_shader_parameter("inset", p_inset)
	mat.set_shader_parameter("feather", p_feather)
	mat.set_shader_parameter("max_px", p_max_px)
	material_override = mat

	# The vertex shader writes clip space directly, so the quad's transform is moot —
	# but Godot still frustum-culls by AABB. A big cull margin keeps it from vanishing.
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Draw after the scene so the screen texture holds the finished frame.
	sorting_offset = 1000.0
