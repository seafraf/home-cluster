{
  apps,
  auth,
  charts,
  db,
  lib,
  namespaces,
  network,
  storage,
  ...
}:
let
  inherit network storage;

  mediaAppFiles = {
    plex = ./apps/plex.nix;
    jellyfin = ./apps/jellyfin.nix;

    transmission = ./apps/transmission.nix;
    sabnzbd = ./apps/sabnzbd.nix;

    sonarr = ./apps/sonarr.nix;
    radarr = ./apps/radarr.nix;
    seerr = ./apps/seerr.nix;
    prowlarr = ./apps/prowlarr.nix;
  };

  route = import ../../templates/app.nix {
    inherit
      lib
      network
      auth
      namespaces
      ;
  };

  secretsFile = ./sops/media-server-secrets.enc.yaml;
  secretConfigHash = builtins.hashFile "sha256" secretsFile;
in
{
  templates.mediaApplication = {
    options = with lib; {
      baseApp = mkOption {
        # type = route.templates.app.options;
      };
      image = mkOption {
        type = lib.types.str;
      };
      configDir = mkOption {
        type = lib.types.str;
      };
      env = mkOption {
        default = [ ];
      };
      runtimeClassName = mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      volumes = mkOption {
        default = [ ];
      };
      id = mkOption {
        type = lib.types.ints.u8;
        default = 0;
      };
      initQueries = mkOption {
        type = types.listOf lib.types.str;
        description = "A list of initializing queries required for this app. The name of this app must exist as a database for this to be used";
        default = [ ];
      };
      queryVariables = mkOption {
        default = [ ];
      };
    };

    output =
      {
        name,
        config,
        lib,
        ...
      }:
      let
        cfg = config;
        labels = {
          "app.kubernetes.io/name" = cfg.name;
        };

        pgid = 2000;
        puid = "1" + lib.fixedWidthString 3 "0" (toString config.id);

        initQuerySet = builtins.listToAttrs (
          lib.imap0 (
            index: sql:
            let
              queryName = "query${toString index}";
            in
            {
              name = queryName;
              value = sql;
            }
          ) cfg.initQueries
        );

        initQueryConfigMap = "${name}-db-queries";
        queriesConfigHash = builtins.hashString "sha256" (builtins.toJSON initQuerySet);

        psqlVarArgs = lib.concatStringsSep " " (
          map (v: ''-v ${v.name}="${"$" + v.name}"'') cfg.queryVariables
        );
      in
      {
        deployments."${name}" = {
          spec = {
            replicas = 1;
            selector.matchLabels = cfg.baseApp.labels;
            template = {
              metadata = {
                annotations."meta.secret.hash" = secretConfigHash;
                annotations."meta.queries.hash" = queriesConfigHash;
                labels = cfg.baseApp.labels;
              };
              spec = {
                enableServiceLinks = false;
                securityContext.fsGroup = pgid;

                initContainers = lib.mapAttrs' (queryName: sql: {
                  name = "exec-query-${queryName}";
                  value = {
                    image = "postgres:16-alpine";
                    env = [
                      {
                        name = "PGHOST";
                        value = "${db.mediaServer.name}-rw.${db.mediaServer.namespace}.svc.cluster.local";
                      }
                      {
                        name = "PGUSER";
                        value = db.mediaServer.dbs."${name}".user;
                      }
                      {
                        name = "PGPASSWORD";
                        valueFrom.secretKeyRef = {
                          inherit name;
                          key = "password";
                        };
                      }
                    ]
                    ++ cfg.queryVariables;
                    command = [
                      "sh"
                      "-c"
                      "psql -v ON_ERROR_STOP=1 ${psqlVarArgs} -f /queries/${queryName}"
                    ];
                    volumeMounts = [
                      {
                        name = initQueryConfigMap;
                        mountPath = "/queries";
                      }
                    ];
                  };
                }) initQuerySet;

                containers."${name}" = {
                  image = cfg.image;
                  env = [
                    {
                      name = "PUID";
                      value = puid;
                    }
                    {
                      name = "PGID";
                      value = toString pgid;
                    }
                    {
                      name = "TZ";
                      value = "Europe/Stockholm";
                    }
                    {
                      name = "UMASK";
                      value = "002";
                    }
                  ]
                  ++ cfg.env;
                  volumeMounts = map (v: {
                    name = v.name;
                    mountPath = v.mountPath;
                    subPath = v.volumePath or null;
                  }) cfg.volumes;
                };

                volumes =
                  (map (v: {
                    name = v.name;
                    persistentVolumeClaim = {
                      claimName = v.name;
                    };
                  }) cfg.volumes)
                  ++ lib.optionals (initQuerySet != { }) [
                    {
                      name = initQueryConfigMap;
                      configMap.name = initQueryConfigMap;
                    }
                  ];
              }
              // lib.optionalAttrs (cfg.runtimeClassName != null) {
                runtimeClassName = cfg.runtimeClassName;
              };
            };
          };
        };

      }
      // lib.optionalAttrs (initQuerySet != { }) {
        configMaps."${initQueryConfigMap}".data = initQuerySet;
      };
  };

  applications.media-server = {
    namespace = namespaces.mediaServer;
    createNamespace = true;

    extraRawYamls = [ secretsFile ];

    resources = {
      persistentVolumeClaims =
        lib.mapAttrs'
          (_: value: {
            name = value.name;
            value = {
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = value.class;
                resources.requests.storage = value.size;
              };
            };
          })
          (
            import ./volumes.nix {
              inherit namespaces storage;

              # these values are not relevant for the PVCs, only mounting
              appName = "dummy";
              configDir = "dummy";
            }
          );
    };

    templates.app = lib.mapAttrs (
      baseAppName: _:
      let
        app = apps."${baseAppName}";
      in
      app
    ) mediaAppFiles;

    templates.mediaApplication = lib.mapAttrs (
      baseAppName: filePath:
      let
        app = apps."${baseAppName}";
      in
      (import filePath {
        inherit
          app
          apps
          auth
          charts
          db
          lib
          namespaces
          network
          storage
          ;
      })
      // {
        baseApp = app;
      }
    ) mediaAppFiles;
  };
}
