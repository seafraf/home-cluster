{
  namespace,
  network,
  storage,
  ...
}:
let
  appName = "radarr";
  configDir = "/config";

  volumes = import ../volumes.nix {
    inherit
      namespace
      storage
      appName
      configDir
      ;
  };
in
{
  name = appName;
  subdomain = appName;
  image = "linuxserver/radarr:6.1.1";
  port = 7878;
  configDir = configDir;
  volumes = [
    volumes.config
    volumes.download
    volumes.anime
    volumes.series
    volumes.movies
  ];
}
