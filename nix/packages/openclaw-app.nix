{ lib
, stdenvNoCC
, fetchzip
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.2.9";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.2.9/OpenClaw-2026.2.9.zip";
    hash = "sha256-pEpPLkKoX+s2C4nk67FaBHoUTSc5SosMC1IE4YbJOAs=";
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
