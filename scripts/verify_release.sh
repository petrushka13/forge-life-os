#!/bin/bash
set -euo pipefail
forge_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$forge_root"
forge_verify_dir="${FORGE_VERIFY_DIR:-${TMPDIR:-/tmp}/forge-release-verification}"
forge_node="${FORGE_NODE:-$(command -v node || true)}"
if [[ -z "$forge_node" ]]; then
  forge_node="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
fi
if [[ ! -x "$forge_node" ]]; then echo 'Install Node.js 20+ or set FORGE_NODE to its executable.' >&2; exit 1; fi
mkdir -p "$forge_verify_dir"
git diff --check
python3 scripts/generate_project.py --check
python3 scripts/check_release.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v scripts.test_signing_configuration scripts.test_public_snapshot
swift test --scratch-path "$forge_verify_dir/swift"
swift run --scratch-path "$forge_verify_dir/swift" ForgeDesktop --smoke-test
swift build --scratch-path "$forge_verify_dir/swift" --product ForgeIntegrationCheck
forge_bin_dir="$(swift build --scratch-path "$forge_verify_dir/swift" --show-bin-path)"
python3 server/verify_client.py --client "$forge_bin_dir/ForgeIntegrationCheck"
python3 -m unittest discover -s server -v
"$forge_node" --test Integrations/VSCode/activity.test.js
xcodebuild -quiet -project FORGE.xcodeproj -scheme FORGE -destination 'platform=macOS,arch=arm64' -derivedDataPath "$forge_verify_dir/mac" CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
xcodebuild -quiet -project FORGE.xcodeproj -scheme FORGE -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$forge_verify_dir/ios" CODE_SIGNING_ALLOWED=NO build
if [[ -n "${FORGE_UI_SIMULATOR_UDID:-}" ]]; then
  xcodebuild -quiet -project FORGE.xcodeproj -scheme FORGE -destination "platform=iOS Simulator,id=$FORGE_UI_SIMULATOR_UDID" -derivedDataPath "$forge_verify_dir/ios" -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 CODE_SIGNING_ALLOWED=NO test
fi
if [[ "${FORGE_UI_MAC:-0}" == 1 ]]; then
  FORGE_MAC_UI_DIR="$forge_verify_dir/mac-ui" bash scripts/verify_mac_ui.sh
fi
echo 'FORGE local release verification passed. Account/device gates are documented separately.'
