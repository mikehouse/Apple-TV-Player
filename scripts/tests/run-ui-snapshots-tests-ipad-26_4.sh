#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

exec "$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformUITests" \
  "RegularSnapshotUITests-iPad" \
  "AppleTVMultiplatformUITests/SnapshotUITests/Regular/RegularSnapshotUITests-iPad.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.iOS-26-4" \
  "iOS 26.4" \
  "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB" \
  "iOS Simulator" \
  "UITests-iPad-Pro-13-inch-M5" \
  "iPad" \
  "$LOCAL_PORT" \
  "en"
