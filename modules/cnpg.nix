{
  namespaces,
  crds,
  lib,
  db,
  ...
}:
{
  applications.cnpg = {
    namespace = namespaces.database;
    createNamespace = true;

    # Required for CNPG manifests
    syncPolicy.syncOptions.serverSideApply = true;

    extraRawYamls =
      # CNPG manigests
      map (p: "${crds.cnpgCrd.source}/${p}") crds.cnpgCrd.files

      # secrets for database credentials
      ++ lib.concatMap (
        cluster:
        let
          dbs = db.${cluster.name}.dbs;
        in
        map (db: ./sops/db + "/${cluster.name}/${dbs.${db.name}.secret}.enc.yaml") (builtins.attrValues dbs)
      ) (builtins.attrValues db);

    resources.cnpgClusters = lib.mapAttrs (_: cluster: {
      spec = {
        instances = cluster.instances;
        storage.size = cluster.size;
        managed.roles = builtins.attrValues (
          builtins.mapAttrs (k: v: {
            name = v.name;
            ensure = "present";
            "inherit" = true;
            connectionLimit = -1;
            login = true;
            passwordSecret.name = v.secret;
          }) cluster.dbs
        );
      };
    }) db;

    resources.cnpgDatabases = builtins.listToAttrs (
      lib.concatMap (
        cluster:
        lib.mapAttrsToList (db: db: {
          name = "${cluster.name}-${db.name}";
          value.spec = {
            name = db.name;
            owner = db.user;
            cluster.name = cluster.name;
          };
        }) cluster.dbs
      ) (builtins.attrValues db)
    );
  };
}
