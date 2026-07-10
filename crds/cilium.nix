{ nixidy, pkgs, ... }:
let
  files = [
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpadvertisements.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpclusterconfigs.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpnodeconfigoverrides.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpnodeconfigs.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgppeerconfigs.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumcidrgroups.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwideenvoyconfigs.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwidenetworkpolicies.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumegressgatewaypolicies.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumendpoints.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumenvoyconfigs.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumidentities.yaml"
    "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumloadbalancerippools.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumlocalredirectpolicies.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnetworkpolicies.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnodeconfigs.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnodes.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumdatapathplugins.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumendpointslices.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumgatewayclassconfigs.yaml"
    "pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliuml2announcementpolicies.yaml"
    # "pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumpodippools.yaml"
  ];

  source = pkgs.fetchFromGitHub {
    owner = "cilium";
    repo = "cilium";
    rev = "v1.19.4";
    hash = "sha256-DcDhBYowP755z7EQ45189GaFNnYAgfJb4rMLSFF113U=";
  };
in
{
  module = nixidy.packages.${pkgs.system}.generators.fromCRDModule {
    name = "cilium";
    src = source;
    crdFiles = files;
  };

  inherit files source;
}
