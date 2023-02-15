{ self, lib, inputs, ... }: {
  perSystem = { config, self', inputs', pkgs, ... }: let

    evalCacheSetup = {config,...}: {
      eval-cache.fileRel = "/nix/modules/drvs/${config.pname}/cache.json";
      eval-cache.repoRoot = self;
    };

    makeDrv = module: let
      evaled = lib.evalModules {
        modules = [
          module
          evalCacheSetup
        ];
        specialArgs.dependencySets = {
          nixpkgs = inputs'.nixpkgsPython.legacyPackages;
        };
        specialArgs.drv-parts = inputs.drv-parts;
      };
    in
      evaled // evaled.config.final.derivation;

  in {
    packages = lib.mapAttrs (_: drvModule: makeDrv drvModule) self.modules.drvs;
  };
}
