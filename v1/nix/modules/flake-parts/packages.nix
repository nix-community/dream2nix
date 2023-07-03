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
  }: let
    # A module imported into every package setting up the eval cache
    setup = {config, ...}: {
      lock.lockFileRel = "/v1/nix/modules/drvs/${config.name}/lock-${system}.json";
      lock.repoRoot = self;
      eval-cache.cacheFileRel = "/v1/nix/modules/drvs/${config.name}/cache-${system}.json";
      eval-cache.repoRoot = self;
      eval-cache.enable = true;
      deps.npm = inputs.nixpkgsV1.legacyPackages.${system}.nodejs.pkgs.npm.override (old: rec {
        version = "8.19.4";
        src = builtins.fetchTarball {
          url = "https://registry.npmjs.org/npm/-/npm-${version}.tgz";
          sha256 = "0xmvjkxgfavlbm8cj3jx66mlmc20f9kqzigjqripgj71j6b2m9by";
        };
      });
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
