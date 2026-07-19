{
  apps,
  lib,
  network,
  volumes,
}:
let
  listCombiner =
    name: values:
    if lib.all builtins.isList values then
      lib.concatLists values
    else if lib.all builtins.isAttrs values then
      lib.zipAttrsWith listCombiner values
    else
      lib.last values;

  plexDomain =
    if apps.plex.http ? domain then
      "${apps.plex.http.subdomain}.${apps.plex.http.domain}"
    else
      "${apps.plex.http.subdomain}.${network.domain}";

  plexNotificationSettings = ''
    json_build_object(
            'server', 'https://${plexDomain}',
            'host', '${apps.plex.http.serviceName}.${apps.plex.http.serviceNamespace}.svc.cluster.local',
            'useSsl', false, 
            'authToken', :'PLEX_TOKEN',
            'signIn', 'startOAuth',
            'updateLibrary', true,
            'isValid', true
          )::text'';

  jellyfinNotificationSettings = ''
    json_build_object(
            'host', '${apps.jellyfin.http.serviceName}.${apps.jellyfin.http.serviceNamespace}.svc.cluster.local',
            'useSsl', false, 
            'apiKey', :'JELLYFIN_API_KEY',
            'notify', false,
            'address', '${apps.jellyfin.http.serviceName}.${apps.jellyfin.http.serviceNamespace}.svc.cluster.local:${toString apps.jellyfin.http.servicePort}',
            'isValid', true
          )::text'';
in
{
  inherit listCombiner;

  generateDownloadClients =
    serviceName:
    let
      sabnzbd = apps.sabnzbd.http;
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

      serviceSpecificSettingsSabnzbd =
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
    {
      initQueries = [
        ''
          BEGIN; 
          TRUNCATE TABLE "DownloadClients" RESTART IDENTITY;
          INSERT INTO "DownloadClients"
            ("Enable", "Name", "Implementation", "Settings", "ConfigContract"${serviceSpecificColumns})
            VALUES
            (TRUE, 'Sabnzbd', 'SABnzbd', json_build_object(
              'host', '${sabnzbd.serviceName}.${sabnzbd.serviceNamespace}.svc.cluster.local',
              'port', ${toString sabnzbd.servicePort},
              'useSsl', false,
              'apiKey', :'SABNZDB_API_KEY'
              ${serviceSpecificSettingsBase}${serviceSpecificSettingsSabnzbd}
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
        ''
      ];

      queryVariables = [
        {
          name = "SABNZDB_API_KEY";
          valueFrom.secretKeyRef = {
            name = "media-server-secrets";
            key = "SABNZDB_API_KEY";
          };
        }
      ];
    };

  appNotifications =
    appName:
    let
      columnNames = builtins.concatStringsSep "," (
        map (s: "\"${s}\"") (
          if appName == "sonarr" then
            [
              "Name"
              "OnGrab"
              "OnDownload"
              "Settings"
              "Implementation"
              "ConfigContract"
              "OnUpgrade"
              "Tags"
              "OnRename"
              "OnHealthIssue"
              "IncludeHealthWarnings"
              "OnSeriesDelete"
              "OnEpisodeFileDelete"
              "OnEpisodeFileDeleteForUpgrade"
              "OnApplicationUpdate"
              "OnManualInteractionRequired"
              "OnSeriesAdd"
              "OnHealthRestored"
              "OnImportComplete"
            ]
          else
            [
              "Name"
              "OnGrab"
              "OnDownload"
              "Settings"
              "Implementation"
              "ConfigContract"
              "OnUpgrade"
              "Tags"
              "OnRename"
              "OnHealthIssue"
              "IncludeHealthWarnings"
              "OnMovieDelete"
              "OnMovieFileDelete"
              "OnMovieFileDeleteForUpgrade"
              "OnApplicationUpdate"
              "OnMovieAdded"
              "OnHealthRestored"
              "OnManualInteractionRequired"
            ]
        )
      );

      plexColumnValues = builtins.concatStringsSep "," (
        map (s: "${s}") (
          if appName == "sonarr" then
            [
              "'Plex Media Server'"
              "false"
              "true"
              plexNotificationSettings
              "'PlexServer'"
              "'PlexServerSettings'"
              "true"
              "'[]'"
              "true"
              "false"
              "false"
              "true"
              "true"
              "true"
              "false"
              "false"
              "true"
              "false"
              "true"
            ]
          else
            [
              "'Plex Media Server'"
              "false"
              "true"
              plexNotificationSettings
              "'PlexServer'"
              "'PlexServerSettings'"
              "true"
              "'[]'"
              "true"
              "false"
              "false"
              "true"
              "true"
              "true"
              "false"
              "false"
              "false"
              "false"
            ]
        )
      );

      jellyfinColumnValues = builtins.concatStringsSep "," (
        map (s: "${s}") (
          if appName == "sonarr" then
            [
              "'Jellyfin'"
              "true"
              "true"
              jellyfinNotificationSettings
              "'MediaBrowser'"
              "'MediaBrowserSettings'"
              "true"
              "'[]'"
              "true"
              "false"
              "false"
              "true"
              "true"
              "true"
              "true"
              "false"
              "true"
              "false"
              "true"
            ]
          else
            [
              "'Jellyfin'"
              "true"
              "true"
              plexNotificationSettings
              "'MediaBrowser'"
              "'MediaBrowserSettings'"
              "true"
              "'[]'"
              "true"
              "false"
              "false"
              "true"
              "true"
              "true"
              "true"
              "false"
              "false"
              "false"
            ]
        )
      );
    in
    {
      initQueries = [
        ''
          TRUNCATE TABLE "Notifications" RESTART IDENTITY;

          INSERT INTO "Notifications" (${columnNames})
          VALUES (${plexColumnValues}), (${jellyfinColumnValues});
        ''
      ];

      queryVariables = [
        {
          name = "PLEX_TOKEN";
          valueFrom.secretKeyRef = {
            name = "media-server-secrets";
            key = "PLEX_TOKEN";
          };
        }
        {
          name = "JELLYFIN_API_KEY";
          valueFrom.secretKeyRef = {
            name = "media-server-secrets";
            key = "JELLYFIN_API_KEY";
          };
        }
      ];
    };
}
