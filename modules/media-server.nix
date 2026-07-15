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

  volumes =
    { appName, configDir }:
    [
      {
        name = "${namespace}-config";
        size = "128Gi"; # Should be rather large
        path = configDir;
        subPath = appName;
        class = storage.ssd;
      }
      {
        name = "${namespace}-transcode";
        size = "256Gi";
        path = "/media/transcode";
        subPath = appName;
        class = storage.ssd;
      }
      {
        name = "${namespace}-download";
        size = "256Gi";
        path = "/media/download";
        class = storage.hdd;
      }
      {
        name = "${namespace}-anime";
        size = "2Ti";
        path = "/media/anime";
        class = storage.hdd;
      }
      {
        name = "${namespace}-series";
        size = "5Ti";
        path = "/media/series";
        class = storage.hdd;
      }
      {
        name = "${namespace}-movies";
        size = "3Ti";
        path = "/media/movies";
        class = storage.hdd;
      }
    ];

  mediaApps = [
    {
      name = "plex";
      subdomain = "plex";
      image = "linuxserver/plex:version-1.43.3.10828-00f62d37d";
      port = 32400;
      configDir = "/config";
      runtimeClassName = "nvidia";

      # plex needs extra help finding libcuda
      env = [
        {
          name = "NVIDIA_VISIBLE_DEVICES";
          value = "all";
        }
        {
          name = "NVIDIA_DRIVER_CAPABILITIES";
          value = "all";
        }
        {
          name = "LD_LIBRARY_PATH";
          value = "/usr/local/nvidia/lib64/";
        }
      ];
    }
    {
      name = "jellyfin";
      subdomain = "jellyfin";
      image = "linuxserver/jellyfin:10.11.11";
      port = 8096;
      configDir = "/config";
      runtimeClassName = "nvidia";
      env = [
        {
          name = "JELLYFIN_PublishedServerUrl";
          value = "jellyfin.${network.domain}";
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

    extraRawYamls = [ ../sops/transmission-password.enc.yaml ];

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

      persistentVolumeClaims = builtins.listToAttrs (
        map
          (v: {
            name = v.name;
            storageClass = v.class;
            value = {
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = v.class;
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
