# evaluate packages from `/**/modules/drvs` and export them via `flake.packages`
{
  self,
  inputs,
  ...
}: {
  perSystem = {
    system,
    config,
    lib,
    pkgs,
    ...
  }:
    if system != "x86_64-linux"
    then {}
    else let
      # A module imported into every package setting up the eval cache
      setup = {config, ...}: {
        lock.lockFileRel = "/v1/nix/modules/drvs/${config.name}/lock-${system}.json";
        lock.repoRoot = self;
        eval-cache.cacheFileRel = "/v1/nix/modules/drvs/${config.name}/cache-${system}.json";
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
            ../drv-parts/lock
            setup
          ];
          specialArgs.system = system;
          specialArgs.packageSets = {
            nixpkgs = inputs.nixpkgsV1.legacyPackages.${system};
            writers = config.writers;
          };
          specialArgs.drv-parts = inputs.drv-parts;
          specialArgs.dream2nix = self;
        };
      in
        evaled.config.public;
    in {
      # map all modules in ../drvs to a package output in the flake.
      packages = lib.mapAttrs (_: drvModule: makeDrv drvModule) self.modules.drvs;
    };
}
