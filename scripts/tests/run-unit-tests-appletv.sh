#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

"$SCRIPT_DIR/simulator-tests-runner.sh" \
  "AppleTVMultiplatformTests" \
  "AppleTVMultiplatformTests" \
  "AppleTVMultiplatformTests/AppleTVMultiplatformTests.xctestplan" \
  "com.apple.CoreSimulator.SimRuntime.tvOS-26-4" \
  "tvOS 26.4" \
  "com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-3rd-generation-4K" \
  "tvOS Simulator" \
  "Tests-Apple-TV-4K-3rd-Gen" \
  "Apple TV" \
  "$LOCAL_PORT" \
  "en"
