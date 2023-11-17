{
  self,
  lib,
  ...
}: {
  perSystem = {
    self',
    pkgs,
    ...
  }: let
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
    makePackage = testModulePath: let
      evaled = lib.evalModules {
        specialArgs = {
          dream2nix.modules = self.modules;
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
  in {
    checks = self'.packages // packagesBuilt;
  };
}
