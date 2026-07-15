{
  namespace,
  network,
  storage,
  ...
}:
let
  appName = "transmission";
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
  subdomain = "tx";
  image = "linuxserver/transmission:4.1.3";
  port = 9091;
  configDir = configDir;
  env = [
    {
      name = "USER";
      value = "root";
    }
    {
      name = "PASS";
      valueFrom.secretKeyRef = {
        key = "transmissionPassword";
        name = "media-server-secrets";
        optional = false;
      };
    }
  ];
  volumes = [ volumes.config ];
}
