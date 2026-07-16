{
  namespaces,
  network,
  storage,
  ...
}:
let
  appName = "prowlarr";
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
  image = "linuxserver/prowlarr:2.4.0";
  port = 9696;
  configDir = configDir;
  volumes = [ volumes.config ];
}
