{
  namespaces,
  network,
  storage,
  ...
}:
let
  appName = "sonarr";
  configDir = "/config";

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
  subdomain = appName;
  image = "linuxserver/sonarr:4.0.19";
  port = 8989;
  configDir = configDir;
  volumes = [
    volumes.config
    volumes.download
    volumes.anime
    volumes.series
    volumes.movies
  ];
}
