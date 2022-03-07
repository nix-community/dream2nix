# builder imported from node2nix
{
  lib,
  pkgs,
  # dream2nix inputs
  externals,
  node2nix ? externals.node2nix,
  utils,
  ...
}: {
  subsystemAttrs,
  defaultPackageName,
  defaultPackageVersion,
  getCyclicDependencies,
  getDependencies,
  getSource,
  packageVersions,
  # overrides
  packageOverrides ? {},
  ...
} @ args: let
  b = builtins;

  getAllDependencies = name: version:
    (args.getDependencies name version)
    ++ (args.getCyclicDependencies name version);

  mainPackageKey = "${defaultPackageName}#${defaultPackageVersion}";

  mainPackageDependencies = getAllDependencies defaultPackageName defaultPackageVersion;

  nodejsVersion = subsystemAttrs.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  node2nixEnv = node2nix nodejs;

  makeSource = packageName: version: prevDeps: let
    depsFiltered =
      lib.filter
      (dep:
        ! b.elem dep prevDeps)
      (getAllDependencies packageName version);
    parentDeps =
      prevDeps ++ depsFiltered;
  in rec {
    inherit packageName version;
    name = utils.sanitizeDerivationName packageName;
    src = getSource packageName version;
    dependencies =
      lib.forEach
      depsFiltered
      (dep: makeSource dep.name dep.version parentDeps);
  };

  node2nixDependencies =
    lib.forEach
    mainPackageDependencies
    (dep: makeSource dep.name dep.version mainPackageDependencies);
  # (dep: allSources."${dep.name}"."${dep.version}");

  callNode2Nix = funcName: args:
    node2nixEnv."${funcName}" (rec {
        name = utils.sanitizeDerivationName packageName;
        packageName = defaultPackageName;
        version = defaultPackageVersion;
        dependencies = node2nixDependencies;
        production = true;
        bypassCache = true;
        reconstructLock = true;
        src = getSource defaultPackageName defaultPackageVersion;
      }
      // args);
in rec {
  packages."${defaultPackageName}"."${defaultPackageVersion}" = defaultPackage;

  defaultPackage = let
    pkg = callNode2Nix "buildNodePackage" {};
  in
    utils.applyOverridesToPackage packageOverrides pkg defaultPackageName;

  devShell = callNode2Nix "buildNodeShell" {};
}
