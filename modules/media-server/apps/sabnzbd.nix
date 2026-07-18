#

{
  namespaces,
  storage,
  app,
  apps,
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
  image = "linuxserver/sabnzbd:5.0.4";
  configDir = configDir;

  volumes = [
    volumes.config
    volumes.download
  ];
}
