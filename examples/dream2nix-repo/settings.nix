{config, ...}: {
  paths.projectRoot = ./.;
  paths.projectRootFile = ".project-root";
  paths.package = "/packages/${config.name}";
}
