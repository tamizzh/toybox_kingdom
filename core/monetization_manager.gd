extends Node

# Autoload facade over ads + in-app purchases (AdMob + Google Play Billing / StoreKit).
#
# The full FLOW is real here — consent gating, rewarded preload/cache + reward callback,
# interstitial frequency cap, IAP grant/restore, analytics. Only the handful of native
# SDK calls are isolated in the `_native_*` methods at the bottom. Those currently
# simulate (so Shop / Settings / consent / rewarded offers are fully testable on desktop
# with no plugin), and become live the moment you install the AdMob plugin and paste the
# plugin calls into them. See docs/MONETIZATION_SETUP.md for the exact code + setup.
#
# Why the native calls are isolated and not inline: referencing the AdMob plugin's
# classes directly would make this script fail to PARSE on any build without the plugin
# (desktop, headless, CI). Keeping them in `_native_*` bodies — empty until you wire the
# plugin — keeps the game runnable everywhere and the integration in exactly one place.

signal product_purchased(product_id)

const Config := preload("res://core/monetization_config.gd")
const INTERSTITIAL_EVERY := 3   # at most one interstitial per N rounds

var ads_available: bool = false
var iap_available: bool = false

var _rounds_since_ad: int = 0
var _rewarded_loaded: bool = false
var _reward_cb: Callable = Callable()    # pending reward callback while a rewarded ad is showing
var _reward_placement: String = ""
var _reward_paid: bool = false           # did the current rewarded ad actually earn the reward?

func _ready() -> void:
	# Real plugins register as Engine singletons; detect them.
	ads_available = Engine.has_singleton("AdMob") or Engine.has_singleton("PoingGodotAdMob") \
		or Engine.has_singleton("PoingGodotAdMobAndroid")
	iap_available = Engine.has_singleton("GodotGooglePlayBilling") or Engine.has_singleton("InAppStore")
	if ads_available:
		_native_init_ads()
		_native_load_rewarded()
		_native_load_interstitial()
	if iap_available:
		_native_init_iap()

# ── consent (GDPR/UMP + iOS ATT) ─────────────────────────────────────────────
func needs_consent() -> bool:
	return not SaveManager.consent_done()

func mark_consent(accepted: bool) -> void:
	SaveManager.set_consent_done(true)
	_native_apply_consent(accepted)

# ── ads: interstitial (between rounds, frequency-capped, suppressed by remove-ads) ──
func note_round_finished() -> void:
	_rounds_since_ad += 1

func maybe_show_interstitial() -> void:
	if SaveManager.has_remove_ads():
		return
	if _rounds_since_ad < INTERSTITIAL_EVERY:
		return
	_rounds_since_ad = 0
	Analytics.ad_event("interstitial", "between_rounds", ads_available)
	if ads_available:
		_native_show_interstitial()
	else:
		print("[Monetization] (simulated) interstitial")

# ── ads: rewarded (opt-in; available even with remove-ads) ───────────────────
# Watch a rewarded ad; on_reward runs only if the ad is actually completed. `placement`
# tags which offer triggered it (revive / double_coins / ...) so analytics shows value.
func show_rewarded(on_reward: Callable, placement: String = "unknown") -> void:
	Analytics.ad_event("rewarded_request", placement, false)
	if ads_available and _rewarded_loaded:
		_reward_cb = on_reward
		_reward_placement = placement
		_reward_paid = false
		_native_show_rewarded()
		return
	# No plugin (desktop) or ad not loaded yet → grant immediately so the flow is testable.
	print("[Monetization] (simulated) rewarded granted: ", placement)
	Analytics.ad_event("rewarded", placement, true)
	if on_reward.is_valid():
		on_reward.call()

# Called from _native_* when the user earns the reward (the SDK reward callback).
func _on_rewarded_earned() -> void:
	_reward_paid = true

# Called from _native_* when the rewarded ad closes (earned or not). Pays out if earned,
# then preloads the next one.
func _on_rewarded_closed() -> void:
	if _reward_paid:
		Analytics.ad_event("rewarded", _reward_placement, true)
		if _reward_cb.is_valid():
			_reward_cb.call()
	else:
		Analytics.ad_event("rewarded", _reward_placement, false)
	_reward_cb = Callable()
	_reward_placement = ""
	_rewarded_loaded = false
	_native_load_rewarded()   # cache the next one

# ── IAP ──────────────────────────────────────────────────────────────────────
func purchase(product_id: String, on_done: Callable = Callable()) -> void:
	if iap_available:
		_native_purchase(product_id, on_done)
	else:
		print("[Monetization] (simulated) purchase: ", product_id)
		_grant(product_id)
		if on_done.is_valid():
			on_done.call(product_id)

func restore() -> void:
	if iap_available:
		_native_restore()
	else:
		print("[Monetization] (simulated) restore")

# Grant entitlements for a completed purchase. Call this from _native_purchase's success
# callback (and from _native_restore for each owned product).
func _grant(product_id: String) -> void:
	Analytics.iap_event(product_id, not iap_available)
	if product_id == Config.PRODUCT_REMOVE_ADS:
		SaveManager.set_remove_ads(true)
	else:
		for id in Cosmetics.ids():
			if Cosmetics.product_of(id) == product_id:
				SaveManager.add_owned_pack(id)
	product_purchased.emit(product_id)

# ── native SDK seams ──────────────────────────────────────────────────────────
# These are the ONLY methods that touch the plugin. They no-op/simulate until you paste
# the AdMob / Play Billing calls per docs/MONETIZATION_SETUP.md. Keep the call sites
# above unchanged. When wiring rewarded ads, route the SDK's reward callback to
# _on_rewarded_earned() and the close callback to _on_rewarded_closed().

func _native_init_ads() -> void:
	pass  # TODO(real-sdk): MobileAds.initialize(); set request config (test device ids).

func _native_apply_consent(_accepted: bool) -> void:
	pass  # TODO(real-sdk): drive UMP ConsentInformation / request ATT; set personalization.

func _native_load_interstitial() -> void:
	pass  # TODO(real-sdk): InterstitialAd.load(Config.interstitial_id(), AdRequest.new(), cb)

func _native_show_interstitial() -> void:
	pass  # TODO(real-sdk): show the cached interstitial; on close, _native_load_interstitial()

func _native_load_rewarded() -> void:
	# TODO(real-sdk): RewardedAd.load(Config.rewarded_id(), AdRequest.new(), cb);
	# on success set _rewarded_loaded = true.
	pass

func _native_show_rewarded() -> void:
	pass  # TODO(real-sdk): show cached RewardedAd; reward cb → _on_rewarded_earned(); dismiss cb → _on_rewarded_closed()

func _native_init_iap() -> void:
	pass  # TODO(real-sdk): connect billing client, query product details + owned purchases.

func _native_purchase(_product_id: String, _on_done: Callable) -> void:
	pass  # TODO(real-sdk): launch purchase flow; on success call _grant(id) + on_done

func _native_restore() -> void:
	pass  # TODO(real-sdk): query owned entitlements; _grant(id) for each
