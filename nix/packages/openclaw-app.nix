{ lib
, stdenvNoCC
, fetchzip
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.3.13-beta.1";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.3.13-beta.1/OpenClaw-2026.3.13.zip";
    hash = "sha256-V2raRMaD0dzBgJNaV6JEbaihuOu0GIUWdEnyzNxJefg=";
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
