# Android build (AAB) + AdMob — step by step

Goal: a signed `.aab` you can upload to Google Play (internal testing) and run on
Samsung Remote Test Lab, with AdMob ads wired.

Project side is ready: the **Android export preset** exists (`com.toybox.kingdoms`,
gradle build on, arm64, internet perm, min SDK 24 / target SDK 34) and the monetization
code has isolated `_native_*` seams (see `docs/MONETIZATION_SETUP.md`). The steps below
are the machine/account setup only you can do.

---

## 1. Install the toolchain (one-time)
1. **JDK 17** (Godot 4.6 Android needs 17): install Temurin/OpenJDK 17, confirm `java -version`.
2. **Android SDK** — easiest via **Android Studio** (installs SDK + platform-tools). Then in
   the SDK Manager install: **Platform 34** (or current), **Build-Tools 34**, **Platform-Tools**,
   **NDK** (the version Godot 4.6 wants — see Godot's docs), **CMake**.
   - Note the SDK path (e.g. `C:\Users\rpandian\AppData\Local\Android\Sdk`).
3. **Godot editor settings** (*Editor → Editor Settings → Export → Android*): set the
   **Java SDK path** (JDK 17) and the **Android SDK path**. Godot will show green checks
   when both are valid.

## 2. Install the Android build template
- *Project → Install Android Build Template…* This creates `android/build/` in the project
  (Gradle project Godot compiles into the AAB). Required because we use a custom gradle
  build (for plugins).

## 3. Create a signing keystore (one-time)
```
keytool -genkeypair -v -keystore toybox-release.keystore -alias toybox \
  -keyalg RSA -keysize 2048 -validity 10000
```
Keep this file + passwords safe (lose it → can't update the app). Set it in the editor:
*Editor Settings → Export → Android* (debug keystore) and in the **Android preset →
Keystore (release)** fields (path, user, password). Keep `package/signed=true`.

## 4. Install the AdMob plugin
1. Get the maintained **Godot 4 AdMob plugin** (Poing Studios / cropco "Godot AdMob") for
   your Godot version. Copy its `addons/admob/` into the project; enable it in
   *Project Settings → Plugins*. (For Godot 4 this is a v2 Android plugin — enabling it
   registers the export plugin + the `AdMob` Engine singleton that `MonetizationManager`
   detects.)
2. **AdMob console** (admob.google.com): create the app + an **Interstitial** and a
   **Rewarded** ad unit (Android). Put the **AdMob App ID** where the plugin asks (usually
   a Project Setting it adds, or its `AndroidManifest` snippet).
3. Fill `core/monetization_config.gd`: paste your real ad-unit ids into `*_REAL`. Leave
   `USE_TEST_ADS = true` for now (test ads — never tap a live ad on your own device).
4. Paste the AdMob calls into `MonetizationManager._native_*` per `docs/MONETIZATION_SETUP.md`
   (only after the plugin is installed, else the script won't parse).
5. The plugin should add the `com.google.android.gms.permission.AD_ID` permission; verify
   it's in the final manifest.

## 5. Export the AAB
- **From the editor:** *Project → Export → Android → Export Project…* → `build/android/toybox_kingdoms.aab`.
- **Headless (once SDK/JDK/template/keystore are set):**
```
godot --headless --path . --export-release "Android" build/android/toybox_kingdoms.aab
```
  (Use `--export-debug` for a test build to sideload / Remote Test Lab.)

## 6. Test
- **Samsung Remote Test Lab**: upload the APK/AAB (or a debug APK), play it on a real device
  — smoke test that it runs, the HUD fits, touch works, the revive ad shows (test ad).
- **Google Play Console** ($25 one-time): create the app → **Internal testing** → upload the
  AAB → read the **pre-launch report** (auto Firebase Test Lab: crashes/compat/perf).
- Then **Closed/Open testing** for real users → retention + your analytics.

## 7. Store-readiness checklist (before any public track)
- Signed AAB, target SDK at Google's current minimum.
- App icon (set `launcher_icons/*` in the preset), screenshots, feature graphic.
- **Privacy policy** URL, **Data safety** form (you collect analytics + serve ads → declare it).
- **Content rating** questionnaire.
- AdMob: link the app, set ad units live + `USE_TEST_ADS = false` for the production build.

## Notes
- Keep test ads on until launch; add your device as an AdMob **test device**.
- Analytics are local-only right now — to see retention from testers, set `ENDPOINT` in
  `core/analytics.gd` to a collector (or rely on Play Console stats).
- The build can't be produced on a machine without JDK + Android SDK + the build template;
  there's nothing more to do in-repo until those are installed.
