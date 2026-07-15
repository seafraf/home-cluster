{
  namespace,
  configDir,
  appName,
  storage,
}:
{
  # Used for all settings stored by all applications. Some applications store quite a bit of metadata so this needs to be rather large
  config = {
    name = "${namespace}-config";
    size = "128Gi";
    mountPath = configDir;
    volumePath = appName;
    class = storage.ssd;
  };

  # Cached transcoded media. This should be fast, but does not require to be very large
  transcode = {
    name = "${namespace}-transcode";
    size = "256Gi";
    mountPath = "/media/transcode";
    volumePath = appName;
    class = storage.ssd;
  };

  # Used by download clients before the media is fully downloaded and imported into one of the below media mounts
  download = {
    name = "${namespace}-download";
    size = "256Gi";
    mountPath = "/media/download/${appName}";
    class = storage.hdd;
  };

  anime = {
    name = "${namespace}-anime";
    size = "2Ti";
    mountPath = "/media/anime";
    class = storage.hdd;
  };

  series = {
    name = "${namespace}-series";
    size = "5Ti";
    mountPath = "/media/series";
    class = storage.hdd;
  };

  movies = {
    name = "${namespace}-movies";
    size = "3Ti";
    mountPath = "/media/movies";
    class = storage.hdd;
  };
}
