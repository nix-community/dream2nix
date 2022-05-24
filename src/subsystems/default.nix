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

  # maps modules
  # ex: {rust = <translators attrset>;} -> {rust.translators = <translators attrset>;}
  mapModules = modules: name:
    l.mapAttrs'
    (
      subsystem: modules:
        l.nameValuePair subsystem {${name} = modules;}
    )
    modules;

  modules = [
    (mapModules builders.builders "builders")
    (mapModules translators.translators "translators")
    (mapModules discoverers.discoverers "discoverers")
  ];
in
  l.foldl' l.recursiveUpdate {} modules
