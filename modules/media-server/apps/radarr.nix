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

  decypharrSettings = builtins.toJSON {
    host = "123";
    port = 8282;
    useSsl = true;
    urlBase = "";
    username = "";
    password = "";
    movieCategory = "radarr";
    recentMoviePriority = -100;
    olderMoviePriority = -100;
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

  initQueries = [
    ''
      BEGIN; 
      TRUNCATE TABLE "DownloadClients";
      INSERT INTO "DownloadClients"
        ("Enable", "Name", "Implementation", "Settings", "ConfigContract", "Tags")
        VALUES
        (TRUE, 'Decypharr (Usenet)', 'Sabnzbd', json_build_object(
          'host', '${apps.decypharr.http.serviceName}.${apps.decypharr.http.serviceNamespace}.svc.cluster.local',
          'port', ${toString apps.decypharr.http.servicePort},
          'useSsl', false,
          'urlBase', 'sabnzbd',
          'username', 'http://${apps.radarr.http.serviceName}.${apps.radarr.http.serviceNamespace}.svc.cluster.local:${toString apps.radarr.http.servicePort}',
          'password', :'RADARR_API_KEY',
          'movieCategory', 'radarr',
          'recentMoviePriority', -100,
          'olderMoviePriority', -100
        )::text, 'SabnzbdSettings', '[]');

      INSERT INTO "DownloadClients"
        ("Enable", "Name", "Implementation", "Settings", "ConfigContract", "Tags")
        VALUES
        (TRUE, 'Transmission', 'Transmission', json_build_object(
          'host', '${apps.transmission.http.serviceName}.${apps.transmission.http.serviceNamespace}.svc.cluster.local',
          'port', ${toString apps.transmission.http.servicePort},
          'useSsl', false,
          'urlBase', '/transmission/',
          'username', ''',
          'password', ''',
          'movieCategory', ''',
          'recentMoviePriority', 0,
          'olderMoviePriority', 0,
          'addPaused', false
        )::text, 'TransmissionSettings', '[]');
      COMMIT;
    ''
  ];

  queryVariables = [
    {
      name = "RADARR_API_KEY";
      valueFrom.secretKeyRef = {
        name = "media-server-secrets";
        key = "RADARR_API_KEY";
      };
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
