{ }:
{
  argocd = {
    service = {
      name = "argocd-server";
      namespace = "argocd";
    };
    http.subdomain = "argocd";
  };

  rancher = {
    service = {
      name = "rancher";
      namespace = "cattle-system";
    };
    http.subdomain = "rancher";
  };

  longhorn = {
    service = {
      name = "longhorn-frontend";
      namespace = "longhorn-system";
    };
    http.subdomain = "longhorn";
    authSubject = [ "group:sysadmin" ];
  };
}
