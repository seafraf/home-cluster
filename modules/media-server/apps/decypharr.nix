{
  namespaces,
  storage,
  app,
  ...
}:
let
  configDir = "/app";

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
  image = "cy01/blackhole:v2.3";
  configDir = configDir;
  volumes = [
    volumes.config
    volumes.download
  ];
}
