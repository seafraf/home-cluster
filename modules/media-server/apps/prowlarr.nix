{
  namespaces,
  storage,
  app,
  apps,
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

  util = import ./util/arr.nix { inherit apps volumes; };
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

  initQueries = [
    (util.generateDownloadClients "prowlarr" "PROWLARR_API_KEY")
    ''
      BEGIN; 
      TRUNCATE TABLE "Applications";
      INSERT INTO "Applications"
        ("Name", "Implementation", "Settings", "ConfigContract", "SyncLevel", "Tags")
        VALUES
        ('Sonarr', 'Sonarr', json_build_object(
          'prowlarrUrl', 'http://${apps.prowlarr.http.serviceName}.${apps.prowlarr.http.serviceNamespace}.svc.cluster.local:${toString apps.prowlarr.http.servicePort}',
          'baseUrl', 'http://${apps.sonarr.http.serviceName}.${apps.sonarr.http.serviceNamespace}.svc.cluster.local:${toString apps.sonarr.http.servicePort}',
          'apiKey', :'SONARR_API_KEY',
          'syncCategories', json_build_array(5000, 5010, 5020, 5030, 5040, 5045, 5050, 5090),
          'animeSyncCategories', json_build_array(5000),
          'syncAnimeStandardFormatSearch', true,
          'syncRejectBlocklistedTorrentHashesWhileGrabbing', false
        )::text, 'SonarrSettings', 2, '[]');

      INSERT INTO "Applications"
        ("Name", "Implementation", "Settings", "ConfigContract", "SyncLevel", "Tags")
        VALUES
        ('Radarr', 'Radarr', json_build_object(
          'prowlarrUrl', 'http://${apps.prowlarr.http.serviceName}.${apps.prowlarr.http.serviceNamespace}.svc.cluster.local:${toString apps.prowlarr.http.servicePort}',
          'baseUrl', 'http://${apps.radarr.http.serviceName}.${apps.radarr.http.serviceNamespace}.svc.cluster.local:${toString apps.radarr.http.servicePort}',
          'apiKey', :'RADARR_API_KEY',
          'syncCategories', json_build_array(2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060, 2070, 2080, 2090),
          'syncRejectBlocklistedTorrentHashesWhileGrabbing', false
        )::text, 'RadarrSettings', 2, '[]');
      COMMIT;
    ''
  ];

  queryVariables = [
    {
      name = "SONARR_API_KEY";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "SONARR_API_KEY";
      };
    }
    {
      name = "RADARR_API_KEY";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "RADARR_API_KEY";
      };
    }
    {
      name = "PROWLARR_API_KEY";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "PROWLARR_API_KEY";
      };
    }
  ];

  volumes = [ volumes.config ];
}
