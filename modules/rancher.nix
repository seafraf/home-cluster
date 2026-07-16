{
  charts,
  network,
  apps,
  namespaces,
  ...
}:
{
  applications.rancher = {
    namespace = namespaces.rancher;
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

    templates.app.rancher = apps.rancher;
  };
}
