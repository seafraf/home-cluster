{ charts, ... }: {
  applications.cert-manager = {
    namespace = "cert-manager";
    createNamespace = true;

    extraRawYamls = [ ../sops/cloudflare-api-token.enc.yaml ];

    helm.releases.cert-manager = {
      chart = charts.jetstack.cert-manager;
      values = {
        prometheus.enabled = false;
        crds.enabled = true;
        config.enableGatewayAPI = true;
      };
    };
  };
}
