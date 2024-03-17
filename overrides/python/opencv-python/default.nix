{
  config,
  lib,
  ...
}: {
  # TODO: supply more of the dependencies instead of ignoring them
  env.autoPatchelfIgnoreMissingDeps = true;
  mkDerivation.buildInputs = [
    config.deps.libglvnd
    config.deps.glib
  ];
  deps = {nixpkgs, ...}:
    lib.mapAttrs (_: lib.mkDefault) {
      inherit
        (nixpkgs)
        libglvnd
        glib
        ;
    };
}
