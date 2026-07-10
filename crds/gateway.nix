{ nixidy, pkgs, ... }:
let
  files = [
    "standard-install.yaml"
  ];

  source = pkgs.linkFarm "gateway-api-crds" [
    {
      name = "standard-install.yaml";
      path = pkgs.fetchurl {
        url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml";
        hash = "sha256-dRACs7kah/euO9JRfHmkeo1+1nApAYCKHPm9l9KE+bg=";
      };
    }
  ];
in
{
  module = nixidy.packages.${pkgs.system}.generators.fromCRDModule {
    name = "gateway";
    src = source;
    crdFiles = files;
  };

  inherit files source;
}
