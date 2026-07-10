{
  nixidy,
  pkgs,
  charts,
}:
{
  module = nixidy.packages.${pkgs.system}.generators.fromChartCRDModule {
    name = "cert-managewr";
    chart = charts.jetstack.cert-manager;
    extraOpts = [
      "--set"
      "crds.enabled=true"
    ];
  };
}
