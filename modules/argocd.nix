{
  lib,
  network,
  apps,
  ...
}:
{
  applications.argocd.templates.app.argocd = apps.argocd;
}
