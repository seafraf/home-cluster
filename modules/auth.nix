{
  charts,
  lib,
  network,
  storage,
  auth,
  apps,
  namespaces,
  db,
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
            forward_auth ${authelia.name}.${namespaces.auth}.svc.cluster.local:${toString apps.authelia.ports.http} {
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

  routeBlocks = lib.mapAttrsToList mkRouteBlock apps;

  caddyConfig = ''
    {
      auto_https off
    }
  ''
  + lib.concatStrings routeBlocks;

  autheliaConfig = builtins.toJSON {
    theme = "auto";

    authentication_backend = {
      password_reset.disable = true;
      password_change.disable = true;
      refresh_interval = "disable";

      ldap = {
        address = "ldap://${apps.lldap.service.name}.${namespaces.auth}.svc.cluster.local:${toString apps.lldap.ports.ldap}";
        implementation = "lldap";

        base_dn = lldap.baseDn;

        user = "UID=admin,OU=people,DC=${network.sld},DC=${network.tld}";
      };
    };

    access_control = {
      default_policy = "deny";
      rules = lib.pipe apps [
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
        address = "tcp://${db.auth.name}-rw.${db.auth.namespace}.svc.cluster.local";
        database = db.auth.dbs.authelia.name;
        username = db.auth.dbs.authelia.user;
      };
    };

    session.cookies = [
      {
        domain = network.domain;
        authelia_url = "https://${apps.authelia.http.subdomain}.${network.domain}";
      }
    ];

    # todo: smtp
    notifier = {
      disable_startup_check = true;
      filesystem.filename = "/tmp/notification.txt";
    };
  };

  secretsFile = ./sops/auth-secrets.enc.yaml;
  autheliaConfigHash = builtins.hashString "sha256" autheliaConfig;
  caddyConfigHash = builtins.hashString "sha256" caddyConfig;
  secretConfigHash = builtins.hashFile "sha256" secretsFile;
in
{
  applications.auth = {
    namespace = namespaces.auth;
    createNamespace = true;

    extraRawYamls = [ secretsFile ];

    templates.app.authelia = apps.authelia;
    templates.app.lldap = apps.lldap;

    resources = {
      ## authelia
      configMaps."${authelia.configName}" = {
        data."${authelia.configEntryName}" = autheliaConfig;
      };

      deployments."${authelia.name}".spec = {
        replicas = 1;
        selector.matchLabels = apps.authelia.labels;
        template = {
          metadata = {
            labels = apps.authelia.labels;
            annotations."meta.config.hash" = autheliaConfigHash;
            annotations."meta.secret.hash" = secretConfigHash;
          };
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
                {
                  mountPath = "/app/db-secret";
                  name = "db-secret";
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
                  value = "/app/db-secret/POSTGRES_PASSWORD";
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
                  ];
                };
              }
              {
                name = "db-secret";
                secret = {
                  secretName = db.auth.dbs.authelia.secret;
                  items = [
                    {
                      key = "password";
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
        selector.matchLabels = apps.lldap.labels;
        template = {
          metadata = {
            labels = apps.lldap.labels;
            annotations."meta.secrets.hash" = secretConfigHash;
          };
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

      ## caddy
      configMaps."${caddy.name}" = {
        data.Caddyfile = caddyConfig;
      };

      deployments."${caddy.name}".spec = {
        replicas = 1;
        selector.matchLabels = caddy.labels;
        template = {
          metadata = {
            labels = caddy.labels;
            annotations."meta.config.hash" = caddyConfigHash;
          };
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
