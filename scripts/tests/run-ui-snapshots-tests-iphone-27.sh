#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

exec "$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformUITests" \
  "RegularSnapshotUITests-iPhone" \
  "AppleTVMultiplatformUITests/SnapshotUITests/Regular/RegularSnapshotUITests-iPhone.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.iOS-27-0" \
  "iOS 27.0" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max" \
  "iOS Simulator" \
  "UITests-iPhone-18-Pro-Max" \
  "iPhone" \
  "$LOCAL_PORT" \
  "en"
