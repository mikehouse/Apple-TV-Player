#!/usr/bin/env zsh
set -euo pipefail

usage() {
  echo "Usage: $0 <scheme> <testplan-name> <testplan-repo-path> <runtime-id> <runtime-name> <device-type> <destination-platform> <sim-name> <label> <local-port> [language]" >&2
}

if [[ "$#" -ne 10 && "$#" -ne 11 ]]; then
  usage
  exit 1
fi

SCHEME="$1"
TESTPLAN_NAME="$2"
TESTPLAN_REPO_PATH="$3"
RUNTIME_ID="$4"
RUNTIME_NAME="$5"
DEVICE_TYPE="$6"
DESTINATION_PLATFORM="$7"
SIM_NAME="$8"
LABEL="$9"
LOCAL_PORT="${10}"
CUSTOM_LANGUAGE="${11:-}"

SCREENSHOT_TIME="${SCREENSHOT_TIME:-9:41}"

PROJECT_DIR="$(pwd)"
PROJECT_PATH="$PROJECT_DIR/AppleTVMultiplatform.xcodeproj"
TESTPLAN_PATH="${PROJECT_DIR}/${TESTPLAN_REPO_PATH}"
PROJECT_NAME="${PROJECT_PATH:t:r}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-${HOME}/Library/Developer/Xcode/DerivedData}"

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

LANGUAGES=()

CURRENT_PROJECT_DERIVED_DATA="${CURRENT_PROJECT_DERIVED_DATA:-}"
TESTPLAN_DERIVED_DATA=""
XCODEBUILD_ARGS=()

CURRENT_UDID=""
CURRENT_SIM_STATE=""
SHOULD_SHUTDOWN_CURRENT_SIM=0
FAILED=0

require_tool() {
  local tool_name="$1"

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "Error: required tool is missing: $tool_name" >&2
    exit 1
  fi
}

require_project() {
  if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "Error: project not found: $PROJECT_PATH" >&2
    echo "Current directory: $PWD" >&2
    echo "Expected the project to exist two levels above the current directory." >&2
    exit 1
  fi
}

require_testplan() {
  if [[ ! -f "$TESTPLAN_PATH" ]]; then
    echo "Error: test plan not found: $TESTPLAN_PATH" >&2
    exit 1
  fi
}

