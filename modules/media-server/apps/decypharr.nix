{
  namespaces,
  storage,
  app,
  apps,
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
  image = "cy01/blackhole:v2.4";
  configDir = configDir;

  env = [
    {
      name = "USE_AUTH";
      value = "false";
    }
    {
      name = "API_TOKEN";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_API_KEY";
      };
    }
    {
      name = "USENET__PROVIDERS__0__HOST";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_HOST";
      };
    }
    {
      name = "USENET__PROVIDERS__0__PORT";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_PORT";
      };
    }
    {
      name = "USENET__PROVIDERS__0__USERNAME";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_USER";
      };
    }
    {
      name = "USENET__PROVIDERS__0__PASSWORD";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_PASS";
      };
    }
    {
      name = "USENET__PROVIDERS__0__SSL";
      value = "true";
    }
    {
      name = "USENET__PROVIDERS__0__BACKBONE";
      value = "Omicron";
    }
    {
      name = "MOUNT__TYPE";
      value = "none";
    }
    {
      name = "DOWNLOAD_FOLDER";
      value = "/media/download";
    }
  ];

  volumes = [
    volumes.config
    volumes.download
  ];
}
