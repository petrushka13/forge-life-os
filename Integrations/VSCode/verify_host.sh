#!/bin/bash
set -euo pipefail
extension_root="$(cd "$(dirname "$0")" && pwd)"
host_fixture="$(mktemp -d "${TMPDIR:-/tmp}/forge-vscode-host.XXXXXX")"
mkdir -p "$host_fixture/workspace" "$host_fixture/user" "$host_fixture/extensions"
export FORGE_HOST_RESULT="$host_fixture/result.json"
code --wait --user-data-dir "$host_fixture/user" --extensions-dir "$host_fixture/extensions" \
  --extensionDevelopmentPath="$extension_root" --extensionTestsPath="$extension_root/host-test" \
  --skip-welcome --skip-release-notes --disable-workspace-trust "$host_fixture/workspace"

if [[ ! -f "$FORGE_HOST_RESULT" ]]; then echo "Extension Host did not produce verification evidence." >&2; exit 1; fi
cat "$FORGE_HOST_RESULT"
