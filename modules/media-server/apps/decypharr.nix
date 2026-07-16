{
  namespaces,
  network,
  storage,
  ...
}:
let
  appName = "decypharr";
  configDir = "/app";

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
  subdomain = "dl";
  image = "linuxserver/jellyfin:10.11.11";
  port = 8282;
  configDir = configDir;
  volumes = [
    volumes.config
    volumes.download
  ];
}
