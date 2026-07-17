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
  image = "linuxserver/transmission:4.1.3";
  configDir = configDir;
  volumes = [ volumes.config ];
}
