{ charts, network, ... }: {
  applications.rancher = {
    namespace = "cattle-system";
    createNamespace = true;

    helm.releases.rancher = {
      chart = charts.rancher.rancher;
      values = {
        hostname = "rancher.${network.domain}";
        networkExposure.type = "none";
        ingress.enabled = false;
        replicas = 1;
      };

      extraOpts = [
        "--kube-version"
        "1.35.0"
      ];
    };
  };
}
