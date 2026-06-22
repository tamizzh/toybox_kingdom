extends Node3D

# ── TerritoryGround: raised CLAY continent (the toybox-diorama look) ───────────
# One subdivided plane the size of the grid, lifted into a bumpy clay plateau that
# sits above the surrounding water. A grid-sized ownership texture (one texel per
# cell) drives a single shader:
#   • neutral cells  -> muted green clay (unconquered wilderness)
#   • owned cells    -> that kingdom's saturated clay, with tonal mottling
#   • cell seams     -> darkened (baked AO line) so regions read as sculpted
#   • the coastline  -> a lighter sandy rim before it drops to the water
# 1 draw call. The only per-tick cost is repainting the 128x96 ownership image.

const TOP_Y := 0.04          # clay surface height (props sit here); base slab is flush under it
const BUMP := 0.035          # soft board relief; props stay grounded and readable

const SHADER_CODE := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D own : filter_nearest;       // R = kingdom idx/255, A = claimed (crisp colour)
uniform sampler2D own_l : filter_linear;      // same texture, smooth — drives plateau height
uniform vec3 kcolors[8];
uniform vec2 grid_size = vec2(128.0, 96.0);
// Natural wilderness palette (sampled from the authored grass/soil tiles).
uniform vec3 grass_dark = vec3(0.24, 0.36, 0.13);
uniform vec3 grass_mid  = vec3(0.38, 0.54, 0.19);
uniform vec3 grass_lite = vec3(0.52, 0.70, 0.28);
uniform vec3 soil_col   = vec3(0.46, 0.35, 0.22);
uniform vec3 sand_col = vec3(0.34, 0.30, 0.20);      // muted coast, doesn't glow
uniform float bump_amp = 0.045;
uniform float plateau = 0.115;                // claimed land rises into thicker toy-board plates

float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
	vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

varying vec3 v_world;

void vertex(){
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bump = vnoise(w.xz * 1.2) * bump_amp + vnoise(w.xz * 5.0) * bump_amp * 0.4;
	// claimed land rises into a gentle plateau (small, so props stay aligned)
	float claimed = texture(own_l, UV).a;
	VERTEX.y += bump + smoothstep(0.1, 0.85, claimed) * plateau;
	v_world = w;
}

void fragment(){
	vec2 uv = UV;
	vec2 px = 1.0 / grid_size;
	vec4 here = texture(own, uv);
	float claimed = here.a;
	int idx = int(floor(here.r * 255.0 + 0.5));
	bool is_claimed = claimed > 0.5;
	float m = vnoise(v_world.xz * 0.62);
	vec2 cuv = fract(uv * grid_size);

	// seam: a dark rim where a neighbour has a different owner → every plate (and
	// the wilderness next to it) reads as a raised, AO'd toy-board tile.
	float seam = 0.0;
	seam += float(texture(own, uv + vec2(px.x, 0)).r != here.r);
	seam += float(texture(own, uv - vec2(px.x, 0)).r != here.r);
	seam += float(texture(own, uv + vec2(0, px.y)).r != here.r);
	seam += float(texture(own, uv - vec2(0, px.y)).r != here.r);
	float seam_ao = mix(1.0, 0.72, clamp(seam, 0.0, 1.0));

	// per-cell bevel normal (claimed plates only)
	vec2 fc = abs(cuv - 0.5);
	vec2 tilt = vec2(smoothstep(0.35, 0.5, fc.x), smoothstep(0.35, 0.5, fc.y));
	vec2 sgn = sign(cuv - 0.5);
	vec3 nrm = normalize(vec3(tilt.x * sgn.x * 0.18 * claimed, 1.0, tilt.y * sgn.y * 0.18 * claimed));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);

	// sandy coast rim around the whole continent before the water
	float edge = min(min(uv.x, 1.0 - uv.x) * grid_size.x, min(uv.y, 1.0 - uv.y) * grid_size.y);
	float coast = smoothstep(0.0, 3.0, edge);

	if (is_claimed) {
		// Keep the plate's colour RICH. Same-hue sheen, never white.
		vec3 base = kcolors[idx] * seam_ao;
		base = mix(sand_col, base, coast);
		vec2 gloss_uv = cuv - vec2(0.34, 0.22);
		float view_gloss = pow(clamp(1.0 - length(gloss_uv) * 2.4, 0.0, 1.0), 3.0);
		ALBEDO = base * 0.96 + base * 0.08 * view_gloss;
		ROUGHNESS = 0.62;
		SPECULAR = 0.06;
	} else {
		// Natural wilderness: rolling grass with organic SOIL patches, all driven
		// by smooth noise (not the grid) so it reads as terrain, not a tiled floor.
		// The scattered trees/rocks/bushes (env/scatter.gd) supply the fine detail.
		float nb = vnoise(v_world.xz * 0.45);
		float nm = vnoise(v_world.xz * 1.7 + 5.0);
		float nf = vnoise(v_world.xz * 6.5 + 11.0);
		vec3 grass = mix(grass_dark, grass_mid, smoothstep(0.25, 0.75, nb));
		grass = mix(grass, grass_lite, smoothstep(0.55, 0.95, nm) * 0.6);
		grass *= 0.93 + nf * 0.14;                      // fine blade speckle
		float soil = smoothstep(0.60, 0.74, vnoise(v_world.xz * 0.5 + 19.0));
		vec3 g = mix(grass, soil_col * (0.9 + nf * 0.2), soil);
		g *= seam_ao;                                    // gap shadow next to a plate
		g = mix(sand_col, g, coast);                     // sandy coast
		ALBEDO = g;
		ROUGHNESS = 0.9;
		SPECULAR = 0.08;
	}
}
"""

var grid
var colors := {}
var _img: Image
var _tex: ImageTexture
var _w: int
var _h: int

func setup(p_grid, p_cell: float, p_colors: Dictionary) -> void:
	grid = p_grid
	colors = p_colors
	_w = grid.w
	_h = grid.h
	_img = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_tex = ImageTexture.create_from_image(_img)

	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(_w * p_cell, _h * p_cell)
	pm.subdivide_width = _w           # one quad per cell -> per-cell clay bumps
	pm.subdivide_depth = _h
	mesh.mesh = pm

	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	mat.shader = sh
	mat.set_shader_parameter("own", _tex)
	mat.set_shader_parameter("own_l", _tex)
	mat.set_shader_parameter("grid_size", Vector2(_w, _h))
	mat.set_shader_parameter("bump_amp", BUMP)
	# Kingdom tiles use the exact same base colour as castle roofs.
	var pal := PackedVector3Array()
	pal.resize(8)
	for i in 8:
		var c: Color = colors.get(i + 1, Color.GRAY)
		pal[i] = Vector3(c.r, c.g, c.b)
	mat.set_shader_parameter("kcolors", pal)
	mesh.material_override = mat
	mesh.position = Vector3(0, TOP_Y, 0)
	add_child(mesh)

# Repaint the ownership texture from the grid (throttled dirty tick).
func update() -> void:
	for y in _h:
		var row := y * _w
		for x in _w:
			var oid: int = grid.owner[row + x]
			if oid == 0:
				_img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				_img.set_pixel(x, y, Color(float(oid - 1) / 255.0, 0, 0, 1.0))
	_tex.update(_img)
