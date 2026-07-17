{
  namespaces,
  network,
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

  domain =
    if app.http ? domain then
      "${app.http.subdomain}.${app.http.domain}"
    else
      "${app.http.subdomain}.${network.domain}";
in
{
  image = "linuxserver/jellyfin:10.11.11";
  configDir = configDir;
  runtimeClassName = "nvidia";
  env = [
    {
      name = "JELLYFIN_PublishedServerUrl";
      value = domain;
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
