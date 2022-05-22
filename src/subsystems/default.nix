{
  lib,
  dlib,
  callPackageDream,
  ...
}: let
  l = lib // builtins;

  builders = callPackageDream ./builders.nix {};
  translators = callPackageDream ./translators.nix {};
  discoverers = callPackageDream ./discoverers.nix {};
in
  l.genAttrs
  dlib.subsystems
  (
    subsystem: {
      builders = builders.builders."${subsystem}";
      translators = translators.translators."${subsystem}";
      discoverers = discoverers.discoverers."${subsystem}";
    }
  )
