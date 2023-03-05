{ self, lib, inputs, ... }: {
  perSystem = { config, self', inputs', pkgs, system, ... }: let

    # A module imported into every package setting up the eval cache
    evalCacheSetup = {config,...}: {
      eval-cache.cacheFileRel = "/nix/modules/drvs/${config.public.name}/cache-${system}.json";
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
          evalCacheSetup
        ];
        specialArgs.dependencySets = {
          nixpkgs = inputs'.nixpkgs.legacyPackages;
          nixpkgsStable = inputs'.nixpkgsStable.legacyPackages;
        };
        specialArgs.drv-parts = inputs.drv-parts;
      };
    in
      evaled // evaled.config.public;

  in {
    # map all modules in ../drvs to a package output in the flake.
    packages = lib.mapAttrs (_: drvModule: makeDrv drvModule) self.modules.drvs;
  };
}
