{
  namespaces,
  network,
  storage,
  ...
}:
let
  appName = "seer";
  configDir = "/app/config";

  volumes = import ../volumes.nix {
    inherit
      namespaces
      storage
      appName
      configDir
      ;
  };
in
{
  name = appName;
  subdomain = "request";
  image = "ghcr.io/seerr-team/seerr:v3.3.0";
  port = 5055;
  configDir = configDir;
  volumes = [ volumes.config ];
}
