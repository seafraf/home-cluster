{
  namespaces,
  storage,
  app,
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
      name = "USENET__0__PROVIDERS__HOST";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_HOST";
      };
    }
    {
      name = "USENET__0__PROVIDERS__PORT";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_PORT";
      };
    }
    {
      name = "USENET__0__PROVIDERS__USERNAME";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_USER";
      };
    }
    {
      name = "USENET__0__PROVIDERS__PASSWORD";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "DECYPHARR_USENET_PASS";
      };
    }
    {
      name = "USENET__0__PROVIDERS__SSL";
      value = "true";
    }
    {
      name = "USENET__0__PROVIDERS__MAX_CONNECTIONS";
      value = "20";
    }
    {
      name = "USENET__0__PROVIDERS__PRIORITY";
      value = "1";
    }
    {
      name = "MOUNT__TYPE";
      value = "none";
    }
    {
      name = "MOUNT__PATH";
      value = "/media/download";
    }
  ];

  volumes = [
    volumes.config
    volumes.download
  ];
}
