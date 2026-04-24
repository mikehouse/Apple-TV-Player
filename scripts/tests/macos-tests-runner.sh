#!/usr/bin/env zsh
set -euo pipefail

usage() {
  echo "Usage: $0 <scheme> <testplan-name> <testplan-repo-path> <destination-platform> <label> <local-port> [language]" >&2
}

if [[ "$#" -ne 6 && "$#" -ne 7 ]]; then
  usage
  exit 1
fi

SCHEME="$1"
TESTPLAN_NAME="$2"
TESTPLAN_REPO_PATH="$3"
DESTINATION_PLATFORM="$4"
LABEL="$5"
LOCAL_PORT="$6"
CUSTOM_LANGUAGE="${7:-}"

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h:h}"
PROJECT_PATH="$PROJECT_DIR/AppleTVMultiplatform.xcodeproj"
TESTPLAN_PATH="${PROJECT_DIR}/${TESTPLAN_REPO_PATH}"
PROJECT_NAME="${PROJECT_PATH:t:r}"

DEFAULT_LANGUAGES=(
  ar
  de
  es
  es-419
  fr
  hi
  id
  it
  ja
  ko
  pt-BR
  ru
  th
  tr
  vi
  zh-Hans
  en
)

ALLOWED_KEYBOARD_LAYOUT_IDS=(
  com.apple.keylayout.ABC
  com.apple.keylayout.USExtended
  com.apple.keylayout.ABC-India
  com.apple.keylayout.Australian
  com.apple.keylayout.British
  com.apple.keylayout.British-PC
  com.apple.keylayout.Canadian
  com.apple.keylayout.Irish
  com.apple.keylayout.NewZealand
  com.apple.keylayout.US
  com.apple.keylayout.USInternational-PC
)

LANGUAGES=()

XCODEBUILD_ARGS=()

FAILED=0

die() {
  echo "Error: $*" >&2
  exit 1
}

require_tool() {
  local tool_name="$1"

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    die "required tool is missing: $tool_name"
  fi
}

require_project() {
  if [[ ! -d "$PROJECT_PATH" ]]; then
    die "project not found: $PROJECT_PATH"
  fi
}

require_testplan() {
  if [[ ! -f "$TESTPLAN_PATH" ]]; then
    die "test plan not found: $TESTPLAN_PATH"
  fi
}

initialize_build_args() {

  XCODEBUILD_ARGS=(
    -project "$PROJECT_PATH"
    -scheme "$SCHEME"
    -testPlan "$TESTPLAN_NAME"
    -skipPackageUpdates
    -disableAutomaticPackageResolution
  )
}

initialize_languages() {
  if [[ -n "$CUSTOM_LANGUAGE" ]]; then
    LANGUAGES=("$CUSTOM_LANGUAGE")
  else
    LANGUAGES=("${DEFAULT_LANGUAGES[@]}")
  fi
}

require_destination_platform() {
  local destination_platform="$1"

  if [[ "$destination_platform" != "macOS" ]]; then
    die "unsupported destination platform for the macOS runner: $destination_platform"
  fi
}

require_local_port() {
  local local_port="$1"

  if ! [[ "$local_port" == <-> ]]; then
    die "LOCAL_PORT must be a number: $local_port"
  fi

  if (( local_port < 1 || local_port > 65535 )); then
    die "LOCAL_PORT must be between 1 and 65535: $local_port"
  fi
}

require_supported_keyboard_layout() {
  local current_keyboard_layout_id
  local allowed_keyboard_layout_id

  current_keyboard_layout_id="$(defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID 2>/dev/null || true)"

  if [[ -z "$current_keyboard_layout_id" ]]; then
    die "unable to determine the current macOS keyboard layout via defaults"
  fi

  for allowed_keyboard_layout_id in "${ALLOWED_KEYBOARD_LAYOUT_IDS[@]}"; do
    if [[ "$current_keyboard_layout_id" == "$allowed_keyboard_layout_id" ]]; then
      return
    fi
  done

  {
    echo "Error: unsupported macOS keyboard layout: $current_keyboard_layout_id"
    echo "Switch the system keyboard layout to one of:"
    printf '  %s\n' "${ALLOWED_KEYBOARD_LAYOUT_IDS[@]}"
  } >&2
  exit 1
}

reset_testplan() {
  git -C "$PROJECT_DIR" checkout -- "$TESTPLAN_REPO_PATH"
}

cleanup() {
  local exit_code=$?

  reset_testplan || true

  return "$exit_code"
}

configure_testplan() {
  local language="$1"
  local local_port="$2"
  local temp_path
  local temp_name_prefix

  temp_name_prefix="${TESTPLAN_NAME//\//_}.configured"
  temp_path="$(mktemp -t "${temp_name_prefix}.XXXXXX")"

  jq \
    --arg language "$language" \
    --arg local_port "$local_port" \
    '
      .defaultOptions.language = $language
      | .defaultOptions.environmentVariableEntries =
          (
            (.defaultOptions.environmentVariableEntries // []) as $entries
            | if any($entries[]?; .key == "LOCAL_PORT") then
                [ $entries[] | if .key == "LOCAL_PORT" then .value = $local_port else . end ]
              else
                $entries + [{ "key": "LOCAL_PORT", "value": $local_port }]
              end
          )
    ' \
    "$TESTPLAN_PATH" > "$temp_path"

  mv "$temp_path" "$TESTPLAN_PATH"
}

run_tests() {
  local language

  for language in "${LANGUAGES[@]}"; do
    echo "Configuring test plan for $LABEL language $language..."
    configure_testplan "$language" "$LOCAL_PORT"

    echo "Running UI tests on $LABEL for language $language..."
    if ! xcodebuild test \
      "${XCODEBUILD_ARGS[@]}" \
      -destination "platform=$DESTINATION_PLATFORM" \
      | xcbeautify
    then
      echo "Error: UI tests failed on $LABEL for language $language" >&2
      FAILED=1
    fi
  done
}

require_tool jq
require_tool git
require_tool xcrun
require_tool xcbeautify
require_tool defaults
require_project
require_testplan
require_destination_platform "$DESTINATION_PLATFORM"
require_local_port "$LOCAL_PORT"
require_supported_keyboard_layout
initialize_build_args
initialize_languages
trap cleanup EXIT

echo "Using project: $PROJECT_PATH"
echo "Using test plan: $TESTPLAN_PATH"
echo "Using keyboard layout: $(defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID)"

run_tests

echo "exit with code=$FAILED"
exit "$FAILED"
