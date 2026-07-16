{
  charts,
  lib,
  network,
  storage,
  auth,
  routes,
  namespaces,
  ...
}:
let
  inherit network storage;

  authelia = {
    name = "authelia";
    image = "authelia/authelia:4.39";

    configMountPath = "/config";
    configName = "config";
    configEntryName = "configuration.yml";
  };

  postgres = {
    name = "postgres";
    image = "postgres:15.18";
    labels = {
      "app.kubernetes.io/name" = postgres.name;
    };

    autheliaDatabase = "authelia";
    lldapDatabase = "lldap"; # not used yet

    claimName = "${postgres.name}-data";
    claimSize = "2Gi";

    port = 5432;
  };

  lldap = {
    name = "lldap";
    image = "lldap/lldap:stable";

    claimName = "${lldap.name}-data";
    claimSize = "2Gi";

    baseDn = "DC=${network.sld},DC=${network.tld}";
  };

  caddy = {
    name = "caddy";
    image = "caddy:2.11.4";
    labels = {
      "app.kubernetes.io/name" = caddy.name;
    };

    port = auth.caddy;
  };

  mkRouteBlock =
    name: cfg:
    let
      host = "${cfg.http.subdomain}.${network.domain}";
      service = "${cfg.service.name}.${cfg.service.namespace}.svc.cluster.local";
      port = cfg.http.servicePort or 80;
    in
    if (cfg.authSubject or null) != null then
      ''
        ${host}:80 {
            forward_auth ${authelia.name}.${namespaces.auth}.svc.cluster.local:${toString routes.authelia.ports.http} {
                uri /api/authz/forward-auth

                copy_headers \
                    Remote-User \
                    Remote-Groups \
                    Remote-Name \
                    Remote-Email

                header_up X-Forwarded-Proto https
                header_up X-Forwarded-Host {host}
            }

            reverse_proxy ${service}:${toString port}
        }
      ''
    else
      "";

  routeBlocks = lib.mapAttrsToList mkRouteBlock routes;
