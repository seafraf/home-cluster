{
  namespaces,
  storage,
  app,
  ...
}:
let
  configDir = "/app/config";

  volumes = import ../volumes.nix {
    inherit
      namespaces
      storage
      configDir
      ;
    appName = app.name;
  };
in
{
  image = "ghcr.io/seerr-team/seerr:v3.3.0";
  configDir = configDir;
  volumes = [ volumes.config ];
}
