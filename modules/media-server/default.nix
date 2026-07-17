{
  charts,
  lib,
  network,
  storage,
  namespaces,
  auth,
  apps,
  ...
}:
let
  inherit network storage;

  mediaAppFiles = {
    plex = ./apps/plex.nix;
    jellyfin = ./apps/jellyfin.nix;

    decypharr = ./apps/decypharr.nix;
    transmission = ./apps/transmission.nix;

    sonarr = ./apps/sonarr.nix;
    radarr = ./apps/radarr.nix;
    seer = ./apps/seer.nix;
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
      in
      {
        deployments."${name}".spec = {
          replicas = 1;
          selector.matchLabels = cfg.baseApp.labels;
          template = {
            metadata.labels = cfg.baseApp.labels;
            spec = {
              securityContext.fsGroup = pgid;

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

              volumes = map (v: {
                name = v.name;
                persistentVolumeClaim = {
                  claimName = v.name;
                };
              }) cfg.volumes;
            }
            // lib.optionalAttrs (cfg.runtimeClassName != null) {
              runtimeClassName = cfg.runtimeClassName;
            };
          };
        };
      };
  };

  applications.media-server = {
    namespace = namespaces.mediaServer;
    createNamespace = true;

    extraRawYamls = [ ./sops/media-server-secrets.enc.yaml ];

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
        mediaApp = import filePath {
          inherit
            namespaces
            network
            storage
            app
            ;
        };
      in
      mediaApp
      // {
        baseApp = app;
      }
    ) mediaAppFiles;
  };
}
