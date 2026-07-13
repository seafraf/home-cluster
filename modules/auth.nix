{ charts, lib, ... }:
let
  name = "authelia";

  labels = {
    "app.kubernetes.io/name" = name;
  };
  image = "authelia/authelia:4.39";

  namespace = "auth-system";

  configName = "config";
  configEntryName = "configuration.yaml";

  subdomain = "auth";
  domainName = "sfdr.me";
  gatewayName = "sfdr-me";
  gatewayNamespace = "network";

  port = 9091;
in
{
  applications.authelia = {
    namespace = namespace;
    createNamespace = true;

    resources = {
      configMaps."${configName}" = {
        data."${configEntryName}" = builtins.toJSON {
          theme = "auto";
          totp.disable = true;

          authentication_backend = {
            password_reset.disable = true;
            pasoword_change.disable = true;
          };

          access_control = {
            default_policy = "deny";

            # todo: build from array
            rules = [
              {
                domain = "longhorn.sfdr.me";
                policy = "one_factor";
                subject = [ "group:admins" ];
              }
            ];
          };

          session.cookies = [
            {
              subdomain = subdomain;
            }
          ];
        };
      };

      deployments.authelia.spec = {
        replicas = 1;
        selector.matchLabels = labels;
        template = {
          metadata.labels = labels;
          spec = {
            containers.authelia = {
              image = image;
              volumeMounts = [
                {
                  name = configName;
                  mountPath = "/config/configuration.yml"; # .yml expected by the container
                  subPath = "${configEntryName}";
                }
              ];
            };
            volumes = [
              {
                name = "config";
                configMap.name = configName;
              }
            ];
          };
        };
      };

      services."${name}".spec = {
        selector = labels;
        ports = [
          {
            name = "http";
            port = port;
            targetPort = port;
          }
        ];
      };

      httpRoutes."${subdomain}-${gatewayName}".spec = {
        hostnames = [ "${subdomain}.${domainName}" ];
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
                name = name;
                namespace = namespace;
                port = port;
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
    };
  };
}
