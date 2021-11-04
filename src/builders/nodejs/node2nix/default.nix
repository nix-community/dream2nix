# builder imported from node2nix

{
  lib,
  pkgs,

  # dream2nix inputs
  externals,
  node2nix ? externals.node2nix,
  utils,
  ...
}:

{
  subsystemAttrs,
  mainPackageName,
  mainPackageVersion,
  getCyclicDependencies,
  getDependencies,
  getSource,
  packageVersions,

  # overrides
  packageOverrides ? {},
  ...
}@args:
let
  b = builtins;

  getAllDependencies = name: version:
    (args.getDependencies name version)
    ++ (args.getCyclicDependencies name version);

  mainPackageKey = "${mainPackageName}#${mainPackageVersion}";

  mainPackageDependencies = getAllDependencies mainPackageName mainPackageVersion;

  nodejsVersion = subsystemAttrs.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  node2nixEnv = node2nix nodejs;

  makeSource = packageName: version: prevDeps:
    let
      depsFiltered =
        (lib.filter
          (dep:
            ! b.elem dep prevDeps)
          (getAllDependencies packageName version));
      parentDeps =
        prevDeps ++ depsFiltered;
    in
    rec {
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
      packageName = mainPackageName;
      version = mainPackageVersion;
      dependencies = node2nixDependencies;
      production = true;
      bypassCache = true;
      reconstructLock = true;
      src = getSource mainPackageName mainPackageVersion;
    }
    // args);

in
rec {

  packages."${mainPackageName}"."${mainPackageVersion}" = defaultPackage;

  defaultPackage =
    let
      pkg = callNode2Nix "buildNodePackage" {};
    in
      utils.applyOverridesToPackage packageOverrides pkg mainPackageName;

  devShell = callNode2Nix "buildNodeShell" {};
    
}
