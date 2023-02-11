{ self, lib, inputs, ... }: {
  perSystem = { config, self', inputs', pkgs, ... }: let

    makeDrv = module: let
      evaled = lib.evalModules {
        modules = [module];
        specialArgs.dependencySets = {
          nixpkgs = inputs'.nixpkgsPython.legacyPackages;
        };
        specialArgs.drv-parts = inputs.drv-parts;
      };
    in
      evaled.config.final.derivation;

  in {
    packages = lib.mapAttrs (_: drvModule: makeDrv drvModule) self.modules.drvs;
  };
}
