extends Node

# Autoload facade over ads + in-app purchases. On a device with the AdMob and
# Play-Billing / StoreKit plugins installed it drives the real SDKs; in the editor
# or on desktop (plugins absent) it falls back to SAFE SIMULATED behaviour so the
# Shop, Settings and consent flow are fully testable now. Every place that needs a
# real SDK call is marked TODO(real-sdk).

signal product_purchased(product_id)

const INTERSTITIAL_EVERY := 3   # at most one interstitial per N rounds

var ads_available: bool = false
var iap_available: bool = false
var _rounds_since_ad: int = 0

func _ready() -> void:
	# Real plugins register as Engine singletons; detect them.
	ads_available = Engine.has_singleton("AdMob") or Engine.has_singleton("PoingGodotAdMob")
	iap_available = Engine.has_singleton("GodotGooglePlayBilling") or Engine.has_singleton("InAppStore")
	# TODO(real-sdk): initialize AdMob, open the billing connection, query products.

# ── consent (GDPR/UMP + iOS ATT) ─────────────────────────────────────────────
func needs_consent() -> bool:
	return not SaveManager.consent_done()

func mark_consent(_accepted: bool) -> void:
	SaveManager.set_consent_done(true)
	# TODO(real-sdk): forward to UMP / request ATT and set ad personalization.

# ── ads ──────────────────────────────────────────────────────────────────────
func note_round_finished() -> void:
	_rounds_since_ad += 1

func maybe_show_interstitial() -> void:
	if SaveManager.has_remove_ads():
		return
	if _rounds_since_ad < INTERSTITIAL_EVERY:
		return
	_rounds_since_ad = 0
	if ads_available:
		pass  # TODO(real-sdk): AdMob.show_interstitial()
	else:
		print("[Monetization] (simulated) interstitial")

# Watch a rewarded ad; on_reward is called on success.
func show_rewarded(on_reward: Callable) -> void:
	if ads_available:
		# TODO(real-sdk): load + show rewarded; call on_reward in the reward cb.
		on_reward.call()
	else:
		print("[Monetization] (simulated) rewarded granted")
		on_reward.call()

# ── IAP ──────────────────────────────────────────────────────────────────────
func purchase(product_id: String, on_done: Callable = Callable()) -> void:
	if iap_available:
		# TODO(real-sdk): start the real purchase flow; grant in the purchase cb.
		_grant(product_id)
	else:
		print("[Monetization] (simulated) purchase: ", product_id)
		_grant(product_id)
	if on_done.is_valid():
		on_done.call(product_id)

func restore() -> void:
	# TODO(real-sdk): query owned entitlements and re-grant each.
	print("[Monetization] restore purchases requested")

func _grant(product_id: String) -> void:
	if product_id == "remove_ads":
		SaveManager.set_remove_ads(true)
	else:
		for id in Cosmetics.ids():
			if Cosmetics.product_of(id) == product_id:
				SaveManager.add_owned_pack(id)
	product_purchased.emit(product_id)
