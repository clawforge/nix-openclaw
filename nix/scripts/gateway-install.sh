#!/bin/sh
set -e
mkdir -p "$out/lib/openclaw" "$out/bin"

cp -r dist node_modules package.json ui "$out/lib/openclaw/"
if [ -d extensions ]; then
  cp -r extensions "$out/lib/openclaw/"

  # Link extension production dependencies from the pnpm store.
  # pnpm hoists all deps into node_modules/.pnpm/ but doesn't populate
  # each extension's own node_modules/, so we resolve them here.
  pnpm_store="$out/lib/openclaw/node_modules/.pnpm"
  for ext_dir in "$out/lib/openclaw/extensions"/*/; do
    ext_pkg="$ext_dir/package.json"
    [ -f "$ext_pkg" ] || continue

    # Extract production dependency names from the extension's package.json
    deps="$(jq -r '.dependencies // {} | keys[]' "$ext_pkg" 2>/dev/null)" || continue
    [ -z "$deps" ] && continue

    mkdir -p "$ext_dir/node_modules"
    for dep in $deps; do
      # Skip if already present
      [ -e "$ext_dir/node_modules/$dep" ] && continue

      # Find the dependency in the pnpm store
      # Handle scoped packages: @scope/name -> @scope+name in .pnpm dir
      dep_escaped="$(echo "$dep" | sed 's|/|+|g')"
      dep_pnpm_dir="$(find "$pnpm_store" -maxdepth 1 -name "${dep_escaped}@*" -print | head -n 1)"

      if [ -n "$dep_pnpm_dir" ]; then
        # For scoped packages, the actual module is nested: node_modules/@scope/name
        dep_module="$dep_pnpm_dir/node_modules/$dep"
        if [ -d "$dep_module" ]; then
          # Handle scoped package directories
          if echo "$dep" | grep -q '/'; then
            scope="$(echo "$dep" | cut -d/ -f1)"
            mkdir -p "$ext_dir/node_modules/$scope"
          fi
          ln -s "$dep_module" "$ext_dir/node_modules/$dep"
        fi
      fi
    done
  done
fi

# Copy docs (workspace templates like AGENTS.md, SOUL.md, TOOLS.md)
if [ -d "docs" ]; then
  cp -r docs "$out/lib/openclaw/"
fi

if [ -z "${STDENV_SETUP:-}" ]; then
  echo "STDENV_SETUP is not set" >&2
  exit 1
fi
if [ ! -f "$STDENV_SETUP" ]; then
  echo "STDENV_SETUP not found: $STDENV_SETUP" >&2
  exit 1
fi

bash -e -c '. "$STDENV_SETUP"; patchShebangs "$out/lib/openclaw/node_modules/.bin"'
if [ -d "$out/lib/openclaw/ui/node_modules/.bin" ]; then
  bash -e -c '. "$STDENV_SETUP"; patchShebangs "$out/lib/openclaw/ui/node_modules/.bin"'
fi

# Work around missing dependency declaration in pi-coding-agent (strip-ansi).
# Ensure it is resolvable at runtime without changing upstream.
pi_pkg="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/node_modules/@mariozechner/pi-coding-agent" -print | head -n 1)"
strip_ansi_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/node_modules/strip-ansi" -print | head -n 1)"

if [ -n "$strip_ansi_src" ]; then
  if [ -n "$pi_pkg" ] && [ ! -e "$pi_pkg/node_modules/strip-ansi" ]; then
    mkdir -p "$pi_pkg/node_modules"
    ln -s "$strip_ansi_src" "$pi_pkg/node_modules/strip-ansi"
  fi

  if [ ! -e "$out/lib/openclaw/node_modules/strip-ansi" ]; then
    mkdir -p "$out/lib/openclaw/node_modules"
    ln -s "$strip_ansi_src" "$out/lib/openclaw/node_modules/strip-ansi"
  fi
fi
bash -e -c '. "$STDENV_SETUP"; makeWrapper "$NODE_BIN" "$out/bin/openclaw" --add-flags "$out/lib/openclaw/dist/index.js" --set-default MOLTBOT_NIX_MODE "1" --set-default CLAWDBOT_NIX_MODE "1" --set-default CLAWDBOT_BUNDLED_PLUGINS_DIR "$out/lib/openclaw/extensions"'
ln -s "$out/bin/openclaw" "$out/bin/moltbot"
