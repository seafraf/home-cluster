{ charts, gatewayCrd, generators, ... }: {
  nixidy.chartsDir = ../charts;

  applications.kgateway = {
    namespace = "kgateway-system";
    createNamespace = true;

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
  };
}
