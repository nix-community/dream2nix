{
  config,
  options,
  extendModules,
  lib,
  drv-parts,
  ...
}: let
  l = lib // builtins;

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
        ../../../../../src/modules/utils.toTOML
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

  buildersBySubsystem.rust.default = import ../../../../../src/subsystems/rust/builders/build-rust-package/default.nix {
    inherit lib pkgs utils;
    dlib = {};
  };

  translator =
    (l.evalModules {
      modules = [
        ../../../../../src/modules/interfaces.translator/interface.nix
        ../../../../../src/subsystems/rust/translators/cargo-lock
      ];
      specialArgs = {
        inherit dlib;
      };
    })
    .config;

  tree = dlib.prepareSourceTree {source = config.mkDerivation.src;};

  project = {
    relPath = "";
    subsystemInfo = {};
  };

  result = translator.translate {
    inherit project tree;
  };

  dreamLock = result.result;

  outputs = legacy-interface.makeOutputsForDreamLock {
    inherit dreamLock;
    sourceRoot = config.mkDerivation.src;
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
