{ lib
, buildEnv
, openclaw-gateway
, openclaw-app ? null
, extendedTools ? []
}:

let
  appPaths = lib.optional (openclaw-app != null) openclaw-app;
  appLinks = lib.optional (openclaw-app != null) "/Applications";
  gatewayVersion = openclaw-gateway.version or "unknown";
  appVersionSuffix = if openclaw-app != null && openclaw-app ? version
    then "-app-${openclaw-app.version}"
    else "";
in
buildEnv {
  name = "openclaw-${gatewayVersion}${appVersionSuffix}";
  paths = [ openclaw-gateway ] ++ appPaths ++ extendedTools;
  pathsToLink = [ "/bin" ] ++ appLinks;

  meta = with lib; {
    description = "Openclaw batteries-included bundle (gateway + app + tools)";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin ++ platforms.linux;
  };
}
