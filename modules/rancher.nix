{ charts, ... }: {
  applications.rancher = {
    namespace = "cattle-system";
    createNamespace = true;

    helm.releases.rancher = {
      chart = charts.rancher.rancher;
      values = {
        hostname = "rancher.sfdr.me";
        networkExposure.type = "none";
        ingress.enabled = false;
        replicas = 1;
      };

      extraOpts = [
        "--kube-version"
        "1.35.0"
      ];
    };

    resources = {
      referenceGrants.rancher = {
        spec = {
          from = [
            {
              group = "gateway.networking.k8s.io";
              kind = "HTTPRoute";
              namespace = "kgateway-system";
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
}
