{ nixidy, pkgs, ... }:
let
  files = [
    "config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml"
    "config/crd/standard/gateway.networking.k8s.io_gateways.yaml"
    "config/crd/standard/gateway.networking.k8s.io_httproutes.yaml"
    "config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml"
    "config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml"
    "config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"
  ];

  # CRD versions 1.4.1 latest supported by Cilium 1.19.1
  source = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "gateway-api";
    rev = "v1.4.1";
    hash = "sha256-/GHyikcC2QGDN0ndpY6/xvSEEnpSsLrNU+lFElCKBs8=";
  };
in
{
  module = nixidy.packages.${pkgs.system}.generators.fromCRDModule {
    name = "gateway";
    src = source;
    crdFiles = files;
  };

  inherit files source;
}
