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
  image = "linuxserver/jellyfin:10.11.11";
  configDir = configDir;
  volumes = [
    volumes.config
    volumes.download
  ];
}
