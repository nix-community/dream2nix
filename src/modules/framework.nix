{
  dream2nixConfig,
  callPackageDream,
  dlib,
  lib,
}: let
  evaledModules = lib.evalModules {
    modules = [./top-level.nix] ++ (dream2nixConfig.modules or []);

    # TODO: remove specialArgs once all functionality is moved to /src/modules
    specialArgs = {
      inherit
        dream2nixConfig
        callPackageDream
        dlib
        ;
    };
  };

  framework = evaledModules.config;
in
  framework
