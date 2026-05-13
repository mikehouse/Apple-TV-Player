#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

exec "$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformUITests" \
  "RegularSnapshotUITests-iPhone" \
  "AppleTVMultiplatformUITests/SnapshotUITests/Regular/RegularSnapshotUITests-iPhone.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.iOS-18-6" \
  "iOS 18.6" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max" \
  "iOS Simulator" \
  "UITests-iPhone-16-Pro-Max" \
  "iPhone" \
  "$LOCAL_PORT" \
  "en"
