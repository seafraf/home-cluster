{ namespaces, groups }:
let
  externalHttpApp =
    {
      namespace,
      name,
      port,
      subdomain ? name,
      authSubject ? null,
    }:
    rec {
      inherit name authSubject;
      ports = {
        http = port;
      };
      labels = {
        "app.kubernetes.io/name" = name;
      };
      service = {
        inherit name;
        namespace = namespace;
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
        subdomain = subdomain;
      };
    };
in
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
    authSubject = [ groups.clusterAdmin ];
  };

  authelia = externalHttpApp {
    namespace = namespaces.auth;
    name = "authelia";
    subdomain = "auth";
    port = 9091;
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

  plex = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "plex";
    port = 32400;
  };

  jellyfin = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "jellyfin";
    port = 8096;
  };

  decypharr = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "decypharr";
    subdomain = "dl";
    port = 8282;
    authSubject = [ groups.mediaAdmin ];
  };

  transmission = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "transmission";
    subdomain = "tx";
    port = 9091;
    authSubject = [ groups.mediaAdmin ];
  };

  sonarr = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "sonarr";
    port = 8989;
    authSubject = [ groups.mediaAdmin ];
  };

  radarr = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "radarr";
    port = 7878;
    authSubject = [ groups.mediaAdmin ];
  };

  seer = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "seer";
    subdomain = "request";
    port = 5055;
  };

  prowlarr = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "prowlarr";
    port = 9696;
    authSubject = [ groups.mediaAdmin ];
  };
}
