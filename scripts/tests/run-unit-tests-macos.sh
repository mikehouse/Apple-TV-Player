#!/usr/bin/env zsh

SCRIPT_DIR="${0:A:h}"
LOCAL_PORT="${LOCAL_PORT:-8000}"

"$SCRIPT_DIR/macos-tests-runner.sh" \
  "AppleTVMultiplatformTests" \
  "AppleTVMultiplatformTests" \
  "AppleTVMultiplatformTests/AppleTVMultiplatformTests.xctestplan" \
  "macOS" \
  "macOS" \
  "$LOCAL_PORT" \
  "en"
