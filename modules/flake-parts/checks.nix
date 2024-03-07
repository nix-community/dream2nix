{
  self,
  lib,
  inputs,
  ...
}: {
  perSystem = {
    self',
    pkgs,
    system,
    ...
  }: let
    dream2nixFlake = import ../../. {};

    importFlake = flakeFile: let
      self' = (import flakeFile).outputs {
        dream2nix = dream2nixFlake;
        nixpkgs = inputs.nixpkgs;
        self = self';
      };
    in
      self';

    modules = self.modules.dream2nix;

    modulesWithTests =
      lib.filterAttrs
      (_: module: lib.pathExists (module + /tests/packages))
      modules;

    getPackagePaths = moduleName: modulePath:
      lib.concatMapAttrs
      (packageDir: _: {
        "module-${moduleName}-${packageDir}" = "${modulePath}/tests/packages/${packageDir}";
      })
      (builtins.readDir (modulePath + /tests/packages));

    makePackage = path:
      if lib.pathExists (path + "/flake.nix")
      then makePackageFromFlake path
      else makePackageFromDefaultNix path;

    makePackageFromFlake = flakePath:
      (importFlake (flakePath + "/flake.nix")).packages.${system}.default or {};

    makePackageFromDefaultNix = testModulePath: let
      evaled = lib.evalModules {
        specialArgs = {
          dream2nix = dream2nixFlake;

          packageSets.nixpkgs = pkgs;
        };
        modules = [
          testModulePath
          {
            paths.projectRoot = testModulePath;
            paths.package = testModulePath;
          }
        ];
      };
    in
      evaled.config.public;

    packagesToBuild =
      lib.concatMapAttrs getPackagePaths modulesWithTests;

    packagesBuilt = lib.mapAttrs (_: makePackage) packagesToBuild;

    packagesFiltered = lib.filterAttrs (_: pkg: pkg != {}) packagesBuilt;
  in {
    checks = self'.packages // packagesFiltered;
  };
}
