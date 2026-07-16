{
  namespaces,
  configDir,
  appName,
  storage,
}:
{
  # Used for all settings stored by all applications. Some applications store quite a bit of metadata so this needs to be rather large
  config = {
    name = "${namespaces.mediaServer}-config";
    size = "128Gi";
    mountPath = configDir;
    volumePath = appName;
    class = storage.ssd;
  };

  # Cached transcoded media. This should be fast, but does not require to be very large
  transcode = {
    name = "${namespaces.mediaServer}-transcode";
    size = "256Gi";
    mountPath = "/media/transcode";
    volumePath = appName;
    class = storage.ssd;
  };

  # Used by download clients before the media is fully downloaded and imported into one of the below media mounts
  download = {
    name = "${namespaces.mediaServer}-download";
    size = "256Gi";
    mountPath = "/media/download/${appName}";
    class = storage.hdd;
  };

  anime = {
    name = "${namespaces.mediaServer}-anime";
    size = "2Ti";
    mountPath = "/media/anime";
    class = storage.hdd;
  };

  series = {
    name = "${namespaces.mediaServer}-series";
    size = "5Ti";
    mountPath = "/media/series";
    class = storage.hdd;
  };

  movies = {
    name = "${namespaces.mediaServer}-movies";
    size = "3Ti";
    mountPath = "/media/movies";
    class = storage.hdd;
  };
}
