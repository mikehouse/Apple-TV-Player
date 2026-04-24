fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build_dev

```sh
[bundle exec] fastlane ios build_dev
```



### ios make_firebase_release

```sh
[bundle exec] fastlane ios make_firebase_release
```

Builds an iOS ad-hoc release and uploads it to Firebase

### ios make_testflight_release

```sh
[bundle exec] fastlane ios make_testflight_release
```

Builds an iOS app-store release and uploads it to TestFlight

### ios upload_appstore_metadata

```sh
[bundle exec] fastlane ios upload_appstore_metadata
```

Upload metadata to the Distribution page on App Store Connect

### ios upload_appstore_screenshots

```sh
[bundle exec] fastlane ios upload_appstore_screenshots
```

Upload screenshots to the Distribution page on App Store Connect

### ios run_unit_tests

```sh
[bundle exec] fastlane ios run_unit_tests
```

Run unit tests on an iOS iPhone simulator

### ios run_ui_snapshots_tests_iphone_26_4

```sh
[bundle exec] fastlane ios run_ui_snapshots_tests_iphone_26_4
```

Run UI Snapshot Tests on an iOS 26.4 iPhone Simulator

### ios run_ui_snapshots_tests_ipad_26_4

```sh
[bundle exec] fastlane ios run_ui_snapshots_tests_ipad_26_4
```

Run UI Snapshot Tests on an iOS 26.4 iPad Simulator

### ios run_ui_snapshots_tests_iphone_18_6

```sh
[bundle exec] fastlane ios run_ui_snapshots_tests_iphone_18_6
```

Run UI Snapshot Tests on an iOS 18.6 iPhone Simulator

### ios run_ui_snapshots_tests_ipad_18_6

```sh
[bundle exec] fastlane ios run_ui_snapshots_tests_ipad_18_6
```

Run UI Snapshot Tests on an iOS 18.6 iPad Simulator

### ios make_app_store_snapshots_iphone_26_4

```sh
[bundle exec] fastlane ios make_app_store_snapshots_iphone_26_4
```

Re-generate app store snapshots for iOS 26.4 on iPhone

### ios make_app_store_snapshots_ipad_26_4

```sh
[bundle exec] fastlane ios make_app_store_snapshots_ipad_26_4
```

Re-generate app store snapshots for iOS 26.4 on iPad

----


## tvos

### tvos build_dev

```sh
[bundle exec] fastlane tvos build_dev
```



### tvos make_testflight_release

```sh
[bundle exec] fastlane tvos make_testflight_release
```

Builds an tvOS app-store release and uploads it to TestFlight

### tvos upload_appstore_metadata

```sh
[bundle exec] fastlane tvos upload_appstore_metadata
```

Upload metadata to the Distribution page on App Store Connect

### tvos upload_appstore_screenshots

```sh
[bundle exec] fastlane tvos upload_appstore_screenshots
```

Upload screenshots to the Distribution page on App Store Connect

### tvos run_unit_tests

```sh
[bundle exec] fastlane tvos run_unit_tests
```

Run unit tests on an tvOS simulator

### tvos run_ui_snapshots_tests_appletv_26_4

```sh
[bundle exec] fastlane tvos run_ui_snapshots_tests_appletv_26_4
```

Run UI Snapshot Tests on an tvOS 26.4 Simulator

### tvos run_ui_snapshots_tests_appletv_18_5

```sh
[bundle exec] fastlane tvos run_ui_snapshots_tests_appletv_18_5
```

Run UI Snapshot Tests on an tvOS 18.5 Simulator

### tvos make_app_store_snapshots_appletv_26_4

```sh
[bundle exec] fastlane tvos make_app_store_snapshots_appletv_26_4
```

Re-generate app store snapshots for tvOS 26.4

----


## Mac

### mac build_dev

```sh
[bundle exec] fastlane mac build_dev
```



### mac make_testflight_release

```sh
[bundle exec] fastlane mac make_testflight_release
```



### mac upload_appstore_metadata

```sh
[bundle exec] fastlane mac upload_appstore_metadata
```

Upload metadata to the Distribution page on App Store Connect

### mac upload_appstore_screenshots

```sh
[bundle exec] fastlane mac upload_appstore_screenshots
```

Upload screenshots to the Distribution page on App Store Connect

### mac run_unit_tests

```sh
[bundle exec] fastlane mac run_unit_tests
```

Run unit tests on a host macOS machine

### mac run_ui_snapshots_tests_macos

```sh
[bundle exec] fastlane mac run_ui_snapshots_tests_macos
```

Run UI Snapshot Tests on a host macOS machine

### mac make_app_store_snapshots_macos

```sh
[bundle exec] fastlane mac make_app_store_snapshots_macos
```

Re-generate app store snapshots for a host macOS machine

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
