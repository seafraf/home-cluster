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

  authelia = rec {
    ports = {
      http = 9091;
    };
    labels = {
      "app.kubernetes.io/name" = "authelia";
    };
    service = {
      name = "authelia";
      namespace = namespaces.auth;
      spec = {
        selector = labels;
        ports = [
          {
            name = "http";
            port = ports.http;
            targetPort = ports.http;
          }
        ];
      };
    };
    http = {
      servicePort = ports.http;
      subdomain = "auth";
    };
  };

  lldap = rec {
    ports = {
      http = 17170;
      ldap = 3890;
      ldaps = 6360;
    };
    labels = {
      "app.kubernetes.io/name" = "lldap";
    };
    service = {
      name = "lldap";
      namespace = namespaces.auth;
      spec = {
        selector = labels;
        ports = [
          {
            name = "http";
            port = ports.http;
            targetPort = ports.http;
          }
          {
            name = "ldap";
            port = ports.ldap;
            targetPort = ports.ldap;
          }
          {
            name = "ldaps";
            port = ports.ldaps;
            targetPort = ports.ldaps;
          }
        ];
      };
    };
    http = {
      servicePort = ports.http;
      subdomain = "ldap";
    };
  };
}
