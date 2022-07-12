{
  lib,
  # dream2nix
  callPackageDream,
  dlib,
  ...
}: let
  b = builtins;
  callIndexer = module:
    module // {indexBin = callPackageDream module.indexBin {};};
in rec {
  indexers = dlib.indexers.mapIndexers callIndexer;
}
