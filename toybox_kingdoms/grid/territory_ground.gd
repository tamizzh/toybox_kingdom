extends Node3D

# ── TerritoryGround: raised CLAY continent (the toybox-diorama look) ───────────
# One subdivided plane the size of the grid, lifted into a bumpy clay plateau that
# sits above the surrounding water. A grid-sized ownership texture (one texel per
# cell) drives a single shader:
#   • neutral cells  -> muted green clay (unconquered wilderness)
#   • owned cells    -> that kingdom's saturated clay, with tonal mottling
#   • cell seams     -> darkened (baked AO line) so regions read as sculpted
#   • the coastline  -> a lighter sandy rim before it drops to the water
# 1 draw call. The only per-tick cost is repainting the dirty rect of the grid-sized
# (GW×GH) ownership image — see update()'s bounded loop.

const TOP_Y := 0.04          # clay surface height (props sit here); base slab is flush under it
const BUMP := 0.014          # near-flat board relief (target reads handcrafted-flat, not bumpy clay); plateau still gives the silhouette

const SHADER_CODE := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D own : filter_nearest;       // R = kingdom idx/255, A = claimed (crisp colour)
uniform sampler2D own_l : filter_linear;      // same texture, smooth — drives plateau height
uniform vec3 kcolors[8];
uniform vec2 grid_size = vec2(128.0, 96.0);
uniform vec2 active_half = vec2(38.4, 28.8);  // world-unit half-extents of the active (non-frozen) zone
uniform sampler2D land_mask : filter_nearest;  // R=1 land, R=0 ocean; default all-white (no mask)
uniform vec3 paper_neutral = vec3(0.24, 0.65, 0.13);
uniform vec3 sand_col = vec3(0.88, 0.79, 0.55);
uniform float bump_amp = 0.045;
uniform float plateau = 0.115;
// low_gfx=1 on web/mobile: skip all vnoise() calls (each is 4 sin() evals;
// at 28k verts + ~1M neutral frags per frame they dominate WebGL2 GPU time).
uniform float low_gfx = 0.0;

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
	// Skip vertex noise on web/mobile — eliminates 2× vnoise() per vertex on a 28k-vert mesh.
	float bump = (low_gfx < 0.5) ? (vnoise(w.xz * 1.2) * bump_amp + vnoise(w.xz * 5.0) * bump_amp * 0.4) : 0.0;
	float claimed = texture(own_l, UV).a;
	VERTEX.y += bump + smoothstep(0.1, 0.85, claimed) * plateau;
	v_world = w;
}

