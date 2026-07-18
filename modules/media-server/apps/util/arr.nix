{ apps, volumes }: {
  generateDownloadClients =
    serviceName: apiKeyEnv:
    let
      decypharr = apps.decypharr.http;
      app = apps.${serviceName};

      # transmission cannot use category and directory
      serviceSpecificSettingsBase =
        if serviceName == "sonarr" then
          ''
            ,
            'tvCategory', '${serviceName}',
            'recentTvPriority', -100,
            'olderTvPriority', -100
          ''
        else if serviceName == "radarr" then
          ''
            ,
            'movieCategory', '${serviceName}',
            'recentMoviePriority', -100,
            'olderMoviePriority', -100
          ''
        # prowlarr
        else
          ''
            ,
            'category', '${serviceName}',
            'priority', 0
          '';

      serviceSpecificSettingsDecypharr =
        if serviceName == "sonarr" then
          ''
            ,'tvDirectory', '${volumes.download.mountPath}'
          ''
        else if serviceName == "radarr" then
          ''
            ,'movieDirectory', '${volumes.download.mountPath}'
          ''
        else
          "";

      serviceSpecificColumns = if serviceName != "prowlarr" then '',"Tags"'' else "";
      serviceSpecificValues = if serviceName != "prowlarr" then ",'[]'" else "";
    in
    ''

      BEGIN; 
      TRUNCATE TABLE "DownloadClients";
      INSERT INTO "DownloadClients"
        ("Enable", "Name", "Implementation", "Settings", "ConfigContract"${serviceSpecificColumns})
        VALUES
        (TRUE, 'Decypharr (Usenet)', 'Sabnzbd', json_build_object(
          'host', '${decypharr.serviceName}.${decypharr.serviceNamespace}.svc.cluster.local',
          'port', ${toString decypharr.servicePort},
          'useSsl', false,
          'urlBase', 'sabnzbd',
          'username', 'http://${app.http.serviceName}.${app.http.serviceNamespace}.svc.cluster.local:${toString app.http.servicePort}',
          'password', :'${apiKeyEnv}'
          ${serviceSpecificSettingsBase}${serviceSpecificSettingsDecypharr}
        )::text, 'SabnzbdSettings'${serviceSpecificValues});

      INSERT INTO "DownloadClients"
        ("Enable", "Name", "Implementation", "Settings", "ConfigContract"${serviceSpecificColumns})
        VALUES
        (TRUE, 'Transmission', 'Transmission', json_build_object(
          'host', '${apps.transmission.http.serviceName}.${apps.transmission.http.serviceNamespace}.svc.cluster.local',
          'port', ${toString apps.transmission.http.servicePort},
          'useSsl', false,
          'urlBase', '/transmission/',
          'username', ''',
          'password', ''',
          'addPaused', false
          ${serviceSpecificSettingsBase}
        )::text, 'TransmissionSettings'${serviceSpecificValues});
      COMMIT;
    '';
}
