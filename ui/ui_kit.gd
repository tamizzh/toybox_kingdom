## Shared button factory for all menu overlays.
## Matches the glossy toy-button aesthetic of the main menu PLAY button.
## Always uses the SM texture (410×155, ratio ≈ 2.65:1) for all overlay buttons.
##
##   Primary (gold) : CONQUER, PLAY, NEXT, RESUME, PLAY AGAIN
##   Secondary (blue): CLOSE, SKIP, MAIN MENU, Give Up
##
## Usage:
##   var b := UIKit.stone_btn("CONQUER", true, my_callback)
##   var b := UIKit.stone_btn("CLOSE", false, my_callback, 220.0)
class_name UIKit

const _GOLD_SM := preload("res://assets/btn_gold_sm.png")
const _BLUE_SM := preload("res://assets/btn_blue_sm.png")

# Natural aspect ratio (width/height) of the SM texture.
const _R_SM := 410.0 / 155.0   # ≈ 2.65


## Returns a TextureButton — callers use .pressed.connect(), size_flags, add_child() as normal.
static func stone_btn(text: String, primary: bool, cb: Callable,
		w: float = 220.0, font_size: int = 22) -> TextureButton:
	var tex: Texture2D = _GOLD_SM if primary else _BLUE_SM
	var ratio: float   = _R_SM

	var text_col   := Color(0.28, 0.13, 0.01) if primary else Color(0.04, 0.10, 0.32)
	var hover_tint := Color(1.08, 1.04, 0.88) if primary else Color(0.88, 0.95, 1.08)
	var press_tint := Color(0.78, 0.68, 0.40) if primary else Color(0.62, 0.78, 0.94)
	var h          := roundf(w / ratio)

	# TextureButton renders the PNG directly — no theme, no background fill.
	var b := TextureButton.new()
	b.texture_normal    = tex
	b.stretch_mode      = TextureButton.STRETCH_SCALE
	b.ignore_texture_size = true   # prevents 410×155 texture from inflating minimum size
	b.focus_mode        = Control.FOCUS_NONE
	b.custom_minimum_size    = Vector2(w, h)
	b.size_flags_horizontal  = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical    = Control.SIZE_SHRINK_CENTER

	# CenterContainer fills the button face (excludes bottom shadow ~20% of height).
	var ctr := CenterContainer.new()
	ctr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ctr.offset_bottom = -roundf(h * 0.22)   # trim shadow area so text centers on the face
	ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ctr)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctr.add_child(lbl)

	# Hover / press feedback via modulate + subtle label nudge.
	b.mouse_entered.connect(func() -> void: b.modulate = hover_tint)
	b.mouse_exited.connect(func()  -> void: b.modulate = Color.WHITE)
	b.button_down.connect(func()   -> void: b.modulate = press_tint; ctr.position.y = 2)
	b.button_up.connect(func()     -> void: b.modulate = Color.WHITE; ctr.position.y = 0)

	if cb.is_valid():
		b.pressed.connect(cb)
	return b
