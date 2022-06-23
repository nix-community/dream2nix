{
  lib,
  dlib,
  callPackageDream,
  ...
}: let
  l = lib // builtins;
  inherit (dlib.modules) collectSubsystemModules;

  builders = callPackageDream ./builders.nix {};
  translators = callPackageDream ./translators.nix {};
  discoverers = callPackageDream ./discoverers.nix {};
  indexers = callPackageDream ./indexers.nix {};

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
    (mapModules indexers.indexers "indexers")
  ];
  allModules = l.foldl' l.recursiveUpdate {} modules;
in
  allModules
  // {
    allTranslators = collectSubsystemModules translators.translators;
    allBuilders = collectSubsystemModules builders.builders;
    allDiscoverers = collectSubsystemModules discoverers.discoverers;
    allIndexers = collectSubsystemModules indexers.indexers;
  }
