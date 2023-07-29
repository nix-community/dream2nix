{
  config,
  lib,
  ...
}: {
  mkDerivation = {
    strictDeps = lib.mkDefault true;
  };
}