resolve_current_project_derived_data() {
  local matches

  matches=("${DERIVED_DATA_ROOT}/${PROJECT_NAME}-"*(N/Om))

  if (( ${#matches[@]} > 0 )); then
    echo "${matches[1]}"
    return
  fi

  echo "${DERIVED_DATA_ROOT}/${PROJECT_NAME}"
}

initialize_derived_data_path() {
  CURRENT_PROJECT_DERIVED_DATA="${CURRENT_PROJECT_DERIVED_DATA:-$(resolve_current_project_derived_data)}"
  # Use custom derived data per test plan because tests may run in parallel and one build dir does not support it.
  TESTPLAN_DERIVED_DATA="${CURRENT_PROJECT_DERIVED_DATA}/${TESTPLAN_NAME}"

  mkdir -p "$TESTPLAN_DERIVED_DATA"

  XCODEBUILD_ARGS=(
    -project "$PROJECT_PATH"
    -scheme "$SCHEME"
    -testPlan "$TESTPLAN_NAME"
    -derivedDataPath "$TESTPLAN_DERIVED_DATA"
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

require_runtime() {
  local runtime_id="$1"
  local runtime_name="$2"

  if ! xcrun simctl list --json runtimes | jq -e --arg runtime "$runtime_id" '
    any(.runtimes[]; .identifier == $runtime and .isAvailable)
  ' >/dev/null; then
    echo "Error: required simulator runtime is not installed: $runtime_name ($runtime_id)" >&2
    echo "Please install/download this runtime in Xcode and rerun." >&2
    exit 1
  fi
}

set_fixed_screenshot_time() {
  local udid="$1"

  if [[ "$DESTINATION_PLATFORM" == "iOS Simulator" ]]; then
    xcrun simctl status_bar "$udid" override --time "$SCREENSHOT_TIME"
  fi
}

clear_fixed_screenshot_time() {
  local udid="$1"

  if [[ -n "${udid:-}" ]]; then
    xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
  fi
}

find_existing_simulator() {
  xcrun simctl list devices --json | jq -r \
    --arg runtime_id "$RUNTIME_ID" \
    --arg sim_name "$SIM_NAME" \
    --arg device_type "$DEVICE_TYPE" \
    '
      first(
        (.devices[$runtime_id] // [])[]
        | select(.isAvailable and .name == $sim_name and .deviceTypeIdentifier == $device_type)
        | "\(.udid)\t\(.state)"
      ) // empty
    '
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

cleanup_current_sim() {
  if [[ -z "${CURRENT_UDID:-}" ]]; then
    return
  fi

  clear_fixed_screenshot_time "$CURRENT_UDID"

  if (( SHOULD_SHUTDOWN_CURRENT_SIM )); then
    echo "Shutting down $LABEL simulator..."
    xcrun simctl shutdown "$CURRENT_UDID" >/dev/null 2>&1 || true
  else
    echo "Keeping $LABEL simulator booted: $CURRENT_UDID"
  fi

  CURRENT_UDID=""
  CURRENT_SIM_STATE=""
  SHOULD_SHUTDOWN_CURRENT_SIM=0
}

reset_testplan() {
  git -C "$PROJECT_DIR" checkout -- "$TESTPLAN_REPO_PATH"
}

run_tests_on_simulator() {
  local language
  local existing_simulator

  existing_simulator="$(find_existing_simulator)"

  if [[ -n "$existing_simulator" ]]; then
    CURRENT_UDID="${existing_simulator%%$'\t'*}"
    CURRENT_SIM_STATE="${existing_simulator#*$'\t'}"
    echo "Reusing $LABEL simulator: $CURRENT_UDID"
  else
    echo "Creating $LABEL simulator..."
    CURRENT_UDID="$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE" "$RUNTIME_ID")"
    CURRENT_SIM_STATE="Shutdown"
  fi

  if [[ "$CURRENT_SIM_STATE" != "Booted" ]]; then
    SHOULD_SHUTDOWN_CURRENT_SIM=1
    echo "Booting $LABEL simulator..."
    xcrun simctl boot "$CURRENT_UDID"
  else
    SHOULD_SHUTDOWN_CURRENT_SIM=0
    echo "$LABEL simulator already booted: $CURRENT_UDID"
  fi

  xcrun simctl bootstatus "$CURRENT_UDID" -b
  set_fixed_screenshot_time "$CURRENT_UDID"

  for language in "${LANGUAGES[@]}"; do
    echo "Configuring test plan for $LABEL language $language..."
    configure_testplan "$language" "$LOCAL_PORT"

    echo "Running UI tests on $LABEL for language $language..."
    if ! xcodebuild test \
      "${XCODEBUILD_ARGS[@]}" \
      -destination "platform=$DESTINATION_PLATFORM,id=$CURRENT_UDID" \
      | xcbeautify
    then
      echo "Error: UI tests failed on $LABEL for language $language" >&2
      FAILED=1
    fi
  done

  cleanup_current_sim
  reset_testplan
}

require_tool jq
require_tool xcrun
require_tool git
require_tool xcbeautify
require_project
require_testplan
initialize_derived_data_path
initialize_languages

echo "Using project: $PROJECT_PATH"
echo "Using test plan: $TESTPLAN_PATH"
echo "Using derived data: $TESTPLAN_DERIVED_DATA"

echo "Checking $RUNTIME_NAME runtime..."
require_runtime "$RUNTIME_ID" "$RUNTIME_NAME"

run_tests_on_simulator

echo "exit with code=$FAILED"
exit "$FAILED"
