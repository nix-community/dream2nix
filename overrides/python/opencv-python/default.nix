{
  config,
  lib,
  ...
}: {
  # TODO: supply more of the dependencies instead of ignoring them
  env.autoPatchelfIgnoreMissingDeps = true;
  mkDerivation = {
    buildInputs = [
      config.deps.libglvnd
      config.deps.glib
      config.deps.qt6Packages.qtbase
    ];
    nativeBuildInputs = [
      config.deps.qt6Packages.wrapQtAppsHook
    ];
  };
  deps = {nixpkgs, ...}:
    lib.mapAttrs (_: lib.mkDefault) {
      inherit
        (nixpkgs)
        libglvnd
        glib
        qt6Packages
        ;
    };
}
