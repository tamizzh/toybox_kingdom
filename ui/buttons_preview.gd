@tool
extends Control
## Open this scene in the editor to preview all button variants live.

const UIKit := preload("res://ui/ui_kit.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("141a28")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("margin_left", 80)
	col.add_theme_constant_override("margin_top", 60)
	add_child(col)

	var heading := Label.new()
	heading.text = "Button Variants"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	col.add_child(heading)

	_row(col, "Primary — large (w=280)",
		UIKit.stone_btn("CONQUER", true, Callable(), 280, 26))
	_row(col, "Primary — medium (w=260)",
		UIKit.stone_btn("PLAY TODAY", true, Callable(), 260, 22))
	_row(col, "Primary — small (w=220)",
		UIKit.stone_btn("NEXT", true, Callable(), 220, 20))

	_row(col, "Secondary — medium (w=200)",
		UIKit.stone_btn("CLOSE", false, Callable(), 200, 20))
	_row(col, "Secondary — small (w=160)",
		UIKit.stone_btn("SKIP", false, Callable(), 160, 18))
	_row(col, "Secondary — wide (w=240)",
		UIKit.stone_btn("Restore Purchases", false, Callable(), 240, 20))
	_row(col, "Secondary — wide (w=220)",
		UIKit.stone_btn("Privacy Policy", false, Callable(), 220, 20))


func _row(parent: Node, label_text: String, btn: TextureButton) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	lbl.custom_minimum_size = Vector2(240, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	row.add_child(btn)
