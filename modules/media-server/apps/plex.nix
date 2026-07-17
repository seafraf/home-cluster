{
  namespaces,
  storage,
  app,
  ...
}:
let
  configDir = "/config";

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
  image = "linuxserver/plex:version-1.43.3.10828-00f62d37d";

  configDir = configDir;
  runtimeClassName = "nvidia";

  # plex needs extra help finding libcuda
  env = [
    {
      name = "NVIDIA_VISIBLE_DEVICES";
      value = "all";
    }
    {
      name = "NVIDIA_DRIVER_CAPABILITIES";
      value = "all";
    }
    {
      name = "LD_LIBRARY_PATH";
      value = "/usr/local/nvidia/lib64/";
    }
  ];

  volumes = [
    volumes.config
    volumes.transcode
    volumes.anime
    volumes.series
    volumes.movies
  ];
}
