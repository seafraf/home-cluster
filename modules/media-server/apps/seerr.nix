{
  app,
  db,
  namespaces,
  storage,
  ...
}:
let
  configDir = "/app/config";

  volumes = import ../volumes.nix {
    inherit
      namespaces
      storage
      configDir
      ;
    appName = app.name;
  };
in
{
  image = "ghcr.io/seerr-team/seerr:v3.3.0";
  configDir = configDir;

  env = [
    {
      name = "DB_TYPE";
      value = "postgres";
    }
    {
      name = "DB_HOST";
      value = "${db.mediaServer.name}-rw.${db.mediaServer.namespace}.svc.cluster.local";
    }
    {
      name = "DB_USER";
      value = db.mediaServer.dbs.seerr.user;
    }
    {
      name = "DB_PASS";
      valueFrom.secretKeyRef = {
        name = "seerr";
        key = "password";
      };
    }
    {
      name = "DB_NAME";
      value = db.mediaServer.dbs.seerr.name;
    }
  ];

  volumes = [ volumes.config ];
}
