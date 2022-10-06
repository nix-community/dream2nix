{
  dream2nixConfig,
  pkgs,
  dlib,
  lib,
  utils,
  apps,
}: let
  topLevel = import ./top-level.nix {
    inherit apps lib dlib utils pkgs dream2nixConfig;
  };
  evaledModules = lib.evalModules {
    modules = [topLevel] ++ (dream2nixConfig.modules or []);
  };

  framework = evaledModules.config;
in
  framework
