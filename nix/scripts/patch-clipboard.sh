#!/bin/sh
set -e

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "usage: patch-clipboard.sh <openclaw-root> <wrapper>" >&2
  exit 1
fi

root="$1"
wrapper="$2"

if [ ! -f "$wrapper" ]; then
  echo "clipboard wrapper not found: $wrapper" >&2
  exit 1
fi

if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

node_modules="$root/node_modules"
if [ ! -d "$node_modules/.pnpm" ]; then
  echo "node_modules missing: $node_modules" >&2
  exit 0
fi

targets=$(find "$node_modules/.pnpm" -path "*/node_modules/@mariozechner/clipboard/index.js" -print)
if [ -z "$targets" ]; then
  echo "clipboard package not found; skipping" >&2
  exit 0
fi

for target in $targets; do
  dir=$(dirname "$target")
  if [ ! -f "$dir/index.original.js" ]; then
    chmod u+w "$dir/index.js" 2>/dev/null || true
    mv "$dir/index.js" "$dir/index.original.js"
  fi
  chmod u+w "$dir/index.original.js" 2>/dev/null || true
  cp "$wrapper" "$dir/index.js"
done
