{
  lib,
  network,
  routes,
  ...
}:
{
  applications.argocd.templates.route.argocd = routes.argocd;
}
