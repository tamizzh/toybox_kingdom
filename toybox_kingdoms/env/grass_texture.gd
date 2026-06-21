extends RefCounted

# Procedural, seamlessly-tileable grass texture built at runtime (no asset import).
# Three octaves of wrapping value-noise blended across three greens give a soft
# stylized lawn with patches + fine speckle, plus a few tiny flowers. Mipmapped so
# it stays smooth (no shimmer) when tiled across the big ground plane.

static func make(size: int = 192) -> ImageTexture:
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var coarse := _grid(6, 1011)
	var fine := _grid(18, 2027)
	var speck := _grid(46, 3041)
	var c_dark := Color("39661f")
	var c_mid := Color("548c35")
	var c_lite := Color("70ad48")
	var flower := _grid(60, 5099)
	var flower_cols := [Color("f4e04d"), Color("ffffff"), Color("f29ad0")]
	for y in size:
		var v := float(y) / size
		for x in size:
			var u := float(x) / size
			var a := _sample(coarse, 6, u, v)
			var b := _sample(fine, 18, u, v)
			var s := _sample(speck, 46, u, v)
			var t := clampf(a * 0.55 + b * 0.30 + s * 0.15, 0.0, 1.0)
			var col := c_dark.lerp(c_mid, smoothstep(0.15, 0.55, t)).lerp(c_lite, smoothstep(0.55, 0.95, t))
			# sparse little flowers in the brighter patches
			if _sample(flower, 60, u, v) > 0.93 and t > 0.5:
				col = flower_cols[(x + y) % flower_cols.size()]
			img.set_pixelv(Vector2i(x, y), col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _grid(g: int, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var arr := PackedFloat32Array()
	arr.resize(g * g)
	for i in g * g:
		arr[i] = rng.randf()
	return arr

# Bilinear smoothstep sample of a wrapping grid -> seamless tile.
static func _sample(grid: PackedFloat32Array, g: int, u: float, v: float) -> float:
	var fx := u * g
	var fy := v * g
	var x0 := int(floor(fx)) % g
	var y0 := int(floor(fy)) % g
	var x1 := (x0 + 1) % g
	var y1 := (y0 + 1) % g
	var tx := smoothstep(0.0, 1.0, fx - floor(fx))
	var ty := smoothstep(0.0, 1.0, fy - floor(fy))
	var top := lerpf(grid[y0 * g + x0], grid[y0 * g + x1], tx)
	var bot := lerpf(grid[y1 * g + x0], grid[y1 * g + x1], tx)
	return lerpf(top, bot, ty)
