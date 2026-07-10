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
              name = " letsencrypt-cloudflare";
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
    };
  };
}
