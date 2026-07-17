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
  image = "linuxserver/radarr:6.1.1";
  configDir = configDir;
  volumes = [
    volumes.config
    volumes.download
    volumes.anime
    volumes.series
    volumes.movies
  ];
}
