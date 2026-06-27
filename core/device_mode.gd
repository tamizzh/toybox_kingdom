extends Node

# Autoload. Decides whether we're running as a phone/tablet (touch-first,
# fullscreen) or a desktop (keyboard + a big window) and sizes the window to
# suit. Mini-games and UI can read `DeviceMode.is_mobile` / `DeviceMode.has_touch`.
#
# Why this exists: the project's design size is 1560x720. Left alone, that opens
# as a tiny box in the middle of a desktop monitor. Here we instead maximize on
# desktop and go fullscreen on mobile. The 3D camera re-frames itself to the
# viewport and the 2D UI uses `canvas_items` stretch, so both scale up cleanly.

# Manual override for testing on a PC: "" = auto-detect, "desktop", or "mobile".
# (Or pass --mobile / --desktop on the command line — see below.)
const FORCE_MODE := ""

var is_mobile: bool = false
var has_touch: bool = false

# Whether we're running in a browser. This is the *graphics budget* flag, kept
# separate from `is_mobile` (which drives the touch UI). A desktop browser stays
# is_mobile=false (keyboard UI) but is_web=true so the renderer can drop the
# expensive post-processing that gl_compatibility (WebGL2) chokes on.
var is_web: bool = false

# Predicate the renderer should branch on for the lighter graphics path:
# any web build OR any mobile device.
var low_gfx: bool = false

func _ready() -> void:
	# Master switch. OS.has_feature("mobile") is false in the desktop editor and
	# desktop exports, true on Android/iOS. We deliberately do NOT use
	# DisplayServer.is_touchscreen_available() to decide this: it returns true on
	# desktop whenever `emulate_touch_from_mouse` is enabled (it is, in this
	# project), which would wrongly force the mobile/touch UI on a PC.
	is_mobile = OS.has_feature("mobile")

	# Touch sticks follow the mode: shown on mobile, hidden on a desktop.
	has_touch = is_mobile

	# Web is special: the HTML5 export reports OS.has_feature("mobile") == false
	# even inside a phone browser, so the line above would force desktop UI + the
	# heavy (full-res, lit) render path onto weak mobile-web GPUs. Sniff the
	# browser instead — a touchscreen / mobile user-agent flips us to the mobile
	# (touch-first, downscaled) path; a desktop browser stays on desktop.
	if OS.has_feature("web"):
		_detect_web()

	# CLI / FORCE_MODE override everything above (manual testing on a PC).
	var cli := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if FORCE_MODE == "mobile" or "--mobile" in cli:
		is_mobile = true
		has_touch = true
	elif FORCE_MODE == "desktop" or "--desktop" in cli:
		is_mobile = false
		has_touch = false

	# Graphics budget. Web (any browser) and mobile both take the lighter render
	# path. `--web` lets us exercise the web tier from a desktop test run.
	is_web = OS.has_feature("web") or "--web" in cli
	low_gfx = is_mobile or is_web

	# Wait one frame so the main window exists before we resize it.
	_apply_window.call_deferred()

func _apply_window() -> void:
	# Force VSync ON at runtime. The project.godot window/vsync/vsync_mode key is
	# not always honored (editor "Play", some D3D12 paths), so we set it explicitly
	# here — this is the real fix for the screen tearing. ENABLED = the GPU presents
	# in lock-step with the monitor refresh, so a frame is never torn mid-scanout.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

	# Desktop: project.godot window/size/mode=0 opens a 1560x720 windowed box.
	# Mobile fullscreen is forced here because the export templates
	# handle the window differently on Android/iOS. On web the canvas size is
	# owned by the host page, so we leave the window alone there.
	if is_mobile and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# Browser sniff for the web export: decide touch-first vs desktop from the actual
# browser. navigator.maxTouchPoints catches touchscreens; the user-agent regex
# catches phones/tablets (and lets us pick the mobile perf path on them).
func _detect_web() -> void:
	var ua := str(JavaScriptBridge.eval("navigator.userAgent || ''", true)).to_lower()
	var touch_points := int(JavaScriptBridge.eval("navigator.maxTouchPoints || 0", true))
	var re := RegEx.new()
	re.compile("android|iphone|ipad|ipod|iemobile|blackberry|opera mini|mobile")
	var mobile_ua := re.search(ua) != null
	# iPadOS 13+ reports a desktop UA but has touch points — treat any touchscreen
	# browser as mobile so it gets the touch controls.
	is_mobile = mobile_ua or touch_points > 0
	has_touch = is_mobile
