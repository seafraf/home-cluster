{
  charts,
  gatewayCrd,
  generators,
  lib,
  network,
  namespaces,
  ...
}:
let
  inherit network;
  issuerName = "letsencrypt-cloudflare";
in
{
  applications.network = {
    namespace = namespaces.network;
    createNamespace = true;

    extraRawYamls = [ ./sops/network-secrets.enc.yaml ];

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
                      key = "cloudflare-api-token";
                      name = "network-secrets";
                    };
                  };
                };
              }
            ];
          };
        };
      };

      gateways."${network.gateway}" = {
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
              hostname = "*.${network.domain}";
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
              hostname = "*.${network.domain}";
              name = "https";
              port = 443;
              protocol = "HTTPS";
              tls = {
                mode = "Terminate";
                certificateRefs = [
                  {
                    group = "";
                    kind = "Secret";
                    name = "letsencrypt-${network.gateway}-tls";
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
              hostname = "plex.${network.domain}";
              name = "plex";
              port = 32400;
              protocol = "HTTP";
            }
          ];
        };
      };
    };
  };
}
