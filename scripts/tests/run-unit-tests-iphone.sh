#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

"$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformTests" \
  "AppleTVMultiplatformTests" \
  "AppleTVMultiplatformTests/AppleTVMultiplatformTests.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.iOS-26-4" \
  "iOS 26.4" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max" \
  "iOS Simulator" \
  "Tests-iPhone-17-Pro-Max" \
  "iPhone" \
  "$LOCAL_PORT" \
  "en"
