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
    { appName }:
    [
      {
        name = "${namespace}-config";
        size = "128Gi"; # Should be rather large
        path = "/config/${appName}";
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
      env = [
        {
          name = "JELLYFIN_PublishedServerUrl";
          value = "jellyfin.${domainName}";
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
                    })
                    (volumes {
                      appName = name;
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
            appName = "myapp";
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
