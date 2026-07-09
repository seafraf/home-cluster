{ charts, ... }: {
  applications.cert-manager = {
    namespace = "cert-manager";
    createNamespace = true;

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
