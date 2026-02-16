{ lib
, stdenvNoCC
, fetchzip
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.2.15";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.2.15/OpenClaw-2026.2.15.zip";
    hash = "sha256-kiT0E2jCqj/TayJPjf63gbsTCv42r9v5I1rX1Kw0GLU=";
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
