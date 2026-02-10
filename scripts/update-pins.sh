#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$repo_root/nix/sources/openclaw-source.nix"
app_file="$repo_root/nix/packages/openclaw-app.nix"
gateway_file="$repo_root/nix/packages/openclaw-gateway.nix"
generated_config_file="$repo_root/nix/generated/openclaw-config-options.nix"
flake_lock_file="$repo_root/flake.lock"
tmp_src=""
backup_dir=$(mktemp -d)

cp "$source_file" "$backup_dir/openclaw-source.nix"
cp "$app_file" "$backup_dir/openclaw-app.nix"
cp "$gateway_file" "$backup_dir/openclaw-gateway.nix"
cp "$generated_config_file" "$backup_dir/openclaw-config-options.nix"
cp "$flake_lock_file" "$backup_dir/flake.lock"

restore_from_backup() {
  cp "$backup_dir/openclaw-source.nix" "$source_file"
  cp "$backup_dir/openclaw-app.nix" "$app_file"
  cp "$backup_dir/openclaw-gateway.nix" "$gateway_file"
  cp "$backup_dir/openclaw-config-options.nix" "$generated_config_file"
  cp "$backup_dir/flake.lock" "$flake_lock_file"
}

cleanup() {
  if [[ -n "$tmp_src" ]]; then
    rm -rf "$tmp_src"
  fi
  rm -rf "$backup_dir"
}
trap cleanup EXIT

log() {
  printf '>> %s\n' "$*"
}

gc_between_candidates="${UPDATE_PINS_GC_BETWEEN_CANDIDATES:-}"
if [[ -z "$gc_between_candidates" ]]; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    gc_between_candidates="1"
  else
    gc_between_candidates="0"
  fi
fi

gc_nix_store() {
  if [[ "$gc_between_candidates" != "1" ]]; then
    return
  fi
  log "Running nix store gc to reclaim disk"
  nix store gc >/dev/null 2>&1 || true
}

add_candidate_sha() {
  local sha="$1"
  local existing
  if [[ -z "$sha" ]]; then
    return
  fi
  for existing in "${candidate_shas[@]:-}"; do
    if [[ "$existing" == "$sha" ]]; then
      return
    fi
  done
  candidate_shas+=("$sha")
}

upstream_checks_green() {
  local sha="$1"
  local checks_json
  checks_json=$(gh api "/repos/openclaw/openclaw/commits/${sha}/check-runs?per_page=100" 2>/dev/null || true)
  if [[ -z "$checks_json" ]]; then
    log "No check runs found for $sha"
    return 1
  fi

  local relevant_count
  relevant_count=$(printf '%s' "$checks_json" | jq '[.check_runs[] | select(.name | test("windows"; "i") | not)] | length')
  if [[ "$relevant_count" -eq 0 ]]; then
    log "No non-windows check runs found for $sha"
    return 1
  fi

  local failing_count
  failing_count=$(
    printf '%s' "$checks_json" | jq '[.check_runs[]
      | select(.name | test("windows"; "i") | not)
      | select(.status != "completed" or (.conclusion != "success" and .conclusion != "skipped"))
    ] | length'
  )
  if [[ "$failing_count" -ne 0 ]]; then
    log "Non-windows checks not green for $sha"
    return 1
  fi

  return 0
}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed." >&2
  exit 1
fi

log "Updating nix-steipete-tools input"
nix flake lock --update-input nix-steipete-tools

log "Fetching latest release metadata"
release_json=$(gh api /repos/openclaw/openclaw/releases?per_page=20 || true)
if [[ -z "$release_json" ]]; then
  echo "Failed to fetch release metadata" >&2
  exit 1
fi
release_tag=$(
  printf '%s' "$release_json" | jq -r \
    '[.[] | select([.assets[]?.name | (test("^(OpenClaw|Clawdbot)-.*\\.zip$") and (test("dSYM"; "i") | not))] | any)][0].tag_name // empty'
)
if [[ -z "$release_tag" ]]; then
  echo "Failed to resolve a release tag with an app zip asset" >&2
  exit 1
fi
log "Latest app release tag with asset: $release_tag"

app_url=$(
  printf '%s' "$release_json" | jq -r \
    '[.[] | select([.assets[]?.name | (test("^(OpenClaw|Clawdbot)-.*\\.zip$") and (test("dSYM"; "i") | not))] | any)][0].assets[] | select(.name | (test("^(OpenClaw|Clawdbot)-.*\\.zip$") and (test("dSYM"; "i") | not))) | .browser_download_url' \
    | head -n 1 || true
)
if [[ -z "$app_url" ]]; then
  echo "Failed to resolve app asset URL from latest release" >&2
  exit 1
fi
log "App asset URL: $app_url"

release_sha=$(gh api "/repos/openclaw/openclaw/commits/${release_tag}" --jq '.sha' 2>/dev/null || true)
if [[ -n "$release_sha" ]]; then
  log "Release tag commit SHA: $release_sha"
fi

main_candidate_count="${UPDATE_PINS_MAIN_CANDIDATES:-10}"
if ! [[ "$main_candidate_count" =~ ^[0-9]+$ ]] || [[ "$main_candidate_count" -lt 1 ]]; then
  main_candidate_count=10
