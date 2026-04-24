#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

exec "$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformUITests" \
  "RegularSnapshotUITests-iPad" \
  "AppleTVMultiplatformUITests/SnapshotUITests/Regular/RegularSnapshotUITests-iPad.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.iOS-18-6" \
  "iOS 18.6" \
  "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-8GB" \
  "iOS Simulator" \
  "UITests-iPad-Pro-13-inch-M4" \
  "iPad" \
  "$LOCAL_PORT" \
  "en"
