{
  charts,
  gatewayCrd,
  generators,
  ...
}:
{
  nixidy.chartsDir = ../charts;

  applications.kgateway = {
    namespace = "kgateway-system";
    createNamespace = true;

    # CRD annotations are too big and must be applied server side
    syncPolicy.syncOptions.serverSideApply = true;

    # manually deploy Gateway CRDs, these are not included with the below helm charts
    yamls = map builtins.toJSON (
      generators.crdObjects {
        src = gatewayCrd.source;
        crdFiles = gatewayCrd.files;
      }
    );

    helm.releases.kgateway-crds = {
      chart = charts.kgateway-dev.kgateway-crds;
    };

    helm.releases.kgateway = {
      chart = charts.kgateway-dev.kgateway;
    };

    resources = {
      # LetsEncrypt key generation for Gateways.  Needs dns01 resolution for wildcard domains
      issuers.letsencrypt-cloudflare = {
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
      gateways.sfdr-me = {
        metadata.annotations = {
          "cert-manager.io/issuer" = "letsencrypt-cloudflare";
        };

        spec = {
          gatewayClassName = "kgateway";
          listeners = [
            {
              allowedRoutes = {
                namespaces = {
                  from = "All";
                };
              };
              hostname = "*.sfdr.me";
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
              hostname = "*.sfdr.me";
              name = "https";
              port = 443;
              protocol = "HTTPS";
              tls = {
                mode = "Terminate";
                certificateRefs = [
                  {
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
              hostname = "plex.sfdr.me";
              name = "plex";
              port = 32400;
              protocol = "HTTP";
            }
          ];
        };
      };

      # Rancher HTTP Route
      httpRoutes.rancher-sfdr-me = {
        spec = {
          hostnames = [ "rancher.sfdr.me" ];
          parentRefs = [
            {
              kind = "Gateway";
              name = "sfdr-me";
              namespace = "kgateway-sytem";
            }
          ];

          rules = [
            {
              backendRefs = [
                {
                  kind = "Service";
                  name = "rancher";
                  namespace = "cattle-system";
                  port = 80;
                }
              ];
            }
          ];
        };
      };
    };
  };
}
