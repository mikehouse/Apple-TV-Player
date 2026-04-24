
<img src="backup-icons-svg/live-glass-tvos-top-shelf-wide.svg" alt="">

# IPTV Player

Bro IPTV Player is a **free**, fast, private, and simple way to watch M3U playlists on iPhone, iPad, Mac, and Apple TV.

<p>
  <a href="https://apps.apple.com/us/app/bro-iptv-player/id6762360135" target="_blank" rel="noopener noreferrer">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="44">
  </a>
</p>

Features:
- Works across iOS, iPadOS, macOS, and tvOS
- Supports M3U and M3U8 playlists
- Supports EPG
- Protect playlists with a PIN for extra privacy
- Share playlists with other devices
- Free
- No account or registration required
- No ads, no tracking (only Firebase Crashlytics to collect crash reports)
- Open source (this repo contains the all application source code)
- 15 languages supported (ar, de, es, fr, hi, id, it, ja, ko, pt-BR, ru, th, tr, vi, zh-Hans)


‼️ **Important:**

Bro IPTV Player does not provide, host, sell, or include any channels, media, or playlists. The app only plays content added by the user, and you are responsible for having the rights to access that content.

----

## Apple TV
<img src="/docs/tvos-dark.webp" alt="">

----

## macOS
<img src="/docs/macos-dark.webp" alt="">

----

## iPad
<img src="/docs/ipad-dark.webp" alt="">

----

# For Developers

- Xcode 26.4+
- Swift 6.2+
- SwiftPM
- Ruby 3+ (`fastlane`)
- For now there is no CI/CD pipeline

```bash
bundle install
```

## App Signing

- Project is set for manual signing (you need to change it if you build for your own real device)
- Build for simulators you do not need to sign the app
- fastlane uses signing identities from `./.secrets/` directory (not committed to git)

## Build from Xcode

- Open a project in Xcode
- For the App scheme select `Signing and Capabilities`
- Set your `Bundle Identifier`
- Enable `Automatically manage signing`
- Xcode will do signing for your Team and Bundle Identifier

## Unit Testing

- iOS `bundle exec fastlane ios run_unit_tests` requires iOS 26.4 Simulator Runtime
- tvOS `bundle exec fastlane tvos run_unit_tests` requires tvOS 26.4 Simulator Runtime
- macOS `bundle exec fastlane mac run_unit_tests` runs on current machine

## UI Testing

Before any UI Tests must run a python local server that will provide mock data to the app.

```bash
./scripts/tests/server.py
```

### iOS

- iOS iPhone `bundle exec fastlane ios run_ui_snapshots_tests_iphone_26_4` requires iOS 26.4 Simulator Runtime
- iOS iPad `bundle exec fastlane ios run_ui_snapshots_tests_ipad_26_4` requires iOS 26.4 Simulator Runtime
- iOS iPhone `bundle exec fastlane ios run_ui_snapshots_tests_iphone_18_6` requires iOS 18.6 Simulator Runtime
- iOS iPad `bundle exec fastlane ios run_ui_snapshots_tests_ipad_18_6` requires iOS 18.6 Simulator Runtime

### tvOS

- tvOS `bundle exec fastlane tvos run_ui_snapshots_tests_appletv_26_4` requires tvOS 26.4 Simulator Runtime
- tvOS `bundle exec fastlane tvos run_ui_snapshots_tests_appletv_18_5` requires tvOS 18.6 Simulator Runtime

### macOS

Screenshots in repo created on macOS 26.2 with macOS SDK 26.4

```bash
bundle exec fastlane mac run_ui_snapshots_tests_macos
```

## Firebase Distribution

- iOS `bundle exec fastlane ios make_firebase_release`

## App Store Connect Distribution

1. Upload the app to testflight
2. Add that build to the distribution group to send to review

- iOS `bundle exec fastlane ios make_testflight_release`
- tvOS `bundle exec fastlane tvos make_testflight_release`
- macOS `bundle exec fastlane mac make_testflight_release`

## App Store Connect Snapshots and Metadata

### Regenerate snapshots for App Store Connect when the UI changes significantly

Must use the latest Simulator Runtime, now it is 26.4

- iOS iPhone `bundle exec fastlane ios make_app_store_snapshots_iphone_26_4` requires iOS 26.4 Simulator Runtime
- iOS iPad `bundle exec fastlane ios make_app_store_snapshots_ipad_26_4` requires iOS 26.4 Simulator Runtime
- tvOS `bundle exec fastlane tvos make_app_store_snapshots_appletv_26_4` requires tvOS 26.4 Simulator Runtime
- macOS `bundle exec fastlane tvos make_app_store_snapshots_macos` requires macOS SDK 26.4 Simulator Runtime and macOS 26 machine

### Upload snapshots to App Store Connect of new made or updated

- iOS `bundle exec fastlane ios upload_appstore_screenshots`
- tvOS `bundle exec fastlane tvos upload_appstore_screenshots`
- macOS `bundle exec fastlane mac upload_appstore_screenshots`

### If you changed metadata (description, keywords, etc.) upload it to App Store Connect

- iOS `bundle exec fastlane ios upload_appstore_metadata`
- tvOS `bundle exec fastlane tvos upload_appstore_metadata`
- macOS `bundle exec fastlane mac upload_appstore_metadata`

----

If you have any questions or ideas, please open an issue on GitHub.
