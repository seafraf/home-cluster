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
  image = "linuxserver/radarr:6.1.1";
  configDir = configDir;

  env = [
    {
      name = "RADARR__AUTH__APIKEY";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "RADARR_API_KEY";
      };
    }
    {
      name = "RADARR__AUTH__METHOD";
      value = "External";
    }
    {
      name = "RADARR__POSTGRES__HOST";
      value = "${db.mediaServer.name}-rw.${db.mediaServer.namespace}.svc.cluster.local";
    }
    {
      name = "RADARR__POSTGRES__USER";
      value = db.mediaServer.dbs.radarr.user;
    }
    {
      name = "RADARR__POSTGRES__PASSWORD";
      valueFrom.secretKeyRef = {
        name = "radarr";
        key = "password";
      };
    }
    {
      name = "RADARR__POSTGRES__MAINDB";
      value = db.mediaServer.dbs.radarr.name;
    }
    {
      name = "RADARR__LOG__DBENABLED";
      value = "False";
    }
  ];

  volumes = [
    volumes.config
    volumes.download
    volumes.anime
    volumes.series
    volumes.movies
  ];
}
