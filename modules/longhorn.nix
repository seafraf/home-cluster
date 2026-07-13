{ charts, network, ... }:
let
  inherit network;

  namespace = "longhorn-system";
in
{
  applications.longhorn = {
    namespace = namespace;
    createNamespace = true;

    helm.releases.longhorn = {
      chart = charts.longhorn.longhorn;
      values = {
        networkPolicies = {
          enabled = false;
          type = "rke2";
        };

        service.ui.type = "ClusterIP";

        persistence = {
          defaultClassReplicaCount = 1;
        };

        csi = {
          attacherReplicaCount = 1;
          provisionerReplicaCount = 1;
          resizerReplicaCount = 1;
          snapshotterReplicaCount = 1;
        };

        longhornUI.replicas = 1;

        httproute = {
          enabled = true;
          hostnames = [ "longhorn.${network.domain}" ];
          parentRefs = [
            {
              group = "gateway.networking.k8s.io";
              kind = "Gateway";
              name = network.gateway;
              namespace = network.namespace;
            }
          ];
        };

        preUpgradeChecker.jobEnabled = false;
      };
    };

    resources.storageClasses.longhorn-hdd = {
      provisioner = "driver.longhorn.io";
      allowVolumeExpansion = true;
      parameters = {
        numberOfReplicas = "1";
        diskSelector = "hdd";
      };
    };

    resources.storageClasses.longhorn-ssd = {
      provisioner = "driver.longhorn.io";
      allowVolumeExpansion = true;
      parameters = {
        numberOfReplicas = "1";
        diskSelector = "ssd";
      };
    };

    resources.storageClasses.longhorn-nvme = {
      provisioner = "driver.longhorn.io";
      allowVolumeExpansion = true;
      parameters = {
        numberOfReplicas = "1";
        diskSelector = "nvme";
      };
    };
  };
}
