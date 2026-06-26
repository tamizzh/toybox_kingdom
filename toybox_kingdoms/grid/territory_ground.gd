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
// Wilderness uses the authored grass (0-3) + soil (4) TILES, one per cell.
uniform sampler2DArray terrain_tex : filter_linear_mipmap;
// Wilderness samples the authored tiles (7 grass variants + the dirt tile's
// cracked-stone pattern) for their bevel + DETAIL only, then drives the hue from
// these clean colours — so it reads as grass/soil tiles with the tile grid intact,
// without the tiles' wrong raw hues (yellow grass, blue "dirt").
uniform vec3 grass_a = vec3(0.24, 0.46, 0.17);       // deep green
uniform vec3 grass_b = vec3(0.37, 0.60, 0.22);       // mid green (lush)
uniform vec3 grass_c = vec3(0.52, 0.71, 0.29);       // light green
uniform vec3 soil_col = vec3(0.47, 0.34, 0.21);      // earthy brown
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
		// Tiled wilderness: the AUTHORED painted tiles (tiles.png), shown with their
		// REAL colour — lush grass with the occasional flower, plus rare dirt patches.
		// One tile per cell; a per-cell 90° rotation + variant hash breaks the grid
		// repetition so it reads as a continuous meadow, not a stamped checkerboard.
		vec2 cell_id = floor(uv * grid_size);
		vec2 tuv = fract(uv * grid_size);
		// rotate the tile 0/90/180/270 deg per cell (kills the "same flower every cell" look)
		int rot = int(floor(hash(cell_id + 5.1) * 4.0));
		vec2 rc = tuv - 0.5;
		if (rot == 1) rc = vec2(-rc.y, rc.x);
		else if (rot == 2) rc = -rc;
		else if (rot == 3) rc = vec2(rc.y, -rc.x);
		tuv = rc + 0.5;
		float gh = hash(cell_id + 0.37);
		float soil = smoothstep(0.74, 0.84, vnoise(v_world.xz * 0.5 + 19.0));  // rare dirt clumps (~10-15%)
		bool is_soil = soil > 0.5;
		// layers 0-3 = grass variants (tiles.png bottom row), layer 4 = dirt (middle row)
		float layer = is_soil ? 4.0 : floor(gh * 4.0);
		vec3 t = texture(terrain_tex, vec3(tuv, layer)).rgb;
		vec3 g;
		if (is_soil) {
			// the raw dirt tile is too orange → salmon under the grade; pull it to an
			// earthy brown while keeping the pebble detail.
			g = vec3(t.r * 0.58, t.g * 0.70, t.b * 0.85);
		} else {
			// tiles.png grass is chartreuse (blue≈0) → neon under the grade. Remap to a
			// rich, natural grass green, deriving the missing blue from the green channel,
			// while KEEPING the painted detail (tufts read as lighter patches).
			// low blue (t.g*0.18) keeps it a rich grass green, not a pale mint.
			vec3 green = vec3(t.r * 0.42, t.g * 0.68, t.g * 0.18);
			// flowers/highlights are bright + actually have blue → keep them as light
			// specks instead of flattening them to green (preserves the tile's charm).
			float flower = smoothstep(0.30, 0.55, t.b);
			g = mix(green, t * 0.9, flower);
		}
		// subtle large-scale brightness variation so the open field has gentle tonal movement
		float sn = vnoise(v_world.xz * 0.30 + 7.0);
		g *= (0.88 + sn * 0.16);
		g *= seam_ao;                                     // gap shadow next to a plate
		g = mix(sand_col, g, coast);                      // sandy coast
		ALBEDO = g;
		ROUGHNESS = 0.88;
		SPECULAR = 0.10;
	}
}
"""

var grid
var colors := {}
var _img: Image
var _tex: ImageTexture
var _buf: PackedByteArray   # reused RGBA8 scratch — avoids per-pixel set_pixel/Color churn
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
	_buf = PackedByteArray()
	_buf.resize(_w * _h * 4)

	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(_w * p_cell, _h * p_cell)
	# One quad per cell gives per-cell clay bumps; on mobile we halve the subdivision
	# (~12k -> ~3k verts) — the ownership tint is sampled per-fragment from the texture
	# so only the geometric relief softens, which is invisible at the play camera.
	var sub_div: int = 2 if DeviceMode.is_mobile else 1
	pm.subdivide_width = _w / sub_div
	pm.subdivide_depth = _h / sub_div
	mesh.mesh = pm

	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	mat.shader = sh
	mat.set_shader_parameter("own", _tex)
	mat.set_shader_parameter("own_l", _tex)
	mat.set_shader_parameter("grid_size", Vector2(_w, _h))
	mat.set_shader_parameter("bump_amp", BUMP)
	mat.set_shader_parameter("terrain_tex", _build_terrain_array())
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

# Pack the painted tiles sliced from tiles.png into a Texture2DArray the shader
# samples per-cell: layers 0-3 = the four grass variants, layer 4 = a dirt tile.
# All forced to 128x128 with matching mipmaps (the array requires consistent
# mipmap usage across layers).
func _build_terrain_array() -> Texture2DArray:
	# The authored painted tiles sliced from tiles.png. Layers 0-3 = the four grass
	# variants (plain → flowered), layer 4 = a pebbly dirt tile for the rare dirt
	# patches. The shader now shows the tiles' REAL painted colour, so the order +
	# hue of these tiles matters directly.
	const TILES := [
		"res://assets/ground_grass_0.png",
		"res://assets/ground_grass_1.png",
		"res://assets/ground_grass_2.png",
		"res://assets/ground_grass_3.png",
		"res://assets/ground_dirt_1.png",
	]
	# Texture2DArray needs every layer in the same format with matching mipmaps.
	# Load the imported textures via load() and pull their Image — _prep_tile()
	# decompresses + reformats as needed. (The earlier Image.load_from_file on a
	# globalized path read the raw PNG off disk, which works in-editor but fails on
	# exported iOS builds where only the imported .ctex is packed, not the source PNG.)
	var imgs: Array[Image] = []
	for p in TILES:
		var tex: Texture2D = load(p)
		imgs.append(_prep_tile(tex.get_image()))
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)
	return arr

# Normalise a tile image for the array: RGBA8, 128x128, with mipmaps.
func _prep_tile(img: Image) -> Image:
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != 128 or img.get_height() != 128:
		img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	img.clear_mipmaps()
	img.generate_mipmaps()
	return img

# Repaint the ownership texture from the grid (throttled dirty tick).
# Writes a reused PackedByteArray and uploads once — ~10-50x cheaper than the
# per-pixel set_pixel()/Color path, and allocation-free per tick.
# Pass a dirty rect (x0,y0)..(x1,y1) to repaint only those rows; the default
# (no rect) repaints the whole board. _buf persists between calls, so cells outside
# the rect keep their last value and only the changed region is rewritten.
func update(x0: int = 0, y0: int = 0, x1: int = -1, y1: int = -1) -> void:
	if x1 < x0:
		x0 = 0; y0 = 0; x1 = _w - 1; y1 = _h - 1
	x0 = maxi(0, x0); y0 = maxi(0, y0)
	x1 = mini(_w - 1, x1); y1 = mini(_h - 1, y1)
	for cy in range(y0, y1 + 1):
		var row := cy * _w
		for cx in range(x0, x1 + 1):
			var i := row + cx
			var oid: int = grid.owner[i]
			var o := i * 4
			if oid == 0:
				_buf[o] = 0
				_buf[o + 1] = 0
				_buf[o + 2] = 0
				_buf[o + 3] = 0
			else:
				_buf[o] = oid - 1        # R: shader reads floor(R*255+0.5) == oid-1
				_buf[o + 1] = 0
				_buf[o + 2] = 0
				_buf[o + 3] = 255        # A = claimed
	_img.set_data(_w, _h, false, Image.FORMAT_RGBA8, _buf)
	_tex.update(_img)
