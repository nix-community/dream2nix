{
  lib ? (args.pkgs or (import <nixpkgs> {})).lib,
  dream2nixConfig ? {},
  ...
} @ args: let
  topLevel = import ./top-level.nix args;
  evaledModules = lib.evalModules {
    modules = [topLevel] ++ (dream2nixConfig.modules or []);
  };

  framework = evaledModules.config;
in
  framework
