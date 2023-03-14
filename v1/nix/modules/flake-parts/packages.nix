# evaluate packages from `/**/modules/drvs` and export them via `flake.packages`
{
  self,
  lib,
  inputs,
  ...
}: let
  system = "x86_64-linux";
  # A module imported into every package setting up the eval cache
  setup = {config, ...}: {
    lock.lockFileRel = "/v1/nix/modules/drvs/${config.public.name}/lock-${system}.json";
    lock.repoRoot = self;
    eval-cache.cacheFileRel = "/v1/nix/modules/drvs/${config.public.name}/cache-${system}.json";
    eval-cache.repoRoot = self;
    eval-cache.enable = true;
  };

  # evalautes the package behind a given module
  makeDrv = module: let
    evaled = lib.evalModules {
      modules = [
        inputs.drv-parts.modules.drv-parts.core
        inputs.drv-parts.modules.drv-parts.docs
        module
        ../drv-parts/eval-cache
        setup
      ];
      specialArgs.dependencySets = {
        nixpkgs = inputs.nixpkgsV1.legacyPackages.${system};
      };
      specialArgs.drv-parts = inputs.drv-parts;
    };
  in
    evaled // evaled.config.public;
in {
  # map all modules in ../drvs to a package output in the flake.
  flake.packages.${system} = lib.mapAttrs (_: drvModule: makeDrv drvModule) self.modules.drvs;
}
