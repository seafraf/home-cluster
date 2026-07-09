{charts, pkgs, ...}: {
  applications.network = {
    namespace = "network";
    createNamespace = true;
    
    resources = {
      # Cilium is a CNI plugin installed via Helm by RKE2. RKE2 recommends configuration be done via HelmChartConfig resources
      helmChartConfigs.rke2-cilium = {
          metadata = {
            name = "rke2-cilium";
            namespace = "kube-system";
          };
          spec = {
            valuesContent = ''
              kubeProxyReplacement: true
              k8sServiceHost: 192.168.1.12
              k8sServicePort: 6443
              l2announcements: 
                enabled: true
              k8sClientRateLimit:
                qps: 10
                burst: 20
              operator:
                replicas: 1
            '';
        };
      };

      ciliumLoadBalancerIPPools.lan-ip-pool = {
        metadata.namespace = "network";
        spec = {
          blocks = [
            {
              start = "192.168.1.150";
              stop = "192.168.1.255";
            }
          ];
        };
      };

      ciliumL2AnnouncementPolicies.lan-policy = {
        metadata.namespace = "network";
        spec = {
          nodeSelector = {
            matchLabels = {
              "kubernetes.io/hostname" = "kassadin";
            };
          };
          externalIPs = true;
          loadBalancerIPs = true;
        };
      };
    };
  };
}