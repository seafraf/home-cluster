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
      services = [
        {
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
        }
      ];
      http = {
        servicePort = ports.http;
        serviceName = name;
        serviceNamespace = namespace;

        subdomain = subdomain;
      };
    };
in
{
  argocd = {
    http = {
      servicePort = 80;
      serviceName = "argocd-server";
      serviceNamespace = namespaces.argocd;

      subdomain = "argocd";
    };
  };

  rancher = {
    http = {
      servicePort = 80;
      serviceName = "rancher";
      serviceNamespace = namespaces.rancher;

      subdomain = "rancher";
    };
  };

  longhorn = {
    http = {
      servicePort = 80;
      serviceName = "longhorn-frontend";
      serviceNamespace = namespaces.longhorn;

      subdomain = "longhorn";
    };

    authSubject = [ groups.clusterAdmin ];
  };

  authelia = externalHttpApp {
    namespace = namespaces.auth;
    name = "authelia";
    subdomain = "auth";
    port = 9091;
  };

  lldap = rec {
    name = "lldap";

    ports = {
      http = 17170;
      ldap = 3890;
      ldaps = 6360;
    };
    labels = {
      "app.kubernetes.io/name" = name;
    };
    services = [
      {
        name = name;
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
      }
    ];
    http = {
      servicePort = ports.http;
      serviceName = name;
      serviceNamespace = namespaces.auth;

      subdomain = "ldap";
    };
  };

  plex =
    let
      namespace = namespaces.mediaServer;
    in
    rec {
      name = "plex";
      ports = {
        http = 32400;
      };
      labels = {
        "app.kubernetes.io/name" = name;
      };
      services = [
        {
          inherit name namespace;
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
        }
        {
          inherit namespace;
          name = "${name}-lb";
          annotations."io.cilium/lb-ipam-ips" = "192.168.1.151";

          spec = {
            selector = labels;
            type = "LoadBalancer";
            ports = [
              {
                name = "http";
                port = ports.http;
                targetPort = ports.http;
              }
            ];
          };
        }
      ];
      http = {
        servicePort = ports.http;
        serviceName = name;
        serviceNamespace = namespace;

        subdomain = name;
      };
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

  seerr = externalHttpApp {
    namespace = namespaces.mediaServer;
    name = "seerr";
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
