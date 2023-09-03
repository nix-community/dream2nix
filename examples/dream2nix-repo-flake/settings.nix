{config, ...}: {
  paths.projectRoot = ./.;
  paths.package = "/packages/${config.name}";
}
