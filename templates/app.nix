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
        services = lib.mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                name = lib.mkOption {
                  type = types.str;
                };
                namespace = lib.mkOption {
                  type = types.str;
                };
                annotations = lib.mkOption {
                  type = types.attrsOf types.str;
                  default = { };
                };
                spec = lib.mkOption {
                  type = types.nullOr types.anything;
                  description = "The spec for the service, if this is set the service will be created, if this is not set it is assumed that the service already exists";
                  default = null;
                };
              };
            }
          );
          default = [ ];
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
                serviceName = lib.mkOption {
                  type = lib.types.str;
                };
                serviceNamespace = lib.mkOption {
                  type = lib.types.str;
                };
                servicePort = lib.mkOption {
                  type = lib.types.ints.u32;
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

        # serviceName =
      in
      lib.mkMerge [
        {
          services = lib.listToAttrs (
            map (service: {
              name = service.name;
              value = {
                metadata = {
                  name = service.name;
                  namespace = service.namespace;
                  annotations = service.annotations;
                };
                spec = service.spec;
              };
            }) cfg.services
          );
        }

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
                          name = cfg.http.serviceName;
                          namespace = cfg.http.serviceNamespace;
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

        # this results in merges that put more than one from entry sometimes.. but it doesn't cause issues
        (lib.mkIf
          (
            cfg.http != null
            && cfg.authSubject == null
            && cfg.http.serviceNamespace != cfg.http.gatewayNamespace
          )
          {
            referenceGrants."${cfg.http.serviceNamespace}-${cfg.http.gatewayName}" = {
              metadata.namespace = cfg.http.serviceNamespace;

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