void fragment(){
	vec2 uv = UV;
	vec2 px = 1.0 / grid_size;

	float is_land = texture(land_mask, uv).r;
	if (is_land < 0.5) {
		discard;
	}

	vec4 here = texture(own, uv);
	float claimed = here.a;
	int idx = int(floor(here.r * 255.0 + 0.5));
	bool is_claimed = claimed > 0.5;
	vec2 cuv = fract(uv * grid_size);

	float border = 0.0;
	border += float(texture(own, uv + vec2(px.x, 0)).r != here.r);
	border += float(texture(own, uv - vec2(px.x, 0)).r != here.r);
	border += float(texture(own, uv + vec2(0, px.y)).r != here.r);
	border += float(texture(own, uv - vec2(0, px.y)).r != here.r);
	float rim = clamp(border, 0.0, 1.0);

	vec2 fc = abs(cuv - 0.5);
	vec2 tilt = vec2(smoothstep(0.35, 0.5, fc.x), smoothstep(0.35, 0.5, fc.y));
	vec2 sgn = sign(cuv - 0.5);
	vec3 nrm = normalize(vec3(tilt.x * sgn.x * mix(0.09, 0.18, claimed), 1.0, tilt.y * sgn.y * mix(0.09, 0.18, claimed)));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);

	// Coastline — 4 land_mask samples (needed even on low_gfx for beach colour).
	float n_land = texture(land_mask, uv + vec2(0.0,  px.y)).r
	             + texture(land_mask, uv - vec2(0.0,  px.y)).r
	             + texture(land_mask, uv + vec2(px.x,  0.0)).r
	             + texture(land_mask, uv - vec2(px.x,  0.0)).r;
	float edge_rect = min(min(uv.x, 1.0 - uv.x) * grid_size.x,
	                      min(uv.y, 1.0 - uv.y) * grid_size.y);
	float coast_rect = smoothstep(0.0, 5.0, edge_rect);
	float coast_mask = smoothstep(2.5, 4.0, n_land);
	float coast = min(coast_rect, coast_mask);

	vec3 base;
	if (is_claimed) {
		base = kcolors[idx];
	} else if (low_gfx > 0.5) {
		// Flat neutral colour on web/mobile — skip all vnoise() fragment calls.
		// The border rim still reads as a lighter separation line.
		base = mix(paper_neutral, mix(paper_neutral, vec3(1.0), 0.4), rim * 0.5);
	} else {
		float sn  = vnoise(v_world.xz * 0.22 + 7.0);
		float sn2 = vnoise(v_world.xz * 0.55 + 19.3);
		float ch  = hash(floor(uv * grid_size) * 1.7 + 3.0);
		vec3 warm = paper_neutral * vec3(1.03, 1.00, 0.90);
		vec3 cool = paper_neutral * vec3(0.97, 1.00, 1.10);
		base = mix(cool, warm, sn2);
		if      (ch > 0.985) base *= 0.82;
		else if (ch > 0.970) base *= 1.07;
		else if (ch > 0.955) base = mix(base, vec3(0.16, 0.60, 0.22), 0.12);
		else if (ch > 0.940) base = mix(base, vec3(0.38, 0.58, 0.07), 0.09);
		base *= (0.97 + sn * 0.05);
		base = mix(base, mix(paper_neutral, vec3(1.0), 0.4), rim * 0.5);
	}
	base = mix(sand_col, base, coast);

	// ── Rectangular frozen zone (active_half — used when WORLD_CONQUEST = false).
	// When WORLD_CONQUEST is on, active_half equals the full grid so rect_frost = 0.
	vec2 from_active = abs(v_world.xz) - active_half;
	float inside_cells = max(-max(from_active.x, from_active.y), 0.0) / 0.6;
	float frost_blend = smoothstep(3.0, 0.0, inside_cells);
	vec3 frost_col = vec3(0.78, 0.90, 0.97);
	base = mix(base, frost_col, frost_blend * 0.85);

	// Matte cardstock everywhere: no sheen, no specular highlight.
	ALBEDO = base;
	ROUGHNESS = 0.95;
	SPECULAR = 0.02;
}
"""

var grid
var colors := {}
var _img: Image
var _tex: ImageTexture
var _buf: PackedByteArray   # reused RGBA8 scratch — avoids per-pixel set_pixel/Color churn
var _w: int
var _h: int
var _mat: ShaderMaterial

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
	# Subdivision controls vertex count for the bump displacement. On web the vertex
	# shader noise is disabled entirely, so subdivision only matters for geometry
	# smoothness — use sub_div=4 (6.9k verts vs 28k at sub_div=2) on web. On mobile
	# (native GL) keep sub_div=2 for the slight relief effect.
	var sub_div: int = 1
	if DeviceMode.is_web: sub_div = 4
	elif DeviceMode.is_mobile: sub_div = 2
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
	mat.set_shader_parameter("bump_amp", 0.0 if DeviceMode.low_gfx else BUMP)
	mat.set_shader_parameter("plateau", 0.0)
	mat.set_shader_parameter("low_gfx", 1.0 if DeviceMode.low_gfx else 0.0)
	# Kingdom tiles use the exact same base colour as castle roofs.
	var pal := PackedVector3Array()
	pal.resize(8)
	for i in 8:
		var c: Color = colors.get(i + 1, Color.GRAY)
		pal[i] = Vector3(c.r, c.g, c.b)
	mat.set_shader_parameter("kcolors", pal)
	mat.set_shader_parameter("active_half", pm.size * 0.5)
	# Default land_mask: all-white 1×1 texture (every cell is land — no country shape applied).
	var white_img := Image.create(1, 1, false, Image.FORMAT_R8)
	white_img.fill(Color(1, 1, 1))
	mat.set_shader_parameter("land_mask", ImageTexture.create_from_image(white_img))
	_mat = mat
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

func set_active_half(new_half: Vector2) -> void:
	if _mat:
		_mat.set_shader_parameter("active_half", new_half)

func set_land_mask(mask: PackedByteArray) -> void:
	if not _mat:
		return
	# Build the R8 texture from a single buffer upload instead of 12k set_pixel()
	# calls (each allocs a Color + bounds-checks) — same result, ~10-50x cheaper.
	var n := _w * _h
	var buf := PackedByteArray()
	buf.resize(n)
	var count: int = mini(mask.size(), n)
	for i in count:
		buf[i] = 255 if mask[i] != 0 else 0
	var img := Image.create_from_data(_w, _h, false, Image.FORMAT_R8, buf)
	_mat.set_shader_parameter("land_mask", ImageTexture.create_from_image(img))
