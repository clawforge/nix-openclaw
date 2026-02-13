{ lib
, stdenvNoCC
, fetchzip
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.2.12";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.2.12/OpenClaw-2026.2.12.zip";
    hash = "sha256-uJgZbNW490yL0NXUKHSpR6gJ0qkE6OjYE2bXcZ/g+cc=";
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
