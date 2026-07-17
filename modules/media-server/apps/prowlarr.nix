{
  namespaces,
  storage,
  app,
  ...
}:
let
  configDir = "/config";

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
  image = "linuxserver/prowlarr:2.4.0";
  configDir = configDir;
  volumes = [ volumes.config ];
}
