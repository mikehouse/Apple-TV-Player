#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

exec "$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformUITests" \
  "RegularSnapshotUITests-AppleTV" \
  "AppleTVMultiplatformUITests/SnapshotUITests/Regular/RegularSnapshotUITests-AppleTV.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.tvOS-18-5" \
  "tvOS 18.5" \
  "com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-3rd-generation-4K" \
  "tvOS Simulator" \
  "UITests-Apple-TV-4K-3rd-Gen" \
  "Apple TV" \
  "$LOCAL_PORT" \
  "en"