fi

log "Resolving openclaw source candidate SHAs"
candidate_shas=()
add_candidate_sha "$release_sha"
mapfile -t main_candidate_shas < <(gh api "/repos/openclaw/openclaw/commits?per_page=${main_candidate_count}" | jq -r '.[].sha' || true)
for sha in "${main_candidate_shas[@]:-}"; do
  add_candidate_sha "$sha"
done
if [[ ${#candidate_shas[@]} -eq 0 ]]; then
  latest_sha=$(git ls-remote https://github.com/openclaw/openclaw.git refs/heads/main | awk '{print $1}' || true)
  if [[ -z "$latest_sha" ]]; then
    echo "Failed to resolve openclaw main SHA" >&2
    exit 1
  fi
  add_candidate_sha "$latest_sha"
fi

selected_sha=""
selected_hash=""
selected_source_store_path=""
selected_source_url=""

for sha in "${candidate_shas[@]}"; do
  if ! upstream_checks_green "$sha"; then
    continue
  fi
  log "Testing upstream SHA: $sha"
  source_url="https://github.com/openclaw/openclaw/archive/${sha}.tar.gz"
  log "Prefetching source tarball"
  source_prefetch=$(
    nix --extra-experimental-features "nix-command flakes" store prefetch-file --unpack --json "$source_url" 2>"/tmp/nix-prefetch-source.err" \
    || true
  )
  if [[ -z "$source_prefetch" ]]; then
    cat "/tmp/nix-prefetch-source.err" >&2 || true
    rm -f "/tmp/nix-prefetch-source.err"
    echo "Failed to resolve source hash for $sha" >&2
    gc_nix_store
    continue
  fi
  rm -f "/tmp/nix-prefetch-source.err"
  source_hash=$(printf '%s' "$source_prefetch" | jq -r '.hash // empty')
  if [[ -z "$source_hash" ]]; then
    printf '%s\n' "$source_prefetch" >&2
    echo "Failed to parse source hash for $sha" >&2
    gc_nix_store
    continue
  fi
  source_store_path=$(printf '%s' "$source_prefetch" | jq -r '.path // .storePath // empty')
  if [[ -z "$source_store_path" ]]; then
    echo "Failed to parse source store path for $sha" >&2
    gc_nix_store
    continue
  fi
  log "Source hash: $source_hash"

  perl -0pi -e "s|rev = \"[^\"]+\";|rev = \"${sha}\";|" "$source_file"
  perl -0pi -e "s|hash = \"[^\"]+\";|hash = \"${source_hash}\";|" "$source_file"
  # Force a fresh pnpmDepsHash recalculation for the candidate rev.
  perl -0pi -e "s|pnpmDepsHash = \"[^\"]*\";|pnpmDepsHash = \"\";|" "$source_file"

  build_log=$(mktemp)
  log "Building gateway to validate pnpmDepsHash"
  if ! nix build .#openclaw-gateway --accept-flake-config >"$build_log" 2>&1; then
    pnpm_hash=$(grep -Eo 'got: *sha256-[A-Za-z0-9+/=]+' "$build_log" | head -n 1 | sed 's/.*got: *//' || true)
    if [[ -n "$pnpm_hash" ]]; then
      log "pnpmDepsHash mismatch detected: $pnpm_hash"
      perl -0pi -e "s|pnpmDepsHash = \"[^\"]*\";|pnpmDepsHash = \"${pnpm_hash}\";|" "$source_file"
      if ! nix build .#openclaw-gateway --accept-flake-config >"$build_log" 2>&1; then
        if grep -q "No space left on device" "$build_log"; then
          log "Gateway build for $sha failed due to runner disk pressure."
        fi
        tail -n 200 "$build_log" >&2 || true
        rm -f "$build_log"
        gc_nix_store
        continue
      fi
    else
      if grep -q "No space left on device" "$build_log"; then
        log "Gateway build for $sha failed due to runner disk pressure."
      fi
      tail -n 200 "$build_log" >&2 || true
      rm -f "$build_log"
      gc_nix_store
      continue
    fi
  fi
  rm -f "$build_log"
  selected_sha="$sha"
  selected_hash="$source_hash"
  selected_source_store_path="$source_store_path"
  selected_source_url="$source_url"
  break
done

if [[ -z "$selected_sha" ]]; then
  if [[ "${UPDATE_PINS_ALLOW_NO_BUILDABLE:-0}" == "1" ]]; then
    log "No buildable upstream revision found in ${#candidate_shas[@]} candidate SHAs; skipping update."
    restore_from_backup
    exit 0
  fi
  echo "Failed to find a buildable upstream revision in ${#candidate_shas[@]} candidate SHAs." >&2
  exit 1
fi
log "Selected upstream SHA: $selected_sha"

app_prefetch=$(
  nix --extra-experimental-features "nix-command flakes" store prefetch-file --unpack --json "$app_url" 2>"/tmp/nix-prefetch-app.err" \
  || true
)
if [[ -z "$app_prefetch" ]]; then
  cat "/tmp/nix-prefetch-app.err" >&2 || true
  rm -f "/tmp/nix-prefetch-app.err"
  echo "Failed to resolve app hash" >&2
  exit 1
fi
rm -f "/tmp/nix-prefetch-app.err"
app_hash=$(printf '%s' "$app_prefetch" | jq -r '.hash // empty')
if [[ -z "$app_hash" ]]; then
  printf '%s\n' "$app_prefetch" >&2
  echo "Failed to parse app hash" >&2
  exit 1
fi
log "App hash: $app_hash"

app_version="${release_tag#v}"
perl -0pi -e "s|version = \"[^\"]+\";|version = \"${app_version}\";|" "$app_file"
perl -0pi -e "s|url = \"[^\"]+\";|url = \"${app_url}\";|" "$app_file"
perl -0pi -e "s|hash = \"[^\"]+\";|hash = \"${app_hash}\";|" "$app_file"

if [[ -z "$selected_source_store_path" ]]; then
  echo "Missing source path for selected upstream revision" >&2
  exit 1
fi

log "Regenerating openclaw config options from upstream schema"
tmp_src=$(mktemp -d)
if [[ -d "$selected_source_store_path" ]]; then
  cp -R "$selected_source_store_path" "$tmp_src/src"
elif [[ -f "$selected_source_store_path" ]]; then
  mkdir -p "$tmp_src/src"
  tar -xf "$selected_source_store_path" -C "$tmp_src/src" --strip-components=1
else
  echo "Source path not found: $selected_source_store_path" >&2
  exit 1
fi
chmod -R u+w "$tmp_src/src"

gateway_version=$(jq -r '.version // empty' "$tmp_src/src/package.json" 2>/dev/null || true)
if [[ -z "$gateway_version" ]]; then
  echo "Failed to resolve gateway version from upstream package.json" >&2
  exit 1
fi
log "Gateway version from upstream source: $gateway_version"
perl -0pi -e "s|^  version = \"[^\"]+\";|  version = \"${gateway_version}\";|m" "$gateway_file"

nix shell --extra-experimental-features "nix-command flakes" nixpkgs#nodejs_22 nixpkgs#pnpm_10 -c \
  bash -c "cd '$tmp_src/src' && pnpm install --frozen-lockfile --ignore-scripts"

nix shell --extra-experimental-features "nix-command flakes" nixpkgs#nodejs_22 nixpkgs#pnpm_10 -c \
  bash -c "cd '$tmp_src/src' && pnpm exec tsx '$repo_root/nix/scripts/generate-config-options.ts' --repo . --out '$repo_root/nix/generated/openclaw-config-options.nix'"

rm -rf "$tmp_src"
tmp_src=""

log "Building app to validate fetchzip hash"
current_system=$(nix eval --impure --raw --expr 'builtins.currentSystem' 2>/dev/null || true)
if [[ "$current_system" == *darwin* ]]; then
  app_build_log=$(mktemp)
  if ! nix build .#openclaw-app --accept-flake-config >"$app_build_log" 2>&1; then
    app_hash_mismatch=$(grep -Eo 'got: *sha256-[A-Za-z0-9+/=]+' "$app_build_log" | head -n 1 | sed 's/.*got: *//' || true)
    if [[ -n "$app_hash_mismatch" ]]; then
      log "App hash mismatch detected: $app_hash_mismatch"
      perl -0pi -e "s|hash = \"[^\"]+\";|hash = \"${app_hash_mismatch}\";|" "$app_file"
      if ! nix build .#openclaw-app --accept-flake-config >"$app_build_log" 2>&1; then
        tail -n 200 "$app_build_log" >&2 || true
        rm -f "$app_build_log"
        exit 1
      fi
    else
      tail -n 200 "$app_build_log" >&2 || true
      rm -f "$app_build_log"
      exit 1
    fi
  fi
  rm -f "$app_build_log"
else
  log "Skipping app build on non-darwin system (${current_system:-unknown})"
fi

if git diff --quiet; then
  echo "No pin changes detected."
  exit 0
fi

if [[ "${UPDATE_PINS_AUTOCOMMIT:-1}" != "1" ]]; then
  log "Skipping git commit/push because UPDATE_PINS_AUTOCOMMIT=${UPDATE_PINS_AUTOCOMMIT:-1}"
  exit 0
fi

log "Committing updated pins"
git add "$source_file" "$app_file" "$gateway_file" "$repo_root/nix/generated/openclaw-config-options.nix" "$repo_root/flake.lock"
git commit -F - <<'EOF'
🤖 codex: bump openclaw pins (no-issue)

What:
- pin openclaw source to latest upstream main
- refresh macOS app pin to latest release asset
- sync gateway derivation version to upstream package version
- update source and app hashes
- regenerate config options from upstream schema

Why:
- keep nix-openclaw on latest upstream for yolo mode

Tests:
- nix build .#openclaw-gateway --accept-flake-config
- nix build .#openclaw-app --accept-flake-config
EOF

log "Rebasing on latest main"
git fetch origin main
git rebase origin/main

git push origin HEAD:main
