{
  charts,
  lib,
  options,
  ...
}:
let
  namespace = "media-server";
  domainName = "sforder.me";
  gatewayName = "sforder-me";
  gatewayNamespace = "network";

  volumes =
    { appName, configDir }:
    [
      {
        name = "${namespace}-config";
        size = "128Gi"; # Should be rather large
        path = configDir;
        subPath = appName;
      }
      {
        name = "${namespace}-download";
        size = "128Gi";
        path = "/media/download";
      }
      {
        name = "${namespace}-anime";
        size = "128Gi";
        path = "/media/anime";
      }
      {
        name = "${namespace}-series";
        size = "128Gi";
        path = "/media/series";
      }
      {
        name = "${namespace}-movies";
        size = "128Gi";
        path = "/media/movies";
      }
    ];

  mediaApps = [
    {
      name = "plex";
      subdomain = "plex";
      image = "linuxserver/plex:version-1.43.2.10687-563d026ea";
      port = 32400;
      configDir = "/config";
      env = [
        {
          name = "NVIDIA_VISIBLE_DEVICES";
          value = "all";
        }
        {
          name = "NVIDIA_DRIVER_CAPABILITIES";
          value = "all";
        }
      ];
    }
    {
      name = "jellyfin";
      subdomain = "jellyfin";
      image = "linuxserver/jellyfin:10.11.11";
      port = 8096;
      configDir = "/config";
      env = [
        {
          name = "JELLYFIN_PublishedServerUrl";
          value = "jellyfin.${domainName}";
        }
      ];
    }
    {
      name = "decypharr";
      subdomain = "dl";
      image = "cy01/blackhole:v2.3";
      port = 8282;
      configDir = "/app";
    }
    {
      name = "seer";
      subdomain = "request";
      image = "ghcr.io/seerr-team/seerr:v3.3.0";
      port = 5055;
      configDir = "/app/config";
    }
    {
      name = "prowlarr";
      subdomain = "prowlarr";
      image = "linuxserver/prowlarr:2.4.0";
      port = 9696;
      configDir = "/config";
    }
    {
      name = "radarr";
      subdomain = "radarr";
      image = "linuxserver/radarr:6.1.1";
      port = 7878;
      configDir = "/config";
    }
    {
      name = "sonarr";
      subdomain = "sonarr";
      image = "linuxserver/sonarr:4.0.19";
      port = 8989;
      configDir = "/config";
    }
    {
      name = "sonarr";
      subdomain = "sonarr";
      image = "linuxserver/sonarr:4.0.19";
      port = 8989;
      configDir = "/config";
    }
    {
      name = "transmission";
      subdomain = "tx";
      image = "linuxserver/transmission:4.1.3";
      port = 9091;
      configDir = "/config";
      env = [
        {
          name = "USER";
          value = "root";
        }
        {
          name = "PASS";
          valueFrom.secretKeyRef = {
            key = "password";
            name = "transmission-password";
            optional = false;
          };
        }
      ];
    }
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
      env = mkOption {
        default = [ ];
      };
      configDir = mkOption {
        type = lib.types.str;
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
      in
      {
        deployments."${name}".spec = {
          replicas = 1;
          selector.matchLabels = labels;
          template = {
            metadata.labels = labels;
            spec = {
              containers."${name}" = {
                image = cfg.image;
                env = [
                  {
                    name = "PUID";
                    value = "1" + lib.fixedWidthString 3 "0" (toString cfg.id);
                  }
                  {
                    name = "PGID";
                    value = "Europe/Stockholm";
                  }
                  {
                    name = "UMASK";
                    value = "002";
                  }
                ]
                ++ cfg.env;
                volumeMounts =
                  map
                    (v: {
                      name = v.name;
                      mountPath = v.path;
                      subPath = v.subPath or null;
                    })
                    (volumes {
                      appName = name;
                      configDir = cfg.configDir;
                    });
              };

              volumes =
                map
                  (v: {
                    name = v.name;
                    persistentVolumeClaim = {
                      claimName = v.name;
                    };
                  })
                  (volumes {
                    appName = name;
                    configDir = cfg.configDir;
                  });
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

        httpRoutes."${name}-${gatewayName}".spec = {
          hostnames = [ "${cfg.subdomain}.${domainName}" ];
          parentRefs = [
            {
              group = "gateway.networking.k8s.io";
              kind = "Gateway";
              name = gatewayName;
              namespace = gatewayNamespace;
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

    resources = {
      # Grant HTTPRoutes in this namespace to access the Gateway in the network namespace
      referenceGrants."${namespace}-${gatewayName}" = {
        metadata = {
          namespace = gatewayNamespace;
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

      persistentVolumeClaims = builtins.listToAttrs (
        map
          (v: {
            name = v.name;
            value = {
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                resources.requests.storage = v.size;
              };
            };
          })
          (volumes {
            appName = "";
            configDir = "";
          })
      );
    };

    templates.mediaApplication = lib.listToAttrs (
      lib.imap0 (i: app: {
        name = app.name;
        value = app // {
          id = i;
        };
      }) mediaApps
    );
  };
}
