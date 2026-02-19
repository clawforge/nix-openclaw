{ lib
, stdenvNoCC
, fetchzip
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.2.17";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.2.17/OpenClaw-2026.2.17.zip";
    hash = "sha256-wEisbUFBc/pRmwnd3LGpqvi7ObBTdgx7qWSn0DIDPcw=";
    stripRoot = false;
  };

  dontUnpack = true;

  installPhase = "${../scripts/openclaw-app-install.sh}";

  meta = with lib; {
    description = "Openclaw macOS app bundle";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
