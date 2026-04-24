#!/usr/bin/env zsh

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

# If app is not run in foreground (stays in Dock after launch) then you need to cache it state via call (once):
# `open -a ${DERIVED_DATA}/Build/Products/Debug/Bro Player.app`
# This somehow will cache/reset app state and after that it should work correctly.

DERIVED_DATA=$(xcodebuild -project AppleTVMultiplatform.xcodeproj -scheme AppleTVMultiplatform -showBuildSettings | sed -n 's/.*OBJROOT = \(.*\)\/Build\/Intermediates.noindex/\1/p')
APP_PATH="${DERIVED_DATA}/Build/Products/Debug/Bro Player.app"

if [[ -d "$APP_PATH" ]]; then
  open "${APP_PATH}"
  sleep 3
  osascript -e 'quit app "Bro Player"'
fi

"$SCRIPT_DIR/macos-tests-runner.sh" \
  "AppleTVMultiplatformUITests" \
  "AppStoreSnapshotUITests-macOS" \
  "AppleTVMultiplatformUITests/SnapshotUITests/App-Store/AppStoreSnapshotUITests-macOS.xctestplan" \
  "macOS" \
  "macOS" \
  "$LOCAL_PORT"
