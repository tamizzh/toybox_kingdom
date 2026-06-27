# Monetization setup (AdMob + Google Play Billing)

The game's monetization **flow is already wired** in `core/monetization_manager.gd`
(consent gating, rewarded preload/cache + reward callback, interstitial frequency cap,
IAP grant/restore, analytics). Only the native SDK calls — isolated in the `_native_*`
methods — are left empty. This doc covers the **external setup** you must do and the
**exact code** to paste into those methods.

Until then the game runs fine everywhere with simulated ads/purchases. IDs live in
`core/monetization_config.gd` (ships with Google's TEST ad units; `USE_TEST_ADS = true`).

> Ads only ever activate when the plugin's Engine singleton is detected, so desktop/
> headless/CI keep using the safe simulated path automatically.

---

## A. External setup (you, outside Godot)

1. **Android export template + custom build.** In Godot: *Project → Install Android Build
   Template*. In the Android export preset, enable **Use Gradle Build**.
2. **Install the AdMob plugin.** Use the maintained Godot 4 plugin
   (Poing Studios / cropco "Godot AdMob"): download the release matching your Godot
   version, copy `addons/admob/` into the project, and enable it in
   *Project → Project Settings → Plugins*. Enabling it registers the Android singleton
   (`AdMob` / `PoingGodotAdMob*`) that `MonetizationManager._ready()` detects.
3. **AdMob console** (admob.google.com): create an app, then an **Interstitial** and a
   **Rewarded** ad unit for Android (and iOS if shipping there). Put your AdMob **App ID**
   in the plugin's settings/AndroidManifest as the plugin docs require.
4. **Fill `monetization_config.gd`**: paste your real ad-unit ids into the `*_REAL`
   constants and set `USE_TEST_ADS = false` **only for release builds**. Keep test ads on
   in dev — tapping a live ad on your own device can get your AdMob account banned.
5. **Google Play Billing** (for IAP): install the Godot Google Play Billing plugin; in
   Play Console create the products — `remove_ads` plus the cosmetic packs `pack_neon`,
   `pack_pastel`, `pack_candy` (must match `Cosmetics.product_of(...)`).
6. **iOS** (optional): AdMob iOS framework + StoreKit; mirror the ad units/products and
   add the App Tracking Transparency usage string.

## B. Code to paste (the `_native_*` methods)

Exact symbols vary by plugin **version** — check the plugin's own example scene and adjust
names if needed. Shape against the Poing Studios Godot 4 AdMob API:

```gdscript
func _native_init_ads() -> void:
    MobileAds.initialize()
    # optional: MobileAds.set_request_configuration(...) with your test device id

func _native_load_rewarded() -> void:
    var cb := RewardedAdLoadCallback.new()
    cb.on_ad_loaded = func(ad: RewardedAd) -> void:
        _rewarded_ad = ad
        _rewarded_loaded = true
    cb.on_ad_failed_to_load = func(_err) -> void:
        _rewarded_loaded = false
    RewardedAd.load(Config.rewarded_id(), AdRequest.new(), cb)

func _native_show_rewarded() -> void:
    var content := FullScreenContentCallback.new()
    content.on_ad_dismissed_full_screen_content = func() -> void: _on_rewarded_closed()
    content.on_ad_failed_to_show_full_screen_content = func(_e) -> void: _on_rewarded_closed()
    _rewarded_ad.full_screen_content_callback = content
    var listener := OnUserEarnedRewardListener.new()
    listener.on_user_earned_reward = func(_reward) -> void: _on_rewarded_earned()
    _rewarded_ad.show(listener)

func _native_load_interstitial() -> void:
    var cb := InterstitialAdLoadCallback.new()
    cb.on_ad_loaded = func(ad: InterstitialAd) -> void: _interstitial_ad = ad
    InterstitialAd.load(Config.interstitial_id(), AdRequest.new(), cb)

func _native_show_interstitial() -> void:
    if _interstitial_ad == null: return
    var content := FullScreenContentCallback.new()
    content.on_ad_dismissed_full_screen_content = func() -> void:
        _interstitial_ad = null
        _native_load_interstitial()
    _interstitial_ad.full_screen_content_callback = content
    _interstitial_ad.show()

func _native_apply_consent(_accepted: bool) -> void:
    # UMP: request ConsentInformation.update(...), then load+show ConsentForm if required.
    pass
```

Add the two ad handles near the top of the script:
`var _rewarded_ad; var _interstitial_ad`.

> These reference plugin classes (`RewardedAd`, etc.), so only paste them **after** the
> plugin is installed — otherwise the script won't parse. Keep the bodies empty until then.

### IAP (Google Play Billing — shape; check your plugin version's signals)

```gdscript
func _native_init_iap() -> void:
    var b := Engine.get_singleton("GodotGooglePlayBilling")
    b.connect("purchases_updated", _on_purchases_updated)
    b.startConnection()

func _native_purchase(product_id: String, on_done: Callable) -> void:
    _pending_iap_done = on_done
    Engine.get_singleton("GodotGooglePlayBilling").purchase(product_id)

func _on_purchases_updated(purchases) -> void:
    for p in purchases:
        _grant(p.sku)                       # grant entitlement
        Engine.get_singleton("GodotGooglePlayBilling").acknowledgePurchase(p.purchase_token)
    if _pending_iap_done.is_valid(): _pending_iap_done.call("")

func _native_restore() -> void:
    var owned = Engine.get_singleton("GodotGooglePlayBilling").queryPurchases("inapp")
    # for each owned purchase: _grant(sku)
```

## C. Testing

- **Desktop/editor**: no plugin → everything simulates (rewarded grants instantly, IAP
  grants instantly). Use this to test Shop/consent/offer flows.
- **Device with test ads**: real AdMob test ads render; rewarded reward fires the real
  callback chain (`_on_rewarded_earned` → `_on_rewarded_closed` → payout + preload).
- Add your device as a **test device** in AdMob to avoid policy issues.
- Verify analytics: `ad` events (interstitial / rewarded_request / rewarded) and
  `iap_purchase` show up in `user://analytics_log.jsonl`.

## D. Where it's called from

- **Rewarded**: `MonetizationManager.show_rewarded(on_reward, "<placement>")` — wire offers
  like revive / 2× coins / instant upgrade to this.
- **Interstitial**: `note_round_finished()` each match end, then `maybe_show_interstitial()`
  (frequency-capped, suppressed by remove-ads).
- **IAP**: `purchase(product_id, on_done)` / `restore()` from `ui/shop_screen.gd`.
- **Consent**: gate first launch on `needs_consent()` → `mark_consent(accepted)`.

---

## E. iOS — building on a Mac

iOS is a **separate native build** from Android: different plugins (`.xcframework`, not
`.aar`), a separate export preset, and it can **only** be built on macOS with Xcode.
The shared code already supports it — `monetization_config.gd` returns the iOS ad units
via `_is_ios()`, and the `_native_*` seams stay the same — but on iOS those methods call
the **iOS** plugin's API, so you'll branch on `OS.get_name() == "iOS"` (or keep a separate
iOS adapter) behind the same seams.

> ⚠️ Verify the AdMob plugin you picked actually ships an **iOS** build for Godot 4 — the
> common one (Poing Studios/cropco) has been Android-first. If there's no iOS
> `.xcframework`, use an iOS-capable plugin or build a small Swift/Obj-C plugin wrapping
> the Google Mobile Ads SDK.

### E.1 Prerequisites
- A **Mac** with the latest **Xcode** (from the App Store) + command line tools.
- An **Apple Developer Program** membership ($99/yr) and a signing **Team**.
- **CocoaPods**: `sudo gem install cocoapods` (or `brew install cocoapods`).
- Godot **iOS export templates** for your exact version: *Editor → Manage Export
  Templates → Download* (or they come bundled with the editor).

### E.2 Install the iOS plugins
Godot iOS plugins are a `.gdip` config + the native library (`.a` / `.xcframework`).
1. Copy the **AdMob iOS** plugin and the **StoreKit IAP iOS** plugin into `res://ios/plugins/`
   (create the folder). Each plugin = its `.gdip` + library files.
2. In the **iOS export preset** (*Project → Export → iOS*), the plugins appear under a
   **Plugins** section — enable both. (The Android `.aar` plugin is NOT used here.)

### E.3 Configure the iOS export preset
- **Bundle Identifier**: `com.toybox.kingdoms` (must match App Store Connect).
- **Team ID** / signing: your Apple Developer team.
- **Required reason / privacy**: add the **App Tracking Transparency** usage string —
  set `NSUserTrackingUsageDescription` (Godot exposes ATT/privacy fields in the preset, or
  you add it to the generated `Info.plist`), e.g.
  *"We use your data to show you more relevant ads."*
- **AdMob App ID**: add `GADApplicationIdentifier` (your iOS AdMob app id) to `Info.plist`.
- **SKAdNetwork**: add the `SKAdNetworkItems` list (Google publishes the current
  SKAdNetwork IDs for AdMob) to `Info.plist` so ad attribution works.

### E.4 ATT + consent on iOS
Wire the ATT prompt inside `_native_apply_consent()` (it runs from `mark_consent`). On
iOS request tracking authorization (the iOS AdMob/ATT plugin exposes this) **before**
initializing ads, then continue with UMP for GDPR. Keep ads non-personalized until both
consent and ATT are resolved.

### E.5 Build / run on Mac
1. In Godot: **Export → iOS → Export Project** → choose an output folder. Godot generates
   an **Xcode project** there (and, when a plugin declares pods, a `Podfile`).
2. In Terminal, `cd` to the export folder and run **`pod install`** (installs the Google
   Mobile Ads SDK + any plugin pods).
3. Open the generated **`.xcworkspace`** (not `.xcodeproj`) in Xcode.
4. Select your **signing Team**, pick a connected device (ads/IAP don't run in the
   Simulator), and **Run**.
5. To test IAP: create a **Sandbox tester** in App Store Connect and sign in on the
   device; create the products (`remove_ads`, `pack_neon/pastel/candy`) in App Store
   Connect first.
6. To distribute: **Product → Archive → Distribute** → upload to App Store Connect →
   **TestFlight** for testing, then submit for review.

### E.6 Notes
- Keep `USE_TEST_ADS = true` and add your device as an AdMob **test device** until launch.
- Re-run `pod install` whenever you re-export from Godot if pod dependencies changed.
- Recommended order: ship **Android first** (buildable on Windows), validate the loop +
  CPI, then do the iOS build once the numbers justify the extra setup.
