{
  namespaces,
  storage,
  app,
  db,
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
  image = "linuxserver/prowlarr:2.4.0";
  configDir = configDir;

    env = [
    {
      name = "PROWLARR__AUTH__APIKEY";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "PROWLARR_API_KEY";
      };
    }
    {
      name = "PROWLARR__AUTH__METHOD";
      value = "External";
    }
    {
      name = "PROWLARR__POSTGRES__HOST";
      value = "${db.mediaServer.name}-rw.${db.mediaServer.namespace}.svc.cluster.local";
    }
    {
      name = "PROWLARR__POSTGRES__USER";
      value = db.mediaServer.dbs.prowlarr.user;
    }
    {
      name = "PROWLARR__POSTGRES__PASSWORD";
      valueFrom.secretKeyRef = {
        name = "prowlarr";
        key = "password";
      };
    }
    {
      name = "PROWLARR__POSTGRES__MAINDB";
      value = db.mediaServer.dbs.prowlarr.name;
    }
    {
      name = "PROWLARR__LOG__DBENABLED";
      value = "False";
    }
  ];

  volumes = [ volumes.config ];
}
