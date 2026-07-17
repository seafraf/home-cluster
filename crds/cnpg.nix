{ nixidy, pkgs, ... }:
let
  files = [
    "releases/cnpg-1.30.0.yaml"
  ];

  source = pkgs.fetchFromGitHub {
    owner = "cloudnative-pg";
    repo = "cloudnative-pg";
    rev = "v1.30.0";
    hash = "sha256-UHgllbD2eNBVYrF5nPZhethZIyyBkEji1xf0okGshoI=";
  };
in
{
  module = nixidy.packages.${pkgs.system}.generators.fromCRDModule {
    name = "cloudnative-pg";
    src = source;
    crdFiles = files;
    namePrefix = "cnpg";
  };

  inherit files source;
}
