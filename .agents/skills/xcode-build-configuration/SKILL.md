
# Xcode Build Configuration

## Overview
Standards and requirements for building and testing Xcode projects in this repository.

## Rules

**Important**: Must use Xcode's default derived data location when building and testing.

**Important**: Build and test project only for macOS SDK.

**Important**: For `xcodebuild` commands (`build`, `test`, `clean`, `archive`) MUST pipe output through `xcbeautify`:

**Rationale**: `xcbeautify` significantly improves readability of Xcode build output.

## Examples

## Build for macOS

```bash
xcodebuild -scheme MyApp -destination 'platform=macOS' build | xcbeautify
```

## Test for macOS

```bash
xcodebuild -scheme MyApp -destination 'platform=macOS' test | xcbeautify
```
