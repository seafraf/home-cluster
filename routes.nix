{ namespaces }:
{
  argocd = {
    service = {
      name = "argocd-server";
      namespace = namespaces.argocd;
    };
    http.subdomain = "argocd";
  };

  rancher = {
    service = {
      name = "rancher";
      namespace = namespaces.rancher;
    };
    http.subdomain = "rancher";
  };

  longhorn = {
    service = {
      name = "longhorn-frontend";
      namespace = namespaces.longhorn;
    };
    http.subdomain = "longhorn";
    authSubject = [ "group:sysadmin" ];
  };

  ldap = {
    service = {
      name = "lldap";
      namespace = namespaces.auth;
    };
  };
}
