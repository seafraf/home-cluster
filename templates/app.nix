{
  lib,
  network,
  auth,
  namespaces,
}:
{
  templates.app = {
    options =
      with lib;
      with network;
      {
        name = lib.mkOption {
          type = lib.types.str;
        };
        labels = lib.mkOption {
          default = { };
        };
        ports = lib.mkOption {
          default = { };
        };
        service = lib.mkOption {
          type = types.submodule {
            options = {
              name = lib.mkOption {
                type = types.str;
              };
              namespace = lib.mkOption {
                type = types.str;
              };
              spec = lib.mkOption {
                description = "The spec for the service, if this is set the service will be created, if this is not set it is assumed that the service already exists";
                default = null;
              };
            };
          };
        };
        http = lib.mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                domain = lib.mkOption {
                  type = lib.types.str;
                  default = network.domain;
                };
                subdomain = lib.mkOption {
                  type = lib.types.str;
                };
                gatewayName = lib.mkOption {
                  type = lib.types.str;
                  default = network.gateway;
                };
                gatewayNamespace = lib.mkOption {
                  type = lib.types.str;
                  default = namespaces.network;
                };
                servicePort = lib.mkOption {
                  type = lib.types.ints.u32;
                  default = 80;
                };
                weight = lib.mkOption {
                  type = lib.types.ints.s32;
                  default = 1;
                };
                matches = lib.mkOption {
                  default = [
                    {
                      path = {
                        type = "PathPrefix";
                        value = "/";
                      };
                    }
                  ];
                };
              };
            }
          );
          default = null;
        };
        authSubject = lib.mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
        };
      };

    output =
      {
        name,
        config,
        ...
      }:
      let
        cfg = config;
      in
      lib.mkMerge [
        (lib.mkIf (cfg.service.spec != null) {
          services."${cfg.service.name}" = {
            metadata = {
              name = cfg.service.name;
              namespace = cfg.service.namespace;
            };
            spec = cfg.service.spec;
          };
        })

        (lib.mkIf (cfg.http != null) {
          httpRoutes."${cfg.http.subdomain}-${cfg.http.gatewayName}" = {
            metadata.namespace = cfg.http.gatewayNamespace;
            spec = {
              hostnames = [ "${cfg.http.subdomain}.${cfg.http.domain}" ];

              parentRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "Gateway";
                  name = cfg.http.gatewayName;
                  namespace = cfg.http.gatewayNamespace;
                }
              ];

              rules = [
                {
                  backendRefs = [
                    (
                      if cfg.authSubject == null then
                        {
                          group = "";
                          kind = "Service";
                          name = cfg.service.name;
                          namespace = cfg.service.namespace;
                          port = cfg.http.servicePort;
                          weight = cfg.http.weight;
                        }
                      else
                        {
                          group = "";
                          kind = "Service";
                          name = auth.proxyService.name;
                          namespace = namespaces.auth;
                          port = auth.proxyService.port;
                          weight = 1;
                        }
                    )
                  ];
                  matches = cfg.http.matches;
                }
              ];
            };
          };
        })

        (lib.mkIf
          (cfg.http != null && cfg.http.gatewayNamespace != cfg.service.namespace && cfg.authSubject == null)
          {
            referenceGrants."${cfg.service.namespace}-${cfg.http.gatewayName}" = {
              metadata.namespace = cfg.service.namespace;

              spec = {
                from = [
                  {
                    group = "gateway.networking.k8s.io";
                    kind = "HTTPRoute";
                    namespace = cfg.http.gatewayNamespace;
                  }
                ];

                to = [
                  {
                    group = "";
                    kind = "Service";
                  }
                ];
              };
            };
          }
        )
      ];
  };
}
