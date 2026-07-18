#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_PATH="${REPO_ROOT}/CaptionTheater/CaptionTheater.xcodeproj"
DERIVED_DATA_PATH="${REPO_ROOT}/Build/DerivedData"
SCREENSHOT_DIR="${REPO_ROOT}/Screenshots/MacQA"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/CaptionTheaterMac.app"
EXECUTABLE_PATH="${APP_PATH}/Contents/MacOS/CaptionTheaterMac"
APP_LOG_PATH="${SCREENSHOT_DIR}/caption-theater-mac-app.log"
SCREENSHOT_PATH="${SCREENSHOT_DIR}/caption-theater-mac-ultrawide.png"

mkdir -p "${SCREENSHOT_DIR}"

cleanup() {
  if [[ -n "${APP_PID:-}" ]]; then
    kill "${APP_PID}" 2>/dev/null || true
  fi
  pkill -x CaptionTheaterMac 2>/dev/null || true
}

trap cleanup EXIT

xcodebuild build \
  -project "${PROJECT_PATH}" \
  -scheme CaptionTheaterMac \
  -destination "generic/platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_PATH}"

"${EXECUTABLE_PATH}" \
  --caption-theater-offline-hls \
  --caption-theater-playback-debug-hud=yes \
  --caption-theater-playback-layout-border=yes \
  --caption-theater-mac-startup-aspect=twentyOneByNine \
  >"${APP_LOG_PATH}" 2>&1 &

APP_PID=$!

sleep 4

if ! osascript <<'APPLESCRIPT'
tell application "CaptionTheaterMac" to activate
tell application "System Events"
  tell process "CaptionTheaterMac"
    set frontmost to true
    set position of window 1 to {80, 80}
    set size of window 1 to {1680, 720}
  end tell
end tell
APPLESCRIPT
then
  echo "Warning: could not size the window with System Events; continuing with the current window size." >&2
fi

sleep 2

if screencapture -x "${SCREENSHOT_PATH}"; then
  echo "Saved ${SCREENSHOT_PATH}"
else
  echo "Warning: screencapture failed; check Screen Recording permission for the invoking terminal." >&2
fi
