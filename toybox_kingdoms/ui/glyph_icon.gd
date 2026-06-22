extends Control

# A tiny sticker-pictogram Control: draws one DrawKit.hud_glyph centred in its
# rect. Used for the build-toolbar cards and the left action stack so the HUD
# matches the target art's iconography without any image assets.

var kind: String = "castle"
var color: Color = Color.WHITE
var radius: float = 0.0          # 0 = auto-fit from the control size

func setup(p_kind: String, p_color: Color = Color.WHITE, p_size: float = 48.0) -> Control:
	kind = p_kind
	color = p_color
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self

func _draw() -> void:
	var r := radius if radius > 0.0 else minf(size.x, size.y) * 0.40
	DrawKit.hud_glyph(self, size * 0.5, r, kind, color)
