{
  charts,
  lib,
  options,
  network,
  storage,
  ...
}:
let
  inherit network storage;

  namespace = "media-server";

  mediaAppFiles = [
    ./apps/plex.nix
    ./apps/jellyfin.nix

    ./apps/decypharr.nix
    ./apps/transmission.nix

    ./apps/sonarr.nix
    ./apps/radarr.nix
    ./apps/seer.nix
    ./apps/prowlarr.nix
  ];
in
{
  templates.mediaApplication = {
    options = with lib; {
      name = mkOption {
        type = lib.types.str;
      };
      subdomain = mkOption {
        type = lib.types.str;
      };
      image = mkOption {
        type = lib.types.str;
      };
      port = mkOption {
        type = lib.types.ints.u16;
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
          selector.matchLabels = labels;
          template = {
            metadata.labels = labels;
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

        services."${name}".spec = {
          selector = labels;
          ports.http = {
            port = cfg.port;
            targetPort = cfg.port;
            appProtocol = "http";
          };
        };

        httpRoutes."${name}-${network.gateway}".spec = {
          hostnames = [ "${cfg.subdomain}.${network.domain}" ];
          parentRefs = [
            {
              group = "gateway.networking.k8s.io";
              kind = "Gateway";
              name = network.gateway;
              namespace = network.namespace;
            }
          ];

          rules = [
            {
              backendRefs = [
                {
                  group = "";
                  kind = "Service";
                  name = cfg.name;
                  namespace = namespace;
                  port = cfg.port;
                  weight = 1;
                }
              ];
              matches = [
                {
                  path = {
                    type = "PathPrefix";
                    value = "/";
                  };
                }
              ];
            }
          ];
        };
      };
  };

  applications.media-server = {
    namespace = namespace;
    createNamespace = true;

    extraRawYamls = [ ./sops/media-server-secrets.enc.yaml ];

    resources = {
      # Grant HTTPRoutes in this namespace to access the Gateway in the network namespace
      referenceGrants."${namespace}-${network.gateway}" = {
        metadata = {
          namespace = network.namespace;
        };
        spec = {
          from = [
            {
              group = "gateway.networking.k8s.io";
              kind = "HTTPRoute";
              namespace = namespace;
            }
          ];
          to = [
            {
              group = "gateway.networking.k8s.io";
              kind = "Gateway";
            }
          ];
        };
      };

      persistentVolumeClaims =
        lib.mapAttrs
          (name: value: {
            spec = {
              accessModes = [ "ReadWriteOnce" ];
              storageClassName = value.class;
              resources.requests.storage = value.size;
            };
          })
          (
            import ./volumes.nix {
              inherit namespace storage;

              # these values are not relevant for the PVCs, only mounting
              appName = "dummy";
              configDir = "dummy";
            }
          );
    };

    templates.mediaApplication = lib.listToAttrs (
      lib.imap0 (
        i: file:
        let
          app = import file { inherit namespace network storage; };
        in
        {
          name = app.name;
          value = app // {
            id = i;
          };
        }
      ) mediaAppFiles
    );
  };
}
