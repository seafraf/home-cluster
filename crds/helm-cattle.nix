{ nixidy, pkgs }:
let
  files = [
    "pkg/crds/yaml/generated/helm.cattle.io_helmcharts.yaml"
    "pkg/crds/yaml/generated/helm.cattle.io_helmchartconfigs.yaml"
  ];

  source = pkgs.fetchFromGitHub {
    owner = "k3s-io";
    repo = "helm-controller";
    rev = "v0.17.3";
    hash = "sha256-JYZjth0/N8dLNhpVCT2V2hNaX3sWq5nrttwH/jx08yE=";
  };
in
{
  module = nixidy.packages.${pkgs.system}.generators.fromCRDModule {
    name = "helm-cattle";
    src = source;
    crdFiles = files;
  };

  inherit files source;
}