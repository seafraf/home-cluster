{ }:
let
  unfirmDatabase = name: {
    name = name;
    user = name;
    secret = name;
  };
in
{
  # cluster name
  default = {
    # a sop secret under sops/db/<cluster name>/<user name> should exist
    # containing username and password fields
    dbs = {
      authelia = unfirmDatabase "authelia";
    };

    instances = 1;
    name = "default";
    size = "10Gi";
  };
}
