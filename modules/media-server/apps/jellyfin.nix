{
  namespaces,
  network,
  storage,
  ...
}:
let
  appName = "jellyfin";
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
  image = "linuxserver/jellyfin:10.11.11";
  port = 8096;
  configDir = configDir;
  runtimeClassName = "nvidia";
  env = [
    {
      name = "JELLYFIN_PublishedServerUrl";
      value = "jellyfin.${network.domain}";
    }
  ];
  volumes = [
    volumes.config
    volumes.transcode
    volumes.anime
    volumes.series
    volumes.movies
  ];
}
