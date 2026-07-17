{
  namespaces,
}:
let
  unfirmDatabase = name: {
    name = name;
    user = name;
    secret = name;
  };
in
{
  auth = {
    # a sop secret under sops/db/<cluster name>/<user name> should exist
    # containing username and password fields
    dbs = {
      authelia = unfirmDatabase "authelia";
    };

    instances = 1;
    namespace = namespaces.auth;
    name = "auth";
    size = "10Gi";
  };

  mediaServer = {
    dbs = {
      sonarr = unfirmDatabase "sonarr";
      # radarr = unfirmDatabase "radarr";
      # prowlarr = unfirmDatabase "prowlarr";
      # sonarr = unfirmDatabase "sonarr";
    };

    instances = 1;
    namespace = namespaces.mediaServer;
    name = "media-server";
    size = "10Gi";
  };
}
