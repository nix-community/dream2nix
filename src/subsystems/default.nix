{
  lib,
  dlib,
  pkgs,
  # dream2nix
  callPackageDream,
  translators,
  config,
  utils,
  ...
}: let
  inherit (lib) mkOption types evalModules;

  baseModule = {...}: {
    _module = {
      # name = "dream2nix";
      args = {inherit callPackageDream;};
    };
  };

  configModule = {...}: {
    options = {
      overridesDirs = mkOption {
        type = types.listOf types.anything;
        default = [];
      };
      packagesDir = mkOption {
        type = types.str;
        default = "./dream2nix-packages";
      };
      projectRoot = mkOption {
        type = types.anything;
        default = null;
      };
      repoName = mkOption {
        type = types.anything;
        default = null;
      };
    };

    config =
      {
        _module = {
          #name = "dream2nixConfig";
          # specialArgs = { inherit dlib; };
          # args = { inherit callPackageDream; };
        };
      }
      // config;
  };

  subsystemsModule = import ./subsystemsModule.nix;

  builtinSubsystemModules = [
    (import ./nodejs/default.nix)
  ]; # dlib.dirNames ./.;
  extensionModules = [];

  evaledModules = lib.evalModules {
    modules =
      [
        baseModule
        subsystemsModule
        configModule
      ]
      ++ builtinSubsystemModules
      ++ extensionModules;

    specialArgs = {
      inherit pkgs dlib callPackageDream utils;

      inherit
        (evaledModules.config)
        discoverers
        translators
        fetchers
        updaters
        builders
        ;

      nigga = "WAT";
    };
  };

  # discoverers = lib.traceValSeqFn (x: x.nodejs) (evaledModules.config.discoverers);
  discoverers = evaledModules.config.discoverers;

  discovererApi = import ../discoverers {
    # inherit (evaledModules.config) discoverers;
    inherit (evaledModules) config;
    inherit dlib lib discoverers;
  };
  # translatorsApi = import ../translators {
  #   # inherit (evaledModules.config) discoverers;
  #   inherit (evaledModules) config;
  #   inherit dlib lib discoverers;
  # };
in {
  inherit
    (evaledModules.config)
    discoverers
    translators
    fetchers
    updaters
    builders
    ;

  inherit
    (discovererApi)
    applyProjectSettings
    discoverProjects
    ;
}
