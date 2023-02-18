{ self, lib, inputs, ... }: {
  perSystem = { config, self', inputs', pkgs, system, ... }: let

    evalCacheSetup = {config,...}: {
      eval-cache.cacheFileRel = "/nix/modules/drvs/${config.pname}/cache-${system}.json";
      eval-cache.repoRoot = self;
      eval-cache.enable = true;
    };

    makeDrv = module: let
      evaled = lib.evalModules {
        modules = [
          module
          evalCacheSetup
        ];
        specialArgs.dependencySets = {
          nixpkgs = inputs'.nixpkgsPython.legacyPackages;
          nixpkgsStable = inputs'.nixpkgsStable.legacyPackages;
        };
        specialArgs.drv-parts = inputs.drv-parts;
      };
    in
      evaled // evaled.config.final.package;

  in {
    packages = lib.mapAttrs (_: drvModule: makeDrv drvModule) self.modules.drvs;
  };
}
