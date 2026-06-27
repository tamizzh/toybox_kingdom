class_name MonetizationConfig
extends RefCounted

# All ad-unit / product IDs in one place. AdMob (Google) is the target ad SDK.
#
# Ships with Google's official TEST ad units so ads work end-to-end in a dev build
# WITHOUT risking your AdMob account (never tap a live ad in test). Set USE_TEST_ADS
# to false and fill the *_REAL ids for a release build.
#
# IMPORTANT: using real ad units before launch (or tapping your own live ads) can get
# an AdMob account banned — keep USE_TEST_ADS true until you ship.

const USE_TEST_ADS := true

# ── Google sample/test ad units (safe for development) ────────────────────────
const TEST_INTERSTITIAL_ANDROID := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ANDROID     := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_IOS     := "ca-app-pub-3940256099942544/4411468910"
const TEST_REWARDED_IOS         := "ca-app-pub-3940256099942544/1712485313"

# ── your real ad units (AdMob console) — fill before release ──────────────────
const INTERSTITIAL_ANDROID_REAL := ""
const REWARDED_ANDROID_REAL     := ""
const INTERSTITIAL_IOS_REAL     := ""
const REWARDED_IOS_REAL         := ""

# ── IAP products (must match Play Console / App Store Connect product ids) ─────
# Cosmetic pack products come from Cosmetics.product_of(id): pack_neon / pack_pastel / pack_candy.
const PRODUCT_REMOVE_ADS := "remove_ads"

static func _is_ios() -> bool:
	return OS.get_name() == "iOS"

static func interstitial_id() -> String:
	if USE_TEST_ADS:
		return TEST_INTERSTITIAL_IOS if _is_ios() else TEST_INTERSTITIAL_ANDROID
	return INTERSTITIAL_IOS_REAL if _is_ios() else INTERSTITIAL_ANDROID_REAL

static func rewarded_id() -> String:
	if USE_TEST_ADS:
		return TEST_REWARDED_IOS if _is_ios() else TEST_REWARDED_ANDROID
	return REWARDED_IOS_REAL if _is_ios() else REWARDED_ANDROID_REAL
