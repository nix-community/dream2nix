{
  dream2nixConfig,
  pkgs,
  dlib,
  externals,
  externalSources,
  lib,
  utils,
  apps,
} @ args: let
  topLevel = import ./top-level.nix args;
  evaledModules = lib.evalModules {
    modules = [topLevel] ++ (dream2nixConfig.modules or []);
  };

  framework = evaledModules.config;
in
  framework
