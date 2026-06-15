extends Control

# On-screen action button. Feeds InputManager.set_action on press/release.
# Styled to match the toy-box reference: vivid coloured circle with icon glyph + label.

var player_id: int = 0
var radius: float   = 72.0
var caption: String = "ACTION"
var player_color: Color = Color("f02828")   # set by touch_controls
var _touch_index: int = -1
var _down: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_set_down(true)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_set_down(false)

func _set_down(v: bool) -> void:
	_down = v
	InputManager.set_action(player_id, v)
	if v:
		AudioManager.play("tap", randf_range(0.96, 1.06))
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var fill := player_color.darkened(0.10) if _down else player_color
	var scale_r := radius * (0.93 if _down else 1.0)

	# Drop shadow
	draw_circle(c + Vector2(0, 5), scale_r, Color(0, 0, 0, 0.22))
	# Dark outline ring
	draw_circle(c, scale_r, DrawKit.OUTLINE)
	# Player-colour fill
	draw_circle(c, scale_r - 4.0, fill)
	# Lighter top highlight (glossy feel)
	draw_circle(c + Vector2(0, -scale_r * 0.28), scale_r * 0.48, Color(1, 1, 1, 0.15))

	# Icon glyph (upper portion of circle)
	var glyph := _verb_to_glyph(caption)
	DrawKit.action_glyph(self, c + Vector2(0, -radius * 0.18), radius * 0.38, glyph, Color(1, 1, 1, 0.95))

	# Caption label (bottom portion)
	var font: Font = ArcadeTheme.font if ArcadeTheme.font else ThemeDB.fallback_font
	var fs := 19
	var tw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# Dark shadow
	draw_string(font, c + Vector2(-tw * 0.5 + 1, radius * 0.58 + 1),
				caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.55))
	# White label
	draw_string(font, c + Vector2(-tw * 0.5, radius * 0.58),
				caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.96))

func _verb_to_glyph(verb: String) -> String:
	match verb.to_lower():
		"run": return "run"
		"fire", "shoot": return "fire"
		"jump", "hop": return "jump"
		"throw", "bomb": return "throw"
		"slash", "sword", "hit": return "slash"
		"boost", "rip", "spin": return "boost"
		"tap", "stop", "go": return "tap"
		"hold", "king": return "hold"
		"kick", "punch": return "kick"
		_: return "run"
