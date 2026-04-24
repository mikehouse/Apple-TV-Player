#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

exec "$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformUITests" \
  "AppStoreSnapshotUITests-iPhone" \
  "AppleTVMultiplatformUITests/SnapshotUITests/App-Store/AppStoreSnapshotUITests-iPhone.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.iOS-26-4" \
  "iOS 26.4" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max" \
  "iOS Simulator" \
  "UITests-iPhone-17-Pro-Max" \
  "iPhone" \
  "$LOCAL_PORT"
