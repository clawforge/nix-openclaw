{ lib
, stdenvNoCC
, fetchzip
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.2.14";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.2.14/OpenClaw-2026.2.14.zip";
    hash = "sha256-vSo9WlEQo72Yj43kvcDfCUuizkxIzUIpO7VEtHvrq4g=";
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
