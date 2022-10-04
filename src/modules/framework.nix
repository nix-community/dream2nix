{
  dream2nixConfig,
  callPackageDream,
  pkgs,
  dlib,
  lib,
  utils,
}: let
  evaledModules = lib.evalModules {
    modules = [./top-level.nix] ++ (dream2nixConfig.modules or []);

    # TODO: remove specialArgs once all functionality is moved to /src/modules
    specialArgs = {
      inherit
        dream2nixConfig
        callPackageDream
        pkgs
        dlib
        utils
        ;
    };
  };

  framework = evaledModules.config;
in
  framework