in
{
  applications.auth = {
    namespace = namespaces.auth;
    createNamespace = true;

    extraRawYamls = [ ./sops/auth-secrets.enc.yaml ];

    templates.route.authelia = routes.authelia;
    templates.route.lldap = routes.lldap;

    resources = {
      ## authelia
      configMaps."${authelia.configName}" = {
        data."${authelia.configEntryName}" = builtins.toJSON {
          theme = "auto";

          authentication_backend = {
            password_reset.disable = true;
            password_change.disable = true;
            refresh_interval = "disable";

            ldap = {
              address = "ldap://${routes.lldap.service.name}.${namespaces.auth}.svc.cluster.local:${toString routes.lldap.ports.ldap}";
              implementation = "lldap";

              base_dn = lldap.baseDn;

              user = "UID=admin,OU=people,DC=${network.sld},DC=${network.tld}";
            };
          };

          access_control = {
            default_policy = "deny";
            rules = lib.pipe routes [
              (lib.filterAttrs (
                name: value:
                value ? http && value.http ? subdomain && value ? authSubject && value.authSubject != null
              ))
              (lib.mapAttrsToList (
                name: value:
                let
                  domain = if value.http ? domain then value.http.domain else network.domain;
                in
                {
                  domain = "${value.http.subdomain}.${domain}";
                  policy = "one_factor";
                  subject = value.authSubject;
                }
              ))
            ];
          };

          storage = {
            postgres = {
              address = "tcp://${postgres.name}.${namespaces.auth}.svc.cluster.local";
              database = postgres.autheliaDatabase;
              username = "postgres";
            };
          };

          session.cookies = [
            {
              domain = network.domain;
              authelia_url = "https://${routes.authelia.http.subdomain}.${network.domain}";
            }
          ];

          # todo: smtp
          notifier = {
            disable_startup_check = true;
            filesystem.filename = "/tmp/notification.txt";
          };
        };
      };

      deployments."${authelia.name}".spec = {
        replicas = 1;
        selector.matchLabels = routes.authelia.labels;
        template = {
          metadata.labels = routes.authelia.labels;
          spec = {
            enableServiceLinks = false;
            containers.authelia = {
              image = authelia.image;
              command = [ "authelia" ];
              args = [
                "--config"
                "${authelia.configMountPath}/${authelia.configEntryName}"
              ];
              volumeMounts = [
                {
                  name = authelia.configName;
                  mountPath = "${authelia.configMountPath}/${authelia.configEntryName}";
                  subPath = "${authelia.configEntryName}";
                }
                {
                  mountPath = "/app/secrets";
                  name = "secrets";
                  readOnly = true;
                }
              ];
              env = [
                {
                  name = "AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE";
                  value = "/app/secrets/JWT_SECRET";
                }
                {
                  name = "AUTHELIA_SESSION_SECRET_FILE";
                  value = "/app/secrets/SESSION_SECRET";
                }
                {
                  name = "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE";
                  value = "/app/secrets/LDAP_PASSWORD";
                }
                {
                  name = "AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE";
                  value = "/app/secrets/STORAGE_ENCRYPTION_KEY";
                }
                {
                  name = "AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE";
                  value = "/app/secrets/POSTGRES_PASSWORD";
                }
              ];
            };
            volumes = [
              {
                name = "config";
                configMap.name = authelia.configName;
              }
              {
                name = "secrets";
                secret = {
                  secretName = "auth-secrets";
                  items = [
                    {
                      key = "JWT_SECRET";
                      path = "JWT_SECRET";
                    }
                    {
                      key = "SESSION_SECRET";
                      path = "SESSION_SECRET";
                    }
                    {
                      key = "LDAP_PASSWORD";
                      path = "LDAP_PASSWORD";
                    }
                    {
                      key = "STORAGE_ENCRYPTION_KEY";
                      path = "STORAGE_ENCRYPTION_KEY";
                    }
                    {
                      key = "POSTGRES_PASSWORD";
                      path = "POSTGRES_PASSWORD";
                    }
                  ];
                };
              }
            ];
          };
        };
      };

      ## lldap
      deployments."${lldap.name}".spec = {
        replicas = 1;
        selector.matchLabels = routes.lldap.labels;
        template = {
          metadata.labels = routes.lldap.labels;
          spec = {
            containers.lldap = {
              image = lldap.image;
              volumeMounts = [
                {
                  name = lldap.claimName;
                  mountPath = "/data";
                }
              ];
              env = [
                {
                  name = "LLDAP_JWT_SECRET";
                  valueFrom.secretKeyRef = {
                    name = "auth-secrets";
                    key = "LLDAP_JWT_SECRET";
                  };
                }
                {
                  name = "LLDAP_KEY_SEED";
                  valueFrom.secretKeyRef = {
                    name = "auth-secrets";
                    key = "LLDAP_KEY_SEED";
                  };
                }
                {
                  name = "LLDAP_LDAP_BASE_DN";
                  value = lldap.baseDn;
                }
                {
                  name = "LLDAP_LDAP_USER_PASS";
                  valueFrom.secretKeyRef = {
                    name = "auth-secrets";
                    key = "LDAP_PASSWORD";
                  };
                }
              ];
            };
            volumes = [
              {
                name = lldap.claimName;
                persistentVolumeClaim.claimName = lldap.claimName;
              }
            ];
          };
        };
      };

      persistentVolumeClaims."${lldap.claimName}".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = lldap.claimSize;
        storageClassName = storage.ssd;
      };

      ## postgres
      deployments."${postgres.name}".spec = {
        replicas = 1;
        selector.matchLabels = postgres.labels;
        template = {
          metadata.labels = postgres.labels;
          spec = {
            containers.postgres = {
              image = postgres.image;
              volumeMounts = [
                {
                  name = postgres.claimName;
                  mountPath = "/var/lib/postgresql/data";
                  subPath = "db";
                }
              ];
              env = [
                {
                  name = "POSTGRES_PASSWORD";
                  valueFrom.secretKeyRef = {
                    name = "auth-secrets";
                    key = "POSTGRES_PASSWORD";
                  };
                }
                {
                  name = "POSTGRES_DB";
                  value = postgres.autheliaDatabase;
                }
              ];
            };
            volumes = [
              {
                name = postgres.claimName;
                persistentVolumeClaim.claimName = postgres.claimName;
              }
            ];
          };
        };
      };

      persistentVolumeClaims."${postgres.claimName}".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = postgres.claimSize;
        storageClassName = storage.ssd;
      };

      services."${postgres.name}".spec = {
        selector = postgres.labels;
        ports = [
          {
            name = "http";
            port = postgres.port;
            targetPort = postgres.port;
          }
        ];
      };

      ## caddy
      configMaps."${caddy.name}" = {
        data.Caddyfile = ''
          {
            auto_https off
          }
        ''
        + lib.concatStringsSep "\n" routeBlocks;
      };

      deployments."${caddy.name}".spec = {
        replicas = 1;
        selector.matchLabels = caddy.labels;
        template = {
          metadata.labels = caddy.labels;
          spec = {
            containers.caddy = {
              image = caddy.image;
              volumeMounts = [
                {
                  name = "config";
                  mountPath = "/etc/caddy/Caddyfile";
                  subPath = "Caddyfile";
                }
              ];
            };
            volumes = [
              {
                name = "config";
                configMap.name = caddy.name;
              }
            ];
          };
        };
      };

      services."${auth.proxyService.name}".spec = {
        selector = caddy.labels;
        ports = [
          {
            name = "http";
            port = auth.proxyService.port;
            targetPort = auth.proxyService.port;
          }
        ];
      };

      ## allow HTTPRoutes in network to access services in auth
      referenceGrants."${namespaces.auth}-${network.gateway}" = {
        spec = {
          from = [
            {
              group = "gateway.networking.k8s.io";
              kind = "HTTPRoute";
              namespace = namespaces.network;
            }
          ];
          to = [
            {
              group = "";
              kind = "Service";
            }
          ];
        };
      };
    };
  };
}
