{
  charts,
  gatewayCrd,
  generators,
  lib,
  ...
}:
let
  domainName = "sfdr.me";
  gatewayName = "sfdr-me";
  namespace = "network";
  issuerName = "letsencrypt-cloudflare";
in
{
  templates.routeForService = {
    options = with lib; {
      serviceName = mkOption {
        type = lib.types.str;
      };
      subdomain = mkOption {
        type = lib.types.str;
      };
      namespace = mkOption {
        type = lib.types.str;
      };
      sectionName = mkOption {
        type = lib.types.str;
        default = "https";
      };
      port = mkOption {
        type = lib.types.ints.u16;
        default = 80;
      };
      weight = mkOption {
        type = lib.types.ints.s32;
        default = 1;
      };
      pathPrefix = mkOption {
        type = lib.types.str;
        default = "/";
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
      {
        httpRoutes."${name}-${gatewayName}".spec = {
          hostnames = [ "${cfg.subdomain}.${domainName}" ];
          parentRefs = [
            {
              group = "gateway.networking.k8s.io";
              kind = "Gateway";
              name = gatewayName;
              namespace = namespace;
            }
          ];

          rules = [
            {
              backendRefs = [
                {
                  group = "";
                  kind = "Service";
                  name = cfg.serviceName;
                  namespace = cfg.namespace;
                  port = cfg.port;
                  weight = cfg.weight;
                }
              ];
              matches = [
                {
                  path = {
                    type = "PathPrefix";
                    value = cfg.pathPrefix;
                  };
                }
              ];
            }
          ];
        };

        referenceGrants."${name}-${gatewayName}" = {
          metadata = {
            name = namespace;
            namespace = cfg.namespace;
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
                group = "";
                kind = "Service";
              }
            ];
          };
        };
      };
  };

  applications.network = {
    namespace = namespace;
    createNamespace = true;
    
    resources = {
      # LetsEncrypt key generation for Gateways.  Needs dns01 resolution for wildcard domains
      issuers."${issuerName}" = {
        spec = {
          acme = {
            email = "seafraf@gmail.com";
            privateKeySecretRef = {
              name = "letsencrypt-cloudflare";
            };
            server = "https://acme-v02.api.letsencrypt.org/directory";
            solvers = [
              {
                dns01 = {
                  cloudflare = {
                    apiTokenSecretRef = {
                      key = "api-token";
                      name = "cloudflare-api-token";
                    };
                  };
                };
              }
            ];
          };
        };
      };

      # Gateway for plex.sfdr.me:32400 *.sfdr.me:80 and *.sfdr.me:443
      gateways."${gatewayName}" = {
        metadata.annotations = {
          "cert-manager.io/issuer" = issuerName;
        };

        spec = {
          gatewayClassName = "cilium";
          listeners = [
            {
              allowedRoutes = {
                namespaces = {
                  from = "All";
                };
              };
              hostname = "*.${domainName}";
              name = "http";
              port = 80;
              protocol = "HTTP";
            }
            {
              allowedRoutes = {
                namespaces = {
                  from = "All";
                };
              };
              hostname = "*.${domainName}";
              name = "https";
              port = 443;
              protocol = "HTTPS";
              tls = {
                mode = "Terminate";
                certificateRefs = [
                  {
                    group = "";
                    kind = "Secret";
                    name = "letsencrypt-sfdr-tls";
                  }
                ];
              };
            }
            {
              allowedRoutes = {
                namespaces = {
                  from = "All";
                };
              };
              hostname = "plex.${domainName}";
              name = "plex";
              port = 32400;
              protocol = "HTTP";
            }
          ];
        };
      };
    };

    templates.routeForService.rancher = {
      serviceName = "rancher";
      namespace = "cattle-system";
      subdomain = "rancher";
    };

    templates.routeForService.argocd = {
      serviceName = "argocd-server";
      namespace = "argocd";
      subdomain = "argocd";
    };
  };
}
