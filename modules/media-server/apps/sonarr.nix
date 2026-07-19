{
  app,
  apps,
  db,
  lib,
  namespaces,
  network,
  storage,
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

  util = import ./util/arr.nix {
    inherit
      apps
      lib
      network
      volumes
      ;
  };
in
lib.zipAttrsWith util.listCombiner [
  {
    image = "linuxserver/sonarr:4.0.19";
    configDir = configDir;

    env = [
      {
        name = "SONARR__AUTH__APIKEY";
        valueFrom.secretKeyRef = {
          name = "media-server-secrets";
          key = "SONARR_API_KEY";
        };
      }
      {
        name = "SONARR__AUTH__METHOD";
        value = "External";
      }
      {
        name = "SONARR__POSTGRES__HOST";
        value = "${db.mediaServer.name}-rw.${db.mediaServer.namespace}.svc.cluster.local";
      }
      {
        name = "SONARR__POSTGRES__USER";
        value = db.mediaServer.dbs.sonarr.user;
      }
      {
        name = "SONARR__POSTGRES__PASSWORD";
        valueFrom.secretKeyRef = {
          name = "sonarr";
          key = "password";
        };
      }
      {
        name = "SONARR__POSTGRES__MAINDB";
        value = db.mediaServer.dbs.sonarr.name;
      }
      {
        name = "SONARR__LOG__DBENABLED";
        value = "False";
      }
    ];

    initQueries = [
      ''
        TRUNCATE TABLE "RootFolders" RESTART IDENTITY;
        INSERT INTO "RootFolders" ("Path") VALUES ('${volumes.anime.mountPath}'), ('${volumes.series.mountPath}');
      ''
    ];

    volumes = [
      volumes.config
      volumes.download
      volumes.anime
      volumes.series
    ];
  }
  (util.generateDownloadClients "sonarr")
  (util.appNotifications "sonarr")
]
