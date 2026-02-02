{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, nodejs_22
, pnpm_10
, pkg-config
, jq
, python3
, perl
, node-gyp
, makeWrapper
, vips
, git
, zstd
, sourceInfo
, gatewaySrc ? null
, pnpmDepsHash ? (sourceInfo.pnpmDepsHash or null)
}:

assert gatewaySrc == null || pnpmDepsHash != null;

let
  sourceFetch = lib.removeAttrs sourceInfo [ "pnpmDepsHash" ];
  pnpmPlatform = if stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  pnpmArch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
  # Native binary for Matrix E2EE support (@matrix-org/matrix-sdk-crypto-nodejs)
  matrixCryptoNative = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.${pnpmPlatform}-${pnpmArch}.node";
    hash = if pnpmPlatform == "darwin" && pnpmArch == "arm64"
      then "sha256-9/X99ikki9q5NOUDj3KL+7OzYfOhSiTtGAZhCMEpry8="
      else lib.fakeHash;
  };

  nodeAddonApi = stdenv.mkDerivation {
    pname = "node-addon-api";
    version = "8.5.0";
    src = fetchurl {
      url = "https://registry.npmjs.org/node-addon-api/-/node-addon-api-8.5.0.tgz";
      hash = "sha256-0S8HyBYig7YhNVGFXx2o2sFiMxN0YpgwteZA8TDweRA=";
    };
    dontConfigure = true;
    dontBuild = true;
    installPhase = "${../scripts/node-addon-api-install.sh}";
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "openclaw-gateway";
  version = "2026.1.30";

  src = if gatewaySrc != null then gatewaySrc else fetchFromGitHub sourceFetch;

  pnpmDeps = pnpm_10.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = if pnpmDepsHash != null
      then pnpmDepsHash
      else lib.fakeHash;
    fetcherVersion = 2;
    npm_config_arch = pnpmArch;
    npm_config_platform = pnpmPlatform;
    nativeBuildInputs = [ git ];
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm_10
    pkg-config
    jq
    python3
    perl
    node-gyp
    makeWrapper
    zstd
  ];

  buildInputs = [ vips ];

  env = {
    SHARP_IGNORE_GLOBAL_LIBVIPS = "1";
    npm_config_arch = pnpmArch;
    npm_config_platform = pnpmPlatform;
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
    npm_config_nodedir = nodejs_22;
    npm_config_python = python3;
    NODE_PATH = "${nodeAddonApi}/lib/node_modules:${node-gyp}/lib/node_modules";
    NODE_BIN = "${nodejs_22}/bin/node";
    PNPM_DEPS = finalAttrs.pnpmDeps;
    NODE_GYP_WRAPPER_SH = "${../scripts/node-gyp-wrapper.sh}";
    GATEWAY_PREBUILD_SH = "${../scripts/gateway-prebuild.sh}";
    PROMOTE_PNPM_INTEGRITY_SH = "${../scripts/promote-pnpm-integrity.sh}";
    REMOVE_PACKAGE_MANAGER_FIELD_SH = "${../scripts/remove-package-manager-field.sh}";
    STDENV_SETUP = "${stdenv}/setup";
  };

  postPatch = "${../scripts/gateway-postpatch.sh}";
  buildPhase = "${../scripts/gateway-build.sh}";
  installPhase = "${../scripts/gateway-install.sh}";
  dontStrip = true;
  dontPatchShebangs = true;

  # TODO: Remove this postFixup once upstream PR #3368 is merged and released
  postFixup = ''
    # Patch DM thread delivery bug (PR #3368)
    local f="$out/lib/openclaw/dist/telegram/bot-message-context.js"

    # 1. Add effectiveThreadId after the resolvedThreadId assignment (multi-line, closes with "});")
    #    Match the closing of resolveTelegramForumThreadId({ ... }); and insert after it
    sed -i '/const resolvedThreadId = resolveTelegramForumThreadId/,/});/{
      /});/a\    const effectiveThreadId = isGroup ? resolvedThreadId : messageThreadId;
    }' "$f"

    # 2-3. Replace buildTypingThreadParams(resolvedThreadId) with effectiveThreadId
    sed -i 's/buildTypingThreadParams(resolvedThreadId)/buildTypingThreadParams(effectiveThreadId)/g' "$f"

    # 4. In the context return object, replace standalone resolvedThreadId, with resolvedThreadId: effectiveThreadId,
    #    Use a pattern that excludes "messageThreadId: resolvedThreadId," (line 272)
    sed -i '/messageThreadId: resolvedThreadId,/!s/^[[:space:]]*resolvedThreadId,/        resolvedThreadId: effectiveThreadId,/' "$f"

    # 5. Fix draft streaming in DM threads: skip resolveBotTopicsEnabled check for private chats
    local d="$out/lib/openclaw/dist/telegram/bot-message-dispatch.js"
    sed -i 's/typeof resolvedThreadId === "number" &&/typeof resolvedThreadId === "number" \&\&/' "$d"
    sed -i 's/(await resolveBotTopicsEnabled(primaryCtx));/(isPrivateChat || (await resolveBotTopicsEnabled(primaryCtx)));/' "$d"

    # Install native Matrix E2EE crypto binary
    local crypto_pkg
    crypto_pkg="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/node_modules/@matrix-org/matrix-sdk-crypto-nodejs" -print | head -n 1)"
    if [ -n "$crypto_pkg" ]; then
      cp "${matrixCryptoNative}" "$crypto_pkg/matrix-sdk-crypto.${pnpmPlatform}-${pnpmArch}.node"
    fi

    # Patch Matrix E2EE cross-signing: enable SignatureUpload in RustEngine
    # The SDK throws on SignatureUpload requests, preventing cross-signing bootstrap.
    # This implements the handler following the same pattern as processKeysUploadRequest.
    local rustEngine
    rustEngine="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/@vector-im/matrix-bot-sdk/lib/e2ee/RustEngine.js" -print | head -n 1)"
    if [ -n "$rustEngine" ]; then
      sed -i 's|case 4 /\* RequestType.SignatureUpload \*/:|case 4 /* RequestType.SignatureUpload */:|' "$rustEngine"
      sed -i '/case 4 \/\* RequestType.SignatureUpload \*\/:/,/throw new Error/{
        s|throw new Error("Bindings error: Backup feature not possible");|const sigBody = JSON.parse(request.body); const sigResp = await this.client.doRequest("POST", "/_matrix/client/v3/keys/signatures/upload", null, sigBody); await this.machine.markRequestAsSent(request.id, request.type, JSON.stringify(sigResp)); break;|
      }' "$rustEngine"
    fi

    # Patch Matrix E2EE: replace broken requestOwnUserVerification with bootstrapCrossSigning
    # The bot-sdk doesn't expose requestOwnUserVerification. Instead, we bootstrap
    # cross-signing via the OlmMachine which self-signs the device.
    local matrixMonitor="$out/lib/openclaw/extensions/matrix/src/matrix/monitor/index.ts"
    if [ -f "$matrixMonitor" ]; then
      sed -i 's|const verificationRequest = await client.crypto.requestOwnUserVerification();|await (client.crypto as any).engine.machine.bootstrapCrossSigning(true); await (client.crypto as any).engine.run();|' "$matrixMonitor"
      sed -i 's|if (verificationRequest) {|if (true) {|' "$matrixMonitor"
      sed -i 's|"matrix: device verification requested - please verify in another client"|"matrix: cross-signing bootstrapped - device self-verified"|' "$matrixMonitor"
    fi
  '';

  meta = with lib; {
    description = "Telegram-first AI gateway (Openclaw)";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin ++ platforms.linux;
    mainProgram = "openclaw";
  };
})
