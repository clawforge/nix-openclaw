#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir="$repo_root/nix/tests/hm-activation-macos"
home_dir="/tmp/hm-activation-home"

rm -rf "$home_dir"
mkdir -p "$home_dir"

export HOME="$home_dir"
export USER="${USER:-runner}"
export LOGNAME="$USER"

cd "$test_dir"

nix build --accept-flake-config --impure \
  --override-input nix-openclaw "path:$repo_root" \
  .#homeConfigurations.hm-test.activationPackage

./result/activate

test -f "$HOME/.openclaw/openclaw.json"

if command -v launchctl >/dev/null 2>&1; then
  launchctl print "gui/$UID/com.steipete.openclaw.gateway" >/dev/null 2>&1
fi
