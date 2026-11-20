#!/bin/bash
# Local XCTest signing and isolated native workflows. Never changes Gatekeeper/TCC policy.
set -euo pipefail
forge_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$forge_root"
forge_mac_ui_dir="${FORGE_MAC_UI_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/forge-mac-ui.XXXXXX")}"
mkdir -p "$forge_mac_ui_dir"
if [[ -e "$forge_mac_ui_dir/acceptance.xcresult" ]]; then
  echo 'Choose a fresh FORGE_MAC_UI_DIR; existing test evidence is preserved.' >&2
  exit 1
fi
forge_mac_arguments=(-project FORGE.xcodeproj -scheme FORGE -configuration Debug
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$forge_mac_ui_dir/build"
  "FORGE_APP_BUNDLE_ID=com.personal.FORGE.MacUIFixture.$(uuidgen)"
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
echo "Building Xcode-signed local runner; evidence: $forge_mac_ui_dir"
if ! xcodebuild "${forge_mac_arguments[@]}" build-for-testing > "$forge_mac_ui_dir/build.log" 2>&1; then
  echo "Build failed; inspect $forge_mac_ui_dir/build.log" >&2
  exit 1
fi
forge_mac_products="$forge_mac_ui_dir/build/Build/Products/Debug"
# --deep is for verification only. Xcode signs nested code first, then the outer runner.
codesign --verify --deep --strict --verbose=2 "$forge_mac_products/FORGEUITests-Runner.app"
codesign --verify --deep --strict --verbose=2 "$forge_mac_products/FORGE.app"
echo 'Running three native acceptance workflows with synthetic data.'
if ! xcodebuild "${forge_mac_arguments[@]}" -resultBundlePath "$forge_mac_ui_dir/acceptance.xcresult" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 120 -collect-test-diagnostics never \
  -skip-testing:FORGEUITests/ForgeUITests/testNativeEditorDiagnosticControl \
  test-without-building > "$forge_mac_ui_dir/test.log" 2>&1; then
  echo "Mac UI acceptance FAILED; inspect $forge_mac_ui_dir/test.log and acceptance.xcresult" >&2
  exit 1
fi
xcrun xcresulttool get test-results summary --path "$forge_mac_ui_dir/acceptance.xcresult" > "$forge_mac_ui_dir/summary.json"
python3 - "$forge_mac_ui_dir/summary.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as source:
    result = json.load(source)
if result.get('result') != 'Passed' or result.get('passedTests') != 3 or result.get('failedTests') != 0 or result.get('skippedTests') != 0:
    raise SystemExit('Expected three executed, passing Mac UI workflows; inspect summary.json')
print('FORGE Mac UI acceptance passed: 3 executed, 0 failed, 0 skipped.')
PY
