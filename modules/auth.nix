{
  charts,
  lib,
  network,
  storage,
  ...
}:
let
  inherit network storage;
  namespace = "auth-system";

  authelia = {
    name = "authelia";
    image = "authelia/authelia:4.39";
    labels = {
      "app.kubernetes.io/name" = authelia.name;
    };

    configMountPath = "/config";
    configName = "config";
    configEntryName = "configuration.yml";

    subdomain = "auth";
    port = 9091;
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
    labels = {
      "app.kubernetes.io/name" = lldap.name;
    };

    claimName = "${lldap.name}-data";
    claimSize = "2Gi";

    subdomain = "ldap";
    webPort = 17170;
    ldapPort = 3890;
    ldapsPort = 6360;
  };
in
{
  applications.auth = {
    namespace = namespace;
    createNamespace = true;

    extraRawYamls = [ ../sops/auth-secrets.enc.yaml ];

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
              address = "ldap://${lldap.name}.${namespace}.svc.cluster.local:${toString lldap.ldapPort}";
              user = "admin";
              implementation = "lldap";
            };
          };

          access_control.default_policy = "two_factor";

          storage = {
            postgres = {
              address = "tcp://${postgres.name}.${namespace}.svc.cluster.local";
              database = postgres.autheliaDatabase;
              username = "postgres";
            };
          };

          session.cookies = [
            {
              domain = network.domain;
              authelia_url = "https://${authelia.subdomain}.${network.domain}";
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
        selector.matchLabels = authelia.labels;
        template = {
          metadata.labels = authelia.labels;
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

      services."${authelia.name}".spec = {
        selector = authelia.labels;
        ports = [
          {
            name = "http";
            port = authelia.port;
            targetPort = authelia.port;
          }
        ];
      };

      httpRoutes."${authelia.subdomain}-${network.gateway}".spec = {
        hostnames = [ "${authelia.subdomain}.${network.domain}" ];
        parentRefs = [
          {
            group = "gateway.networking.k8s.io";
            kind = "Gateway";
            name = network.gateway;
            namespace = network.namespace;
          }
        ];

        rules = [
          {
            backendRefs = [
              {
                group = "";
                kind = "Service";
                name = authelia.name;
                namespace = namespace;
                port = authelia.port;
                weight = 1;
              }
            ];
            matches = [
              {
                path = {
                  type = "PathPrefix";
                  value = "/";
                };
              }
            ];
          }
        ];
      };

      ## lldap
      deployments."${lldap.name}".spec = {
        replicas = 1;
        selector.matchLabels = lldap.labels;
        template = {
          metadata.labels = lldap.labels;
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
                # {
                #   name = "LLDAP_LDAP_BASE_DN";
                #   value = "dc={}"
                # }
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

      services."${lldap.name}".spec = {
        selector = lldap.labels;
        ports = [
          {
            name = "http";
            port = lldap.webPort;
            targetPort = lldap.webPort;
          }
          {
            name = "ldap";
            port = lldap.ldapPort;
            targetPort = lldap.ldapPort;
          }
          {
            name = "ldaps";
            port = lldap.ldapsPort;
            targetPort = lldap.ldapsPort;
          }
        ];
      };

      httpRoutes."${lldap.subdomain}-${network.gateway}".spec = {
        hostnames = [ "${lldap.subdomain}.${network.domain}" ];
        parentRefs = [
          {
            group = "gateway.networking.k8s.io";
            kind = "Gateway";
            name = network.gateway;
            namespace = network.namespace;
          }
        ];

        rules = [
          {
            backendRefs = [
              {
                group = "";
                kind = "Service";
                name = lldap.name;
                namespace = namespace;
                port = lldap.webPort;
                weight = 1;
              }
            ];
            matches = [
              {
                path = {
                  type = "PathPrefix";
                  value = "/";
                };
              }
            ];
          }
        ];
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

      ## other
      referenceGrants."${namespace}-${network.gateway}" = {
        metadata = {
          namespace = network.namespace;
        };
        spec = {
          from = [
            {
              group = "gateway.networking.k8s.io";
              kind = "HTTPRoute";
              namespace = namespace;
            }
          ];
          to = [
            {
              group = "gateway.networking.k8s.io";
              kind = "Gateway";
            }
          ];
        };
      };
    };
  };
}
