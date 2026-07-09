{ lib, charts, ... }: {
  config = {
    nixidy = {
      target = {
        repository = "git@github.com:seafraf/home-cluster.git";
        branch = "main";
        rootPath = "manifests";
      };

      defaults = {
        syncPolicy = {
          autoSync = {
            enable = true;
            prune = true;
            selfHeal = true;
          };
        };

        # Many helm chars will render all resources with the
        # following labels.
        # This produces huge diffs when the charts are updated
        # because the values of these labels change each release.
        # Here we add a transformer that strips them out after
        # templating the helm charts in each application.
        helm.transformer = map (
          lib.kube.removeLabels [
            "app.kubernetes.io/managed-by"
            "app.kubernetes.io/version"
            "helm.sh/chart"
          ]
        );
      };
    };
  };
}
