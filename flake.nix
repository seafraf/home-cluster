{
  description = "NixOS/Kubernetes Home Cluster";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixidy,
      nixhelm,
    }:
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        charts = nixhelm.chartsDerivations.${system};
        pkgs = import nixpkgs { inherit system; };

        crdSources = {
          gatewayCrd = ./crds/gateway.nix;
          helmCattleCrd = ./crds/helm-cattle.nix;
          ciliumCrd = ./crds/cilium.nix;
          certManagerCrd = ./crds/cert-manager.nix;
        };

        network = {
          sld = "sfdr";
          tld = "me";
          gateway = "${network.sld}-${network.tld}";
          namespace = "network";
          domain = "${network.sld}.${network.tld}";
        };

        auth = {
          namespace = "auth-system"; # needs to match modules/sops/auth-secrets.enc.yaml
          proxyService = {
            name = "caddy";
            port = 80;
          };
        };

        # key is disk tag, value is StorageClass name
        # all storage classes match any node for now
        storage = {
          nvme = "longhorn-nvme";
          ssd = "longhorn-ssd";
          hdd = "longhorn-hdd";
        };

        routes = import ./routes.nix { };

        crds = builtins.mapAttrs (
          _: path:
          import path {
            inherit nixidy pkgs charts;
          }
        ) crdSources;

      in
      {
        packages.nixidy = nixidy.packages.${system}.default;

        nixidyEnvs = nixidy.lib.mkEnvs {
          inherit pkgs charts;

          envs.home = {
            modules = [
              {
                nixidy.applicationImports = builtins.attrValues (builtins.mapAttrs (_: crd: crd.module) crds);
              }

              {
                _module.args = {
                  inherit
                    crds
                    network
                    storage
                    routes
                    auth
                    ;
                };
              }

              {
                imports = [
                  (import ./templates/route.nix {
                    inherit network auth;
                    lib = pkgs.lib;
                  })
                ];
              }

              ./configuration.nix
              ./modules/rancher.nix
              ./modules/argocd.nix
              ./modules/cert-manager.nix
              ./modules/network.nix
              ./modules/longhorn.nix
              ./modules/media-server
              ./modules/auth.nix
            ];
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            nixidy.packages.${system}.default
          ];
        };
      }
    ));
}
