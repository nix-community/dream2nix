{
  config,
  options,
  extendModules,
  lib,
  drv-parts,
  ...
}: let
  l = lib // builtins;

  cfg = config.dream2nix-legacy;

  pkgs = drv-parts.inputs.nixpkgs.legacyPackages.x86_64-linux;

  dlib =
    (l.evalModules {
      modules = [
        ../../../../../src/modules/dlib
        ../../../../../src/modules/dlib.construct
        ../../../../../src/modules/dlib.parsing
        ../../../../../src/modules/dlib.simpleTranslate2
        libModule
      ];
    })
    .config
    .dlib;

  utils =
    (l.evalModules {
      modules = [
        ../../../../../src/modules/utils
        ../../../../../src/modules/utils.override
        ../../../../../src/modules/utils.toTOML
        ../../../../../src/modules/utils.translator
        ../../../../../src/modules/dlib
        libModule
      ];
    })
    .config
    .utils;

  legacy-interface =
    (l.evalModules {
      modules = [
        ../../../../../src/modules/dream2nix-interface
        ../../../../../src/modules/dlib
        ../../../../../src/modules/fetchers
        ../../../../../src/modules/functions.default-fetcher
        ../../../../../src/modules/functions.fetchers
        ../../../../../src/modules/utils
        ../../../../../src/modules/utils.dream-lock
        ../../../../../src/modules/utils.override
        buildersModule
        configModule
        libModule
        pkgsModule
      ];
    })
    .config
    .dream2nix-interface;

  buildersModule = {
    options.buildersBySubsystem = l.mkOption {type = l.types.raw;};
    config.buildersBySubsystem = buildersBySubsystem;
  };

  configModule = {
    options.dream2nixConfig = l.mkOption {type = l.types.raw;};
    config.dream2nixConfig = {
      overridesDirs = [../../../../../overrides];
    };
  };

  libModule = {
    options.lib = l.mkOption {type = l.types.raw;};
    config.lib = lib // builtins;
  };

  pkgsModule = {
    options.pkgs = l.mkOption {type = l.types.raw;};
    config.pkgs = pkgs;
  };

  buildersBySubsystem.${cfg.subsystem}.default = import (../../../../.. + "/src/subsystems/${cfg.subsystem}/builders/${cfg.builder}/default.nix") {
    inherit lib pkgs utils;
    dlib = {};
  };

  translator =
    (l.evalModules {
      modules = [
        ../../../../../src/modules/interfaces.translator/interface.nix
        (../../../../.. + "/src/subsystems/${cfg.subsystem}/translators/${cfg.translator}")
        libModule
      ];
      specialArgs = {
        inherit dlib utils;
      };
    })
    .config;

  tree = dlib.prepareSourceTree {inherit (cfg) source;};

  project = {
    inherit (config) name;
    relPath = cfg.relPath;
    subsystemInfo = cfg.subsystemInfo;
  };

  result =
    translator.translate
    (cfg.subsystemInfo
      // {
        inherit project tree;
        inherit (cfg) source;
      });

  dreamLock = result.result or result;

  defaultSourceOverride = dreamLock: let
    defaultPackage = dreamLock._generic.defaultPackage;
    defaultPackageVersion =
      dreamLock._generic.packages."${defaultPackage}";
  in {
    "${defaultPackage}"."${defaultPackageVersion}" = "${cfg.source}/${dreamLock._generic.location}";
  };

  dreamOverrides = let
    overridesDirs = [../../../../../overrides];
  in
    utils.loadOverridesDirs overridesDirs pkgs;

  outputs = legacy-interface.makeOutputsForDreamLock {
    inherit dreamLock;
    sourceRoot = cfg.source;
    sourceOverrides = oldSources:
      dlib.recursiveUpdateUntilDepth
      1
      (defaultSourceOverride dreamLock)
      (cfg.sourceOverrides oldSources);
    packageOverrides =
      l.recursiveUpdate
      (dreamOverrides."${dreamLock._generic.subsystem}" or {})
      (cfg.packageOverrides or {});
  };

  drvModule = drv-parts.lib.makeModule {
    packageFunc = outputs.packages.default;
  };

  # hacky call drvModule manually to prevent infinite recursions
  eval = drvModule {
    inherit config options extendModules;
  };
in {
  imports = [
    ./interface.nix
  ];

  public = l.mkForce eval.config.public;
}
