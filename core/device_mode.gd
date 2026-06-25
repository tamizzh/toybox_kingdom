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

func _ready() -> void:
	# Master switch. OS.has_feature("mobile") is false in the desktop editor and
	# desktop exports, true on Android/iOS. We deliberately do NOT use
	# DisplayServer.is_touchscreen_available() to decide this: it returns true on
	# desktop whenever `emulate_touch_from_mouse` is enabled (it is, in this
	# project), which would wrongly force the mobile/touch UI on a PC.
	is_mobile = OS.has_feature("mobile")

	var cli := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if FORCE_MODE == "mobile" or "--mobile" in cli:
		is_mobile = true
	elif FORCE_MODE == "desktop" or "--desktop" in cli:
		is_mobile = false

	# Touch sticks follow the mode: shown on mobile, hidden on a desktop.
	has_touch = is_mobile

	# Wait one frame so the main window exists before we resize it.
	_apply_window.call_deferred()

func _apply_window() -> void:
	# Force VSync ON at runtime. The project.godot window/vsync/vsync_mode key is
	# not always honored (editor "Play", some D3D12 paths), so we set it explicitly
	# here — this is the real fix for the screen tearing. ENABLED = the GPU presents
	# in lock-step with the monitor refresh, so a frame is never torn mid-scanout.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

	# Desktop: project.godot window/size/mode=2 already starts maximized; no
	# code needed. Mobile fullscreen is set here because the export templates
	# handle the window differently on Android/iOS.
	if is_mobile:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
