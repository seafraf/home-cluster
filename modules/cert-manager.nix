{ charts, namespaces, ... }: {
  applications.cert-manager = {
    namespace = namespaces.certManager;
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
